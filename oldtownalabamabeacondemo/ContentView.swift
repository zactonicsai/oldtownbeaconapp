import SwiftUI
import CoreBluetooth
import SafariServices

struct ContentView: View {
    @StateObject private var beaconDetector = EddystoneBeaconDetector()
    
    // This state now controls which page is visible.
    // When nil, the main scanning view is shown.
    // When it has a URL, the web view page is shown.
    @State private var activeURL: URL? = nil
    
    var body: some View {
        ZStack {
            if let url = activeURL {
                // Show the new WebViewPage when a URL is active
                WebViewPage(url: url) {
                    // This is the action for the "Back" button
                    // It sets the activeURL to nil, returning to the main view.
                    withAnimation {
                        activeURL = nil
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                // Show the main scanning interface
                MainContentView(beaconDetector: beaconDetector) { url in
                    // This is the action for the "Explore" button
                    withAnimation {
                        activeURL = url
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            }
        }
        .onChange(of: beaconDetector.shouldOpenURL) { _, newValue in
            // This detects the beacon's trigger to auto-open a URL
            if newValue, let url = beaconDetector.detectedURL {
                withAnimation {
                    activeURL = url
                }
                // Reset the trigger so it doesn't fire again on its own
                beaconDetector.shouldOpenURL = false
            }
        }
    }
}

// MARK: - Main Content View
// Your original UI has been moved into this separate view for clarity.
struct MainContentView: View {
    @ObservedObject var beaconDetector: EddystoneBeaconDetector
    var onExploreTapped: (URL) -> Void // Callback to tell the ContentView to navigate
    
    var body: some View {
        ZStack {
            // Natural gradient background - warm earth tones
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.96, green: 0.93, blue: 0.88), // Warm beige
                    Color(red: 0.85, green: 0.82, blue: 0.75), // Light tan
                    Color(red: 0.92, green: 0.88, blue: 0.82)  // Soft sand
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
                
                // Status Icon and Text...
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
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: beaconDetector.isDetected ? "location.north.fill" : "location.slash")
                        .font(.system(size: 50))
                        .foregroundColor(beaconDetector.isDetected ?
                            Color(red: 0.2, green: 0.5, blue: 0.3) : // Forest green
                            Color(red: 0.6, green: 0.5, blue: 0.4))  // Muted brown
                        .symbolEffect(.pulse, isActive: beaconDetector.isDetected)
                }
                .padding(.vertical, 10)
                
                VStack(spacing: 5) {
                    Text(beaconDetector.isDetected ? "Historic Site Detected!" : "Searching for Historic Sites...")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(beaconDetector.isDetected ?
                            Color(red: 0.2, green: 0.5, blue: 0.3) :
                            Color(red: 0.4, green: 0.35, blue: 0.3))
                    
                    if !beaconDetector.isDetected {
                        Text("Walk near a historic marker to learn more")
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                            .italic()
                    }
                }
                .padding(.horizontal)
                
                // Beacon Info Card
                if beaconDetector.isDetected {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Spacer()
                        }
                        .padding(.bottom, 5)
                        
                        Divider()
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: 10) {
                            if !beaconDetector.namespace.isEmpty && beaconDetector.namespace != "N/A" {
                                switch String(beaconDetector.instance) {
                                case "000000000004":
                                    DetailRow(icon: "mappin.circle", label: "Location", value: "Shotgun House")
                                case "000000000001":
                                    DetailRow(icon: "mappin.circle", label: "Location", value: "Pole Barn")
                                default:
                                    DetailRow(icon: "questionmark.diamond", label: "Location", value: "Unknown")
                                }
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
                if beaconDetector.isDetected, let url = beaconDetector.detectedURL {
                    Button(action: {
                        // When tapped, call the closure to trigger navigation
                        onExploreTapped(url)
                    }) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Explore Historic Site")
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
                            
                            Text("Learn about this location's history")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.35))
                                .italic()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Bluetooth Status...
                 if !beaconDetector.isBluetoothOn {
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


// MARK: - Web View Page
// This is the new page that displays the website and the back button.
struct WebViewPage: View {
    let url: URL
    let onBack: () -> Void // Action to perform when back button is tapped

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with Back Button
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

            // The Safari View takes up the rest of the screen
            SafariView(url: url)
                .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(Color(red: 0.96, green: 0.93, blue: 0.88).ignoresSafeArea()) // Match background
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
