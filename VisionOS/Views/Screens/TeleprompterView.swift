import SwiftUI
import AVFoundation
import Speech
import Accelerate

private func splitLines(_ text: String, font: UIFont, width: CGFloat) -> [String] {
    let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    var out:[String]=[]
    var line=""
    for w in words {
        let t = line.isEmpty ? w : "\(line) \(w)"
        if (t as NSString).size(withAttributes:[.font:font]).width <= width {
            line=t
        } else {
            if !line.isEmpty { out.append(line) }
            line=w
        }
    }
    if !line.isEmpty { out.append(line) }
    return out
}

private func normTokens(_ s:String)->[String]{
    s.lowercased()
     .unicodeScalars
     .map{ CharacterSet.punctuationCharacters.contains($0) ? " " : String($0) }
     .joined()
     .split(whereSeparator:\.isWhitespace)
     .map(String.init)
}

struct Screen3Teleprompter: View {

    private enum FS:Hashable,CaseIterable,Identifiable{
        case xs,s,def,l,xl,custom
        var id:Self{self}
        var t:String{
            switch self {
            case .xs:"XS"; case .s:"S"; case .def:"Default"; case .l:"L"; case .xl:"XL"; case .custom:"Custom"
            }
        }
        var preset:Double?{
            switch self{
            case .xs:10; case .s:20; case .def:28; case .l:40; case .xl:50; default:nil
            }
        }
        static func from(_ v:Double)->FS{
            switch v{case 10:.xs;case 20:.s;case 28:.def;case 40:.l;case 50:.xl;default:.custom}
        }
    }

    @EnvironmentObject var recordingStore:RecordingStore
    @Environment(\.dismiss) private var dismiss
    @Binding var title:String
    @Binding var script:String
    @Binding var WPM:Int
    @Binding var isPresented:Bool
    
    @AppStorage("fontSize") private var fontSize:Double = 28
    @State private var fontChoice:FS = .def
    @State private var customSize:Double = 28

    @State private var scriptLines:[String]=[]
    @State private var tokensPerLine:[[String]]=[]
    @State private var currentLine=0

    @State private var transcription=""
    @State private var isRecording=false
    @State private var navigate=false
    @State private var isLoading=true

    @State private var wallTimer:Timer?
    @State private var elapsed=0
    @State private var wordCount=0

    @State private var silenceDurations:[TimeInterval]=[]
    @State private var LGBWSeconds:TimeInterval=0
    @State private var isSilent=true
    @State private var lastSilenceStart:Date?

    @State private var audioEngine=AVAudioEngine()
    @State private var req:SFSpeechAudioBufferRecognitionRequest?
    @State private var task:SFSpeechRecognitionTask?

    private let silenceThresh:Float = -40
    private let minSilence:TimeInterval = 0.25
    private let recogniser=SFSpeechRecognizer(locale:.current)

    private func recompute() {
        let f = UIFont.systemFont(ofSize: CGFloat(fontSize))
        scriptLines = splitLines(script, font:f, width: UIScreen.main.bounds.width - 32)
        tokensPerLine = scriptLines.map(normTokens)
    }

    private func startWall(){
        wallTimer?.invalidate()
        elapsed=0
        wallTimer = Timer.scheduledTimer(withTimeInterval:1,repeats:true){_ in elapsed+=1}
        RunLoop.current.add(wallTimer!, forMode:.common)
    }

    private func stopWall(){
        wallTimer?.invalidate()
        wallTimer=nil
    }

    private func handleLevel(_ db:Float){
        let now=Date()
        if db <= silenceThresh {
            if !isSilent { isSilent=true; lastSilenceStart=now }
        } else {
            if isSilent {
                isSilent=false
                if let st=lastSilenceStart {
                    let d=now.timeIntervalSince(st)
                    if d>=minSilence {
                        silenceDurations.append(d)
                        if d>LGBWSeconds { LGBWSeconds=d }
                    }
                }
            }
        }
    }

    private func finalizeSilence(){
        if isSilent, let st=lastSilenceStart {
            let d=Date().timeIntervalSince(st)
            if d>=minSilence {
                silenceDurations.append(d)
                if d>LGBWSeconds { LGBWSeconds=d }
            }
        }
    }

    private func dB(_ b:AVAudioPCMBuffer)->Float{
        guard let cd=b.floatChannelData else{return -120}
        let c=cd[0]; let n=Int(b.frameLength)
        if n==0 {return -120}
        var sum:Float=0
        vDSP_measqv(c,1,&sum,vDSP_Length(n))
        let rms=sqrtf(sum)
        let db=20*log10f(max(rms,1e-7))
        return db.isFinite ? db : -120
    }

