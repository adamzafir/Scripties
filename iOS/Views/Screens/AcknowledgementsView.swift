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
    @State var avyan = false
    @State var friends = false
    private let fadeInDuration: Double = 3

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    List {
                        Section(header: Text("People")) {
                            DisclosureGroup(isExpanded: $adam) {
                                VStack {
                                    HStack {
                                        Text("About")
                                            .multilineTextAlignment(.leading)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Spacer()
                                    }
                                    HStack {
                                        Text("What if the real about was the freinds we made along the way")
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                }
                            } label: {
                                ListItem(sfSymbol: "apple.terminal", title: "Adam", subtitle: "The only iPhone user.")
                            }
                             DisclosureGroup(isExpanded: $divya) {
                                 VStack {
                                     HStack {
                                         Text("About")
                                             .multilineTextAlignment(.leading)
                                             .font(.title2)
                                             .fontWeight(.bold)
                                         Spacer()
                                     }
                                     HStack {
                                         Text("What if the real about was the freinds we made along the way")
                                             .multilineTextAlignment(.leading)
                                         Spacer()
                                     }
                                 }
                             } label: {
                                 ListItem(sfSymbol: "shoeprints.fill", title: "Divya", subtitle: "The one who threw the shoe.")
                             }
                             .monospacedDigit()
                            DisclosureGroup(isExpanded: $yaplong) {
                                VStack {
                                    HStack {
                                        Text("About")
                                            .multilineTextAlignment(.leading)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Spacer()
                                    }
                                    HStack {
                                        Text("What if the real about was the freinds we made along the way")
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                }
                            } label: {
                                ListItem(sfSymbol: "sharedwithyou", title: "Yap Long", subtitle: "The inspiration behind the app.")
                            }
                            DisclosureGroup(isExpanded: $avyan) {
                                VStack {
                                    HStack {
                                        Text("About")
                                            .multilineTextAlignment(.leading)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Spacer()
                                    }
                                    HStack {
                                        Text("What if the real about was the freinds we made along the way")
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                }
                            } label: {
                                ListItem(sfSymbol: "figure.walk.motion.trianglebadge.exclamationmark", title: "Avyan", subtitle: "Our Mentor, the cooked one.")
                            }
                            DisclosureGroup(isExpanded: $friends) {
                                VStack {
                                    HStack {
                                        Text("About")
                                            .multilineTextAlignment(.leading)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Spacer()
                                    }
                                    HStack {
                                        Text("What if the real about was me")
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                }
                            } label: {
                                ListItem(sfSymbol: "figure.2.circle.fill", title: "The Friends We Made Along the Way", subtitle: "Thank you to everyone who helped with this app!")
                            }
                        }
                        Section(header: Text("Tools")) {
                            ListItem(sfSymbol: "hammer.fill", title: "Xcode", subtitle: "Development IDE")
                            ListItem(sfSymbol: "paintbrush.fill", title: "Figma", subtitle: "UI design")
                        }
                        Section(header: Text("Packages & Frameworks")) {
                            ListItem(sfSymbol: "apple.intelligence", title: "Foundation Models", subtitle: "Local device models developed by Apple.")
                            ListItem(sfSymbol: "sparkles", title: "Avyan Intelligence", subtitle: "Inspired by Avyan.")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTap()
                                }
                            ListItem(sfSymbol: "link", title: "AppleIntelligenceGlowEffect", subtitle: "Developed by jacobamobin on Github. Licensed under the MIT License.")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: "https://github.com/jacobamobin/AppleIntelligenceGlowEffect") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        }
                        Section(header: Text("Source Control")) {
                            ListItem(sfSymbol: "link", title: "Yap Longer", subtitle: "This project is open source on Github.")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: "https://github.com/adamzafir/yapLonger") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                        }
                    }
                }

                if showImage {
                    Image("cookeddogmemeimage")
                        .resizable()
                        .scaledToFit()
                        .opacity(imageOpacity)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
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
