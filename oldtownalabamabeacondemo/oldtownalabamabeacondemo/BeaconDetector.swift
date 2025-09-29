
import Foundation
import CoreBluetooth
import SwiftUI

struct TargetBeacon {
    let namespace: String
    let instance: String
    let url: String
    
    var identifier: String {
        return "\(namespace)-\(instance)".uppercased()
    }
}

class EddystoneBeaconDetector: NSObject, ObservableObject {
    @Published var statusText = "Scanning for Old Town Montgomery beacons..."
    @Published var isDetected = false
    @Published var beaconType = "Unknown"
    @Published var namespace = ""
    @Published var instance = ""
    @Published var rssi: Int = 0
    @Published var distanceString = "Unknown"
    @Published var isBluetoothOn = true
    @Published var shouldOpenURL = false
    @Published var detectedURL: URL?
    
    // MARK: - Configuration
    // IMPORTANT: Configure your list of Eddystone beacons and their URLs here
    let targetBeacons: [TargetBeacon] = [
        TargetBeacon(
            namespace: "00000000000000000001",
            instance: "000000000004",
            url: "https://touroldalabamatown.com/living-block/shotgun-house"
        ),
        TargetBeacon(
            namespace: "00000000000000000001",
            instance: "000000000001", // A different instance for the second beacon
            url: "https://touroldalabamatown.com/living-block/pole-barn" // A different URL
        ),
    TargetBeacon(
        namespace: "00000000000000000001",
        instance: "000000000002",
        url: "https://touroldalabamatown.com/living-block/lucas-tavern"
    ),
    TargetBeacon(
        namespace: "00000000000000000001",
        instance: "000000000003",
        url: "https://touroldalabamatown.com/living-block/church"
    ),
    TargetBeacon(
        namespace: "00000000000000000001",
        instance: "000000000005",
        url: "https://touroldalabamatown.com/living-block/corner-grocery-store"
    )
 
    ]
    
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var openedBeaconIdentifiers: Set<String> = [] // Tracks which beacons have auto-opened
    private var currentBeaconIdentifier: String? // Track the currently detected beacon
    private let eddystoneServiceUUID = CBUUID(string: "FEAA")
    private var resetTimer: Timer? // Timer to reset detection status
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Helper Methods
    
    // This method is called by the timer to reset the UI to the scanning state.
    @objc private func resetDetectionStatus() {
        isDetected = false
        statusText = "Scanning for Old Town Montgomery beacons..."
        beaconType = "Unknown"
        namespace = ""
        instance = ""
        rssi = 0
        distanceString = "Unknown"
        currentBeaconIdentifier = nil
        // Don't clear detectedURL here - keep it for manual button press
    }
    
    private func calculateDistance(rssi: Int, measuredPower: Int = -59) -> Double {
        if rssi == 0 { return -1.0 }
        
        let ratio = Double(rssi) / Double(measuredPower)
        if ratio < 1.0 {
            return pow(ratio, 10)
        } else {
            let accuracy = (0.89976) * pow(ratio, 7.7095) + 0.111
            return accuracy
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 0 {
            return "Unknown"
        } else if distance < 1 {
            return String(format: "%.2f m (Immediate)", distance)
        } else if distance < 5 {
            return String(format: "%.2f m (Near)", distance)
        } else {
            return String(format: "%.2f m (Far)", distance)
        }
    }
    
    private func parseEddystoneFrame(_ serviceData: Data) -> (type: String, namespace: String?, instance: String?) {
        guard serviceData.count > 0 else { return ("Unknown", nil, nil) }
        
        let frameType = serviceData[0]
        
        switch frameType {
        case 0x00: // UID frame
            if serviceData.count >= 18 {
                let namespaceData = serviceData.subdata(in: 2..<12)
                let instanceData = serviceData.subdata(in: 12..<18)
                let namespace = namespaceData.map { String(format: "%02X", $0) }.joined()
                let instance = instanceData.map { String(format: "%02X", $0) }.joined()
                return ("UID", namespace, instance)
            }
        case 0x10: // URL frame
            return ("URL", nil, nil)
        case 0x20: // TLM frame
            return ("TLM", nil, nil)
        case 0x30: // EID frame
            return ("EID", nil, nil)
        default:
            break
        }
        
        return ("Unknown", nil, nil)
    }
}

// MARK: - CBCentralManagerDelegate
extension EddystoneBeaconDetector: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothOn = true
            statusText = "Scanning for Eddystone beacons..."
            // Start scanning for Eddystone beacons
            centralManager.scanForPeripherals(
                withServices: [eddystoneServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        case .poweredOff:
            isBluetoothOn = false
            statusText = "Bluetooth is off"
            centralManager.stopScan()
        case .unsupported:
            statusText = "Bluetooth not supported"
        case .unauthorized:
            statusText = "Bluetooth unauthorized"
        case .resetting:
            statusText = "Bluetooth resetting..."
        case .unknown:
            statusText = "Bluetooth state unknown"
        @unknown default:
            statusText = "Bluetooth state unknown"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Look for Eddystone service data
        guard let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
              let eddystoneData = serviceData[eddystoneServiceUUID] else {
            return
        }
        
        // Parse Eddystone frame
        let (frameType, discoveredNamespace, discoveredInstance) = parseEddystoneFrame(eddystoneData)
        
        // Ensure we have a namespace and instance to check against
        guard let discoveredNamespace = discoveredNamespace, let discoveredInstance = discoveredInstance else {
            return
        }
        
        // Check if the discovered beacon matches any of our targets
        let matchedBeacon = targetBeacons.first {
            $0.namespace.uppercased() == discoveredNamespace.uppercased() &&
            $0.instance.uppercased() == discoveredInstance.uppercased()
        }
        
        // If it's not a beacon we're looking for, do nothing.
        guard let target = matchedBeacon else {
            return
        }
        
        // We found a target beacon! Update the UI and reset the timer.
        DispatchQueue.main.async {
            // Invalidate any existing timer, since we've just seen a beacon.
            self.resetTimer?.invalidate()
            
            let beaconIdentifier = target.identifier
            let beaconChanged = self.currentBeaconIdentifier != beaconIdentifier
            
            self.isDetected = true
            self.statusText = "Historic Site Detected!"
            self.beaconType = "Eddystone-\(frameType)"
            self.namespace = discoveredNamespace
            self.instance = discoveredInstance
            self.rssi = RSSI.intValue
            
            let distance = self.calculateDistance(rssi: RSSI.intValue)
            self.distanceString = self.formatDistance(distance)
            
            // ALWAYS update the URL when we detect a beacon
            if let url = URL(string: target.url) {
                self.detectedURL = url  // Always update to current beacon's URL
            }
            
            // If this is a different beacon than before, update tracking
            if beaconChanged {
                self.currentBeaconIdentifier = beaconIdentifier
                
                // Auto-open URL only on first detection of each unique beacon
                if !self.openedBeaconIdentifiers.contains(beaconIdentifier) && frameType == "UID" {
                    self.openedBeaconIdentifiers.insert(beaconIdentifier)
                    self.shouldOpenURL = true  // Trigger auto-open for first-time detection
                }
            }
            
            // Schedule a new timer. If we don't see another beacon within 5 seconds,
            // the UI will reset to the "Scanning..." state.
            self.resetTimer = Timer.scheduledTimer(
                timeInterval: 5.0,
                target: self,
                selector: #selector(self.resetDetectionStatus),
                userInfo: nil,
                repeats: false
            )
        }
    }
}