    private func startRecog(){
        SFSpeechRecognizer.requestAuthorization{_ in}
        let s=AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker,.allowBluetooth])
        try? s.setActive(true)

        let r=SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults=true
        req=r

        let input=audioEngine.inputNode
        let fmt=input.outputFormat(forBus:0)
        input.removeTap(onBus:0)
        input.installTap(onBus:0,bufferSize:1024,format:fmt){buf,_ in
            r.append(buf)
            self.handleLevel(self.dB(buf))
        }

        audioEngine.prepare()
        try? audioEngine.start()

        task = recogniser?.recognitionTask(with:r){res,err in
            if let res { self.transcription=res.bestTranscription.formattedString }
            if err != nil { self.stopRecog() }
        }
    }

    private func stopRecog(){
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus:0)
        audioEngine.reset()
        req?.endAudio()
        task?.cancel()
        req=nil
        task=nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func tryAdvance(_ tokens:[String], _ proxy:ScrollViewProxy){
        if currentLine >= tokensPerLine.count { return }
        guard let last = tokensPerLine[currentLine].last else { return }
        if tokens.contains(last) {
            currentLine += 1
            withAnimation(.easeInOut){
                proxy.scrollTo(currentLine,anchor:.top)
            }
        }
    }

    private func computeCIS()->Double {
        if silenceDurations.isEmpty { return 100 }
        let m=silenceDurations.reduce(0,+)/Double(silenceDurations.count)
        let v=silenceDurations.reduce(0){$0+pow($1-m,2)}/Double(silenceDurations.count)
        let sd=sqrt(v)
        let base=100/(1+sd)
        let p = LGBWSeconds<=0.5 ? 0 : min(40,(LGBWSeconds-0.5)*25)
        return max(0,base-p)
    }

    var body: some View {
        NavigationStack {
            NavigationLink("", destination:
                ReviewView(
                    LGBW:Binding(get:{Int(LGBWSeconds)},set:{_ in}),
                    elapsedTime:$elapsed,
                    wordCount:$wordCount,
                    deriative:Binding(get:{computeCIS()},set:{_ in}),
                    isCoverPresented:$isPresented
                ), isActive:$navigate
            )

            VStack {
                if isLoading {
                    ProgressView("Loading...")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment:.leading){
                                ForEach(Array(scriptLines.enumerated()),id:\.offset){i,l in
                                    Text(l)
                                        .font(.system(size:CGFloat(fontSize)))
                                        .id(i)
                                        .padding(.vertical,4)
                                        .background(i==currentLine ? Color.primary.opacity(0.1):.clear)
                                }
                            }.padding()
                        }
                        .onChange(of: transcription){ _,v in
                            tryAdvance(normTokens(v),proxy)
                        }
                    }
                }

                Button {
                    isRecording.toggle()
                    if isRecording {
                        silenceDurations=[]
                        LGBWSeconds=0
                        isSilent=true
                        lastSilenceStart=Date()
                        recordingStore.startRecording()
                        startWall()
                        startRecog()
                    } else {
                        recordingStore.stopRecording()
                        stopRecog()
                        stopWall()
                        finalizeSilence()
                        navigate=true
                    }
                } label: {
                    RecordButtonView(isRecording:$isRecording)
                }
                .padding(.bottom,20)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing){
                    Menu{
                        Picker("Font Size",selection:$fontChoice){
                            ForEach(FS.allCases){c in Text(c.t).tag(c) }
                        }
                        .onChange(of:fontChoice){_,v in
                            if let p=v.preset {
                                fontSize=p
                                customSize=p
                            }
                        }
                        if fontChoice == .custom {
                            Slider(value:$customSize,in:10...60,step:1)
                                .onChange(of:customSize){_,v in fontSize=v }
                        }
                    } label: {
                        Image(systemName:"textformat.size")
                    }
                }

                ToolbarItem(placement:.topBarLeading){
                    Button { dismiss() } label: {
                        Image(systemName:"xmark")
                    }
                }
            }
            .onAppear{
                fontChoice = FS.from(fontSize)
                customSize = fontSize
                wordCount = script.split(whereSeparator:\.isWhitespace).count
                recompute()
                isLoading=false
            }
            .onChange(of:fontSize){_,_ in recompute() }
            .onChange(of:script){_,_ in wordCount = script.split(whereSeparator:\.isWhitespace).count; recompute() }
        }
    }
}
