import SwiftUI
import AVFoundation
import Combine

final class AudioPlaybackCoordinator: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    var onDidFinishPlaying: (() -> Void)?
    
    private(set) var player: AVAudioPlayer?
    
    func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed:", error)
        }
    }
    
    func playSound(named name: String, withExtension ext: String) {
        configureSession()
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Audio file not found: \(name).\(ext)")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            isPlaying = true
            player?.play()
        } catch {
            print("Failed to init AVAudioPlayer:", error)
        }
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        onDidFinishPlaying?()
    }
}

struct Acknowledgements: View {
    @StateObject private var audioCoordinator = AudioPlaybackCoordinator()
    
    @State private var showImage: Bool = false
    @State private var imageOpacity: Double = 0.0
    @State private var isAnimating: Bool = false
    @State var adam = false
    @State var divya = false
    @State var yaplong = false
    @State var ethan = false
    @State var avyan = false
    @State var friends = false
    private let fadeInDuration: Double = 3
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    List {
                        Section(header: Text("People")) {
//                            DisclosureGroup(isExpanded: $adam) {
//                                VStack {
//                                    HStack {
//                                        Text("About")
//                                            .multilineTextAlignment(.leading)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                        Spacer()
//                                    }
//                                    HStack {
//                                        Text("""
//                                            Adam was a groupmate who specialised in coding. From IOS to Apple Vision Pro compatible apps, Adam inspired our group with his many speeches. “Because at Scripties, we care” He would often give motivational speeches to our group and relegate different tasks to us. He was the voice of the group, having the confidence to speak up to voice our ideas to the mentors of Swift Accelerator, no matter how much it was frowned upon. He was also extremely humorous, always quoting “the friends we made along the way”, a playful twist that showed our friendship. However, Adam would causally ragebait Ethan sometimes, fully immersed in the experience of our group.
//                                            """)
//                                            .multilineTextAlignment(.leading)
//                                        Spacer()
//                                    }
//                                }
//                            } label: {
                                ListItem(sfSymbol: "apple.terminal", title: "Adam Zafir", subtitle: "The only iPhone user.")
//                            DisclosureGroup(isExpanded: $divya) {
//                                VStack {
//                                    HStack {
//                                        Text("About")
//                                            .multilineTextAlignment(.leading)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                        Spacer()
//                                    }
//                                    HStack {
//                                        Text("Divya was the oldest of the group and her maturity was next to Yap Long’s. She would consistently learn from tutorials and was hardworking. She contributed much to the project as she completed the main part of the app which no one had dared to do although she might have taken a longer time. She also reprimanded Ethan for leaving 1h early for a birthday party and being negative. She crashed out at Ethan, where she chased him around with a shoe. With incredibly accurate aim, she impressively threw the shoe at Ethan and hit him in the chest! Ethan was very scared from then on as she would always wear heels. Divya contributed a lot and her work is nothing short of impressive. Without her, we would not have made it this far.")
//                                            .multilineTextAlignment(.leading)
//                                        Spacer()
//                                    }
//                                }
//                            } label: {
                                ListItem(sfSymbol: "shoeprints.fill", title: "Divya Dharshini", subtitle: "The one who threw the shoe.")
//                            DisclosureGroup(isExpanded: $yaplong) {
//                                VStack {
//                                    HStack {
//                                        Text("About")
//                                            .multilineTextAlignment(.leading)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                        Spacer()
//                                    }
//                                    HStack {
//                                        Text("Yap Long was the original inspiration behind the app. During the discussion phase, all of our group members were very impressed with his name, specifically the term ‘Yap’. We drew ideation from this and decided to make an app about ‘Yapping’.  We wanted to name the app Yap Longer, however Yap Long was against this idea. Yap Long hard carried the Vision Pro app, completing the entire app optimization in 1 day. When Ethan refused to cooperate, Yappy continued to provide calm collaboration and continued to assist the group, regardless of the situation. Yap Long used critical thinking to solve problems dynamically and efficiently, making him an asset to the group.")
//                                            .multilineTextAlignment(.leading)
//                                            .lineLimit(nil)
//                                        Spacer()
//                                    }
//                                }
//                            } label: {
                                ListItem(sfSymbol: "sharedwithyou", title: "Chan Yap Long", subtitle: "The inspiration behind the app.")
//                            DisclosureGroup(isExpanded: $ethan) {
//                                VStack {
//                                    HStack {
//                                        Text("About")
//                                            .multilineTextAlignment(.leading)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                        Spacer()
//                                    }
//                                    HStack {
//                                        Text("""
//Ethan was the jokester of the group. Always slacking, playing Minecraft, and deleting our prototypes, Ethan was very easily ragebaited. Once, he was fooled in Minecraft by getting dispensed a Curse of Binding pumpkin on his head. Because Keep Inventory was on, he could not remove said pumpkin even when he leaped off a cliff to respawn. Enraged, he deleted our Figma prototype, saying, "It's just a Figma prototype." As quoted by Ethan, who believed he did nothing wrong: "Ethan, one of the few in the ensemble with both ingenuity and practical foresight, efficiently implemented his ideas. Adam was the only other with comparable competence. In a display of opportunistic brilliance, he enlisted Clanker to handle the more formidable project tasks, optimizing his efforts for higher-priority matters."
//"""
//                                        )
//                                        .multilineTextAlignment(.leading)
//                                        Spacer()
//                                    }
//                                }
//                            } label: {
                                ListItem(sfSymbol: "birthday.cake.fill", title: "Ethan Soh", subtitle:"'Soh What?'")
//                            DisclosureGroup(isExpanded: $avyan) {
//                                VStack {
//                                    HStack {
//                                        Text("About")
//                                            .multilineTextAlignment(.leading)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                        Spacer()
//                                    }
//                                    HStack {
//                                        Text("""
//                                            Avyan heavily inspired us throughout the development process. When we were slacking, he played the ‘cooked-dog-audio’ to as well as showing the image of the meme, showcasing his disappointment with us. We respected avyan too much to the point where we made a parody of the audio, titled: ‘Cooked-Avyan’. This audio showcased the popular memes tone and pitch, while containing the lyrics “Avyan-vyan” instead of the usual “Aeaeae”.
//                                            With this in mind, we decided to develop Avyan Intelligence™. Avyan intelligence assists users in editing their scripts and overall improving their quality of life. We believe Avyan is an EXCELLENT mentor and can only be compared to the likes of Sean(he left for finland).
//                                            """)
//                                        .multilineTextAlignment(.leading)
//                                        Spacer()
//                                    }
//                                }
//                            } label: {
                                ListItem(sfSymbol: "figure.walk.motion.trianglebadge.exclamationmark", title: "Avyan Mehra", subtitle: "Our Mentor, the cooked one.")
//                            DisclosureGroup(isExpanded: $friends) {
//                                VStack {
//                                    HStack {
//                                        Text("About")
//                                            .multilineTextAlignment(.leading)
//                                            .font(.title2)
//                                            .fontWeight(.bold)
//                                        Spacer()
//                                    }
//                                    HStack {
//                                        Text("""
//                                             The friends we made along the way were the most important in the overall app. We could not have made it this far without the support and encouragement from every single person that helped us along this journey. From our parents, mentors, friends, and even strangers that tested our app for us, we appreciate it all. Most importantly, we thank YOU, for giving our app a try. Specifically, we would like to thank: The Swift Accelerator program; for allowing us this opportunity to learn and create this app, Apple; for being the host of the programme, Ethan; for trying to delete the xcode project and pushing to the github but ran into a merge conflict.
//                                             """)
//                                        .multilineTextAlignment(.leading)
//                                        Spacer()
//                                    }
//                                }
//                            } label: {
                                ListItem(sfSymbol: "figure.2.circle.fill", title: "The Friends We Made Along The Way", subtitle: "Thank you to everyone who helped with this app!")
                            }
                        Section(header: Text("Tools")) {
                            ListItem(sfSymbol: "hammer.fill", title: "Xcode", subtitle: "Development IDE")
                            ListItem(sfSymbol: "paintbrush.fill", title: "Figma", subtitle: "UI design")
                        }
                        Section(header: Text("Packages & Frameworks")) {
                            ListItem(sfSymbol: "apple.intelligence", title: "Foundation Models", subtitle: "Local device models developed by Apple.")
                            ListItem(sfSymbol: "sparkles", title: "Avyan Intelligence", subtitle: "Inspired by Avyan.")
                                .contentShape(Rectangle())
//                                .onTapGesture {
//                                    handleTap()
//                                }
                            ListItem(sfSymbol: "link", title: "AppleIntelligenceGlowEffect", subtitle: "Developed by jacobamobin on Github. Licensed under the MIT License.")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: "https://github.com/jacobamobin/AppleIntelligenceGlowEffect") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        }
                        Section(header: Text("Source Control")) {
                            ListItem(sfSymbol: "link", title: "Scripties", subtitle: "This project is open source on Github.")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: "https://github.com/adamzafir/yapLonger") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        }
                    }
                    
//                    if showImage {
//                        Image("cookeddogmemeimage")
//                            .resizable()
//                            .scaledToFit()
//                            .opacity(imageOpacity)
//                            .allowsHitTesting(false)
//                            .transition(.opacity)
//                    }
                }
                .navigationTitle("Acknowledgements")
                .onAppear {
                    audioCoordinator.configureSession()
                    audioCoordinator.onDidFinishPlaying = { [weak audioCoordinator] in
                        withAnimation(.easeOut(duration: 1)) {
                            imageOpacity = 0.0
                            isAnimating = false
                            showImage = false
                        }
                        audioCoordinator?.stop()
                    }
                }
            }
        }
    }
    
    private func handleTap() {
        guard !isAnimating else { return }
        isAnimating = true
        imageOpacity = 0.0
        showImage = true
        audioCoordinator.playSound(named: "cooked-dog-meme", withExtension: "mp3")
        withAnimation(.easeInOut(duration: fadeInDuration)) {
            imageOpacity = 1.0
        }
    }
}

#Preview {
    Acknowledgements()
}
