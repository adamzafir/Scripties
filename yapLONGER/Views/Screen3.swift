import SwiftUI
import AVFoundation
import Speech
import FoundationModels

@Generable
struct keyword {
    @Guide(description: "Key Words/Phrases from the script")
    var keywords: [String]
}

struct Screen3: View {
    @State private var showAccessory = false
    let synthesiser = AVSpeechSynthesizer()
    let audioEngine = AVAudioEngine()
    let speechRecogniser = SFSpeechRecognizer(locale: .current)
    @State var transcription = ""
    @State var isRecording = false
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var script: String
    let session = LanguageModelSession()
    @State var response2: keyword = .init(keywords: [])
    @State var response3: [String] = []
    
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    ScrollView {
                        VStack {
                        
                            Text("Keywords:")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .center)
                            ForEach(response3, id: \.self) { word in
                                Text(word)
                                    .font(.title2.bold())
                                    .padding(5)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding()
                }

                Spacer()

                HStack {
                    Button {
                        print("can i get the mic a little lefter?")
                    } label: {
                        Image(systemName: "arrow.left")
                            .frame(height: 100)
                            .padding(.horizontal)
                    }
                    Button {
                        isRecording.toggle()
                        showAccessory.toggle()
                    } label: {
                        RecordButtonView(isRecording: $isRecording)
                    }
                    .sensoryFeedback(.selection, trigger: showAccessory)
                    
                    
                    Button {
                        print("can i get the mic a little righter?")
                    } label: {
                        Image(systemName: "arrow.right")
                            .frame(height: 100)
                            .padding(.horizontal)
                    }
                }
                Text(transcription)
            }
            .onAppear {
                Task {
                    let prompt = "Reply with only the keywords/phrases, each on a new line from: \(script)"
                    let response = try await session.respond(to: prompt, generating: keyword.self)
                    response2 = response.content
                    print("\(response2)")
                    
                    response3 = response2.keywords
                    isLoading = false
                }
            }
            .navigationTitle($title)
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Label("Back", systemImage: "chevron.backward")
                    }
                }
            }
            .onChange(of: isRecording) { recording in
                if recording {
                    SFSpeechRecognizer.requestAuthorization { status in
                        guard status == .authorized else { return }
                    }
                    
                    Task {
                        let micGranted = await AVAudioApplication.requestRecordPermission()
                        guard micGranted else { return }
                    }
                    
                    guard let recogniser = speechRecogniser, recogniser.isAvailable else { return }
                    
                    let audioSession = AVAudioSession.sharedInstance()
                    try? audioSession.setCategory(.record, mode: .measurement)
                    try? audioSession.setActive(true)
                    
                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true
                    
                    let inputNode = audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    
                    inputNode.removeTap(onBus: 0)
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        request.append(buffer)
                    }
                    audioEngine.prepare()
                    try? audioEngine.start()
                    
                    recogniser.recognitionTask(with: request) { result, _ in
                        if let result {
                            transcription = result.bestTranscription.formattedString
                        }
                    }
                } else {
                    audioEngine.stop()
                    audioEngine.inputNode.removeTap(onBus: 0)
                }
            }
        }
    }
}

struct RecordButtonView: View {
    @Binding var isRecording: Bool
    @State private var buttonCircle: CGFloat = 60
    @State private var buttonSquare: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray, lineWidth: 5)
                    .frame(width: 75, height: 75)
                
                RoundedRectangle(cornerRadius: isRecording ? 5 : 50)
                    .foregroundStyle(.red)
                    .frame(
                        maxWidth: isRecording ? buttonSquare : buttonCircle,
                        maxHeight: isRecording ? buttonSquare : buttonCircle)
            }
        }
        .padding(.vertical, 20)
        .animation(.snappy, value: isRecording)
    }
}

#Preview {
    RecordButtonView(isRecording: .constant(false))
}
