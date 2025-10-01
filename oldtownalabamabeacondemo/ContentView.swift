import SwiftUI
import CoreBluetooth
import SafariServices
import AVKit

struct ContentView: View {
    @StateObject private var beaconDetector = EddystoneBeaconDetector()
    @State private var activeURL: URL? = nil
    @State private var isSimulating = false
   

    var body: some View {
        ZStack {
            if let url = activeURL {
                WebViewPage(url: url) {
                    withAnimation {
                        activeURL = nil
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                MainContentView(
                    beaconDetector: beaconDetector,
                    isSimulating: $isSimulating
                ) { url in
                    withAnimation {
                        activeURL = url
                       
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            }
        }
        .onChange(of: beaconDetector.shouldOpenURL) { _, newValue in
            if newValue, let url = beaconDetector.detectedURL {
                withAnimation {
                    activeURL = url
                }
                beaconDetector.shouldOpenURL = false
            }
        }
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @ObservedObject var beaconDetector: EddystoneBeaconDetector
    @Binding var isSimulating: Bool
    var onExploreTapped: (URL) -> Void
    
    // Video player for simulation
    @State private var player: AVPlayer? = nil
    @State private var showVideo = false
    @State private var audioPlayer: AVPlayer?
    
    // Check if beacon is detected (real or simulated)
    var isBeaconDetected: Bool {
        return beaconDetector.isDetected || isSimulating
    }
    
    var body: some View {
        ZStack {
            // Natural gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.96, green: 0.93, blue: 0.88),
                    Color(red: 0.85, green: 0.82, blue: 0.75),
                    Color(red: 0.92, green: 0.88, blue: 0.82)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Title Banner
                    VStack(spacing: 8) {
                        Text("Old Town Montgomery")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                        
                        Text("TOUR BEACONS")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .tracking(3)
                            .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                        
                        Rectangle()
                            .fill(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .frame(width: 100, height: 2)
                            .padding(.top, 5)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 10)
                    
                    // Simulation Toggle Button
                    Button(action: {
                        withAnimation(.spring()) {
                            if isSimulating {
                                // Stop simulation - clean up everything
                                stopSimulation()
                            } else {
                                // Start simulation
                                isSimulating = true
                               // setupSimulationVideo()
                                showVideo = true
                                playSimulationAudio()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: isSimulating ? "stop.circle.fill" : "play.circle.fill")
                            Text(isSimulating ? "Stop Simulation" : "Start Simulation")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isSimulating ? Color.red.opacity(0.8) : Color.blue.opacity(0.8),
                                    isSimulating ? Color.red : Color.blue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                    }
                    
                    // Walking Tour Header
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 20))
                        Text("Take Our Walking Tour")
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .italic()
                        Image(systemName: "building.columns")
                            .font(.system(size: 20))
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                    .padding(.horizontal)
                    
                    // Detection Status Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isBeaconDetected ? "location.north.fill" : "location.slash")
                            .font(.system(size: 50))
                            .foregroundColor(isBeaconDetected ?
                                Color(red: 0.2, green: 0.5, blue: 0.3) :
                                Color(red: 0.6, green: 0.5, blue: 0.4))
                            .symbolEffect(.pulse, isActive: isBeaconDetected)
                    }
                    .padding(.vertical, 10)
                    
                    // Status Text
                    VStack(spacing: 5) {
                        Text(isBeaconDetected ? "Historic Site Detected!" : "Searching for Historic Sites...")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isBeaconDetected ?
                                Color(red: 0.2, green: 0.5, blue: 0.3) :
                                Color(red: 0.4, green: 0.35, blue: 0.3))
                        
                        if !isBeaconDetected {
                            Text("Walk near a historic marker to learn more")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                                .italic()
                        }
                        
                        if isSimulating {
                            Label("Simulation Mode", systemImage: "wand.and.stars")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Video Player (shows in simulation when detected)
                    if isSimulating && showVideo {
                        VStack(alignment: .center, spacing: 10) {
                            Label("Playing Audio Narration", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                .padding()
                                .background(Material.thin)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5)
                        }
                       /* VStack(alignment: .leading, spacing: 10) {
                            Text("Historic Site Video")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                            
                            if let player = player {
                                VideoPlayer(player: player)
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                                    .onAppear {
                                        player.play()
                                    }
                            }
                        }*/
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Enhanced Beacon Info Card with Rich Text
                    if isBeaconDetected {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                Text(isSimulating ? "Shotgun House" : getLocationName())
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                Spacer()
                            }
                            .padding(.bottom, 5)
                            
                            Divider()
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3))
                            
                            // Rich Historical Description
                            VStack(alignment: .leading, spacing: 15) {
                                // Year Built
                                HStack(alignment: .top) {
                                    Image(systemName: "calendar.circle.fill")
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Built in 1890")
                                            .font(.system(size: 16, weight: .semibold, design: .serif))
                                            .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                        Text("Over 130 years of history")
                                            .font(.system(size: 13, design: .serif))
                                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                                            .italic()
                                    }
                                }
                                
                                // Historical Context
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Historical Significance")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                    
                                    Text("The Shotgun House represents a distinctive architectural style that emerged in the American South during the post-Civil War era. Named for its long, narrow design—legend says you could fire a shotgun through the front door and the bullet would exit straight out the back—these homes were primarily built for working-class families.")
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.3))
                                        .lineSpacing(4)
                                }
                                
                                // Architectural Details
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Architectural Features")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        FeatureRow(feature: "Single-story wooden frame construction")
                                        FeatureRow(feature: "Rooms arranged in a linear fashion")
                                        FeatureRow(feature: "12-foot high ceilings for natural cooling")
                                        FeatureRow(feature: "Original heart pine flooring")
                                        FeatureRow(feature: "Decorative Victorian-era millwork")
                                    }
                                }
                                
                                // Cultural Impact
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Cultural Heritage")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                    
                                    Text("This house served as home to multiple generations of Montgomery families, witnessing the city's transformation from Reconstruction through the Civil Rights Movement. Its preservation offers visitors a tangible connection to the everyday lives of working families who built Old Town Montgomery.")
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.3))
                                        .lineSpacing(4)
                                }
                                
                                // Did You Know Section
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(Color(red: 0.8, green: 0.6, blue: 0.2))
                                        Text("Did You Know?")
                                            .font(.system(size: 16, weight: .bold, design: .serif))
                                            .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                                    }
                                    
                                    Text("Shotgun houses influenced modern sustainable architecture with their emphasis on natural ventilation and efficient use of space. Many contemporary tiny homes draw inspiration from these historic structures.")
                                        .font(.system(size: 14, design: .serif))
                                        .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.3))
                                        .lineSpacing(4)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(red: 1, green: 0.95, blue: 0.85).opacity(0.5))
                                        )
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.95))
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // CTA Button
                    if isBeaconDetected {
                        Button(action: {
                            let url = isSimulating ?
                                URL(string: "https://www.touroldalabamatown.com")! :
                                (beaconDetector.detectedURL ?? URL(string: "https://www.touroldalabamatown.com")!)
                            onExploreTapped(url)
                        }) {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "book.fill")
                                    Text("Explore Full History")
                                        .font(.system(size: 18, weight: .semibold, design: .serif))
                                    Image(systemName: "arrow.right")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.5, green: 0.3, blue: 0.15),
                                            Color(red: 0.6, green: 0.4, blue: 0.2)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                                
                                Text("View photos, documents, and more")
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                                    .italic()
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 30)
                    
                    // Bluetooth Status
                    if !beaconDetector.isBluetoothOn && !isSimulating {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(red: 0.7, green: 0.4, blue: 0.2))
                                Text("Bluetooth Required")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.2))
                            }
                            
                            Text("Enable Bluetooth to discover nearby historic sites on your walking tour.")
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Open Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white.opacity(0.95))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color(red: 0.7, green: 0.4, blue: 0.2), lineWidth: 2)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                        .padding(.horizontal)
                    }
                    
                    // Footer
                    Text("Old Town Montgomery • Alabama")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func getLocationName() -> String {
        switch String(beaconDetector.instance) {
        case "000000000004":
            return "Shotgun House"
        case "000000000001":
            return "Pole Barn"
        default:
            return "Historic Site"
        }
    }
    
    private func setupSimulationVideo() {
        // Replace this URL with your actual video URL
        // For local video: Bundle.main.url(forResource: "historic-site", withExtension: "mp4")
        // For remote video: URL(string: "https://your-video-url.com/video.mp4")
        
        // Using a sample video URL - replace with your actual video
        if let videoURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4") {
            player = AVPlayer(url: videoURL)
            player?.volume = 0.5
            
            // Loop the video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
    }
    
    private func playSimulationAudio() {
        // IMPORTANT: Replace "narration" with the actual name of your MP3 file.
        guard let audioURL = Bundle.main.url(forResource: "intro", withExtension: "mp3") else {
            print("Audio file 'intro.mp3' not found in project bundle.")
            return
        }
        
        // Configure the audio session to allow playback even in silent mode.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
        
        // Create the player instance and start playing automatically.
        audioPlayer = AVPlayer(url: audioURL)
        audioPlayer?.play()
    }

    private func stopSimulation() {
        isSimulating = false
        showVideo = false
        
        // Pause and clean up the video player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        // Remove any observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let feature: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            Text(feature)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.3))
                .lineSpacing(2)
        }
    }
}

// MARK: - Web View Page
struct WebViewPage: View {
    let url: URL
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Back to Tour")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15))
                }
                .padding()
                
                Spacer()
            }
            .background(Color.white.opacity(0.8))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .bottom
            )

            SafariView(url: url)
                .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(Color(red: 0.96, green: 0.93, blue: 0.88).ignoresSafeArea())
    }
}

// MARK: - Helper Views
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
