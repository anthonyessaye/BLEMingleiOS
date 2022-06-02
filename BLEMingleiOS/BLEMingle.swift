import Foundation
import CoreBluetooth

extension String {
    subscript  (r: Range<Int>) -> String {
            get {
                let myNSString = self as NSString
                let start = r.lowerBound
                let length = r.upperBound - start + 1
                
                return myNSString.substring(with: NSRange(location: start, length: length))
            }
    }
    
    func separatedComponents(separator: Character) -> [String] {
       return self.split(separator: separator).map(String.init)
   }
    
    func dataFromHexadecimalString() -> NSData? {
        let myNSString = self as NSString
        let midString = myNSString.trimmingCharacters(in: NSCharacterSet(charactersIn: "<> ") as CharacterSet) as NSString
        let trimmedString = midString.replacingOccurrences(of: " ", with: "")
        
        // make sure the cleaned up string consists solely of hex digits, and that we have even number of them
        
        let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$",
                                             options: [.caseInsensitive])
        
        let this_max = trimmedString.count
        let found = regex.firstMatch(in: trimmedString, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, this_max))
        if found == nil || found?.range.location == NSNotFound || this_max % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData
        
        let data = NSMutableData(capacity: this_max / 2)
        
        for i in 0 ..< ((trimmedString.count / 2) - 1) {
            let lower = i * 2
            let upper = lower + 2
            let byteString = trimmedString[lower..<upper]
            let something = byteString.withCString { strtoul($0, nil, 16) }
            let num = UInt16(something)
            data?.append([num] as [UInt16], length: 1)
        }
        
        return data
    }
}

extension NSData {
    func toHexString() -> String {
        
        let string = NSMutableString(capacity: length * 2)
        var byte: UInt8 = 0
        
        for i in 0 ..< length {
            getBytes(&byte, range: NSMakeRange(i, 1))
            string.appendFormat("%02x", byte)
        }
        
        return string as String
    }
}

class BLEMingle: NSObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic!
    var dataToSend: NSData!
    var sendDataIndex: Int!
    var datastring: String!
    var sendingEOM: Bool = false
    let MAX_TRANSFER_DATA_LENGTH: Int = 20
    let TRANSFER_SERVICE_UUID:String = "00002A00-0000-1000-8000-00805F9B34FB"
    let TRANSFER_CHARACTERISTIC_UUID:String = "00002A00-0000-1000-8000-00805F9B34FB"
    var sendUuid = "00002A00-0000-1000-8000-00805F9B34FB"
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral!
    var data: NSMutableData!
    var finalString: String!
    var lastString: NSString!
    var usedList: [String]!
    var newList: [String]!
    var delegate: BLECentralDelegate?
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        data = NSMutableData()
        finalString = ""
        lastString = ""
        usedList = ["Zygats","Quiltiberry"]
        newList = usedList
        print("[BLEMingle]: " + "initCentral")
    }
    
    func startScan() {
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
        print("[BLEMingle]: " + "Scanning started")
    }
    
    func didDiscoverPeripheral(peripheral: CBPeripheral!) -> CBPeripheral! {
        if (peripheral != nil)
        {
            return peripheral;
        }
        return nil
    }
    
    func stopScan() {
        centralManager.stopScan()
        
        print("[BLEMingle]: " + "Scanning stopped")
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
    }
    
    
    func hexToScalar(char: String) -> UnicodeScalar? {
        var total = 0
        for scalar in char.uppercased().unicodeScalars {
             if !(scalar >= "A" && scalar <= "F" || scalar >= "0" && scalar <= "9") {
                print(scalar)
            }
            
            if scalar >= "A" {
                total = 16 * total + 10 + Int(scalar.value) - 65 /* 'A' */
            } else {
                total = 16 * total + Int(scalar.value) - 48 /* '0' */
            }
        }
        return UnicodeScalar(total)
    }
    
    func centralManager(_: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber){
        
        delegate?.didDiscoverPeripheral(peripheral)
        let splitUp : [String] = "\(advertisementData)".components(separatedBy: "\n")
        
        if (splitUp.count > 1)
        {
            var chop = splitUp[1]
            let counter = chop.count - 2
            
            if counter >= 0 {
            
                chop = chop[0..<counter]

                let chopSplit : [String] = "\(chop)".components(separatedBy: "\"")
                
                print("[BLEMingle]: \(chop)")
                
                if !(chopSplit.count > 1 && chopSplit[1] == "Device Information") && chop.count == 26 {
                    let hexString = chop[4..<7] + chop[12..<19] + chop[21..<26]
                    let hexArray = [hexString[0..<1], hexString[2..<3], hexString[4..<5], hexString[6..<7], hexString[8..<9], hexString[10..<11], hexString[12..<13], hexString[14..<15], hexString[16..<17]]
                     
                    var currentScalar: UnicodeScalar?
                    
                    for char in hexArray {
                        currentScalar = hexToScalar(char: char)
                        if currentScalar == nil {
                            break
                        }
                    }
                     
                    
                    if currentScalar != nil {
                    let charArray = hexArray.map { Character(hexToScalar(char: $0)!) }
                    let string = String(charArray) as String?
                        if (string == nil) {
                        }
                        
                        else if (!usedList.contains(string!)) {
                            usedList.append(string!)
                            let this_count = string!.count
                            if (this_count == 9 && string![this_count-1..<this_count-1] == "-")
                            {
                                finalString = finalString + string![0..<this_count-2]
                            }
                            else
                            {
                                lastString = finalString + string! + "\n" as NSString
                                print("[BLEMingle]: " + (lastString as String))
                                finalString = ""
                                usedList = newList
                                usedList.append(string!)
                            }
                        }
                    }
                    
                    else {
                        lastString = "Tried Parsing something I can't understand"
                    }
                    
                }
            }
        }
    }
    
    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
    }
    
    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("[BLEMingle]: " + "Connected to peripheral: \(peripheral)")
        
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: TRANSFER_SERVICE_UUID)])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            return
        }
        
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)], for: service )
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("[BLEMingle]: " + "didDiscoverCharacteristicsForService: \(service)")
        
        for characteristic in service.characteristics ?? [] {
            if ((characteristic ).uuid.isEqual(CBUUID(string: TRANSFER_CHARACTERISTIC_UUID))) {
                print("[BLEMingle]: " + "Discovered characteristic: \(characteristic)")
                peripheral .setNotifyValue(true, for: characteristic )
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            return
        }
        
        let stringFromData = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue)
        
        if (stringFromData! == "EOM") {
            print("[BLEMingle]: " + "Data Received: \(NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue))")
            data.length = 0
                        peripheral.setNotifyValue(false, for: characteristic)
                        centralManager.cancelPeripheralConnection(peripheral)
        }
        else {
            data.append(characteristic.value!)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            return
        }
        
        if !characteristic.uuid.isEqual(CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)) {
            return
        }
        
        if characteristic.isNotifying {
            print("[BLEMingle]: " + "Notification began on: \(characteristic)")
        }
        else {
            print("[BLEMingle]: " + "Notification stopped on: \(characteristic). Disconnecting")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BLEMingle]: " + "Peripheral Disconnected")
        discoveredPeripheral = nil
    }
    
    func StringToUUID(coupon: String, studyId: String) -> String {
        
        var studyId = studyId
        print("Study Id: \(studyId)")
        
        while studyId.count < 4 {
            studyId = "0" + studyId
        }
        
        print("Fixed Id: \(studyId)")
        
        let hex = coupon + studyId
        
        var rev = String(hex.reversed())
        let hexData: NSData! = rev.data(using: String.Encoding.utf8, allowLossyConversion: false) as! NSData
        dataToSend = hexData
        
        // String Structure = "xxxxYYYYYYYYYYzzzz'
        // x -> CRC
        // y -> coupon
        // z -> studyId
        
        rev =  String(calcCRC8(Array(hex.utf8))) + hexData.toHexString()
        
        while(rev.count < 32) {
            rev = "0" + rev;
        }
        rev = rev[0..<31]
        let finalString = rev[0..<7] + "-" + rev[8..<11] + "-" + rev[12..<15] + "-" + rev[16..<19] + "-" + rev[20..<31]
        
        
        return finalString
    }
    
    class var sharedInstance: BLEMingle {
        struct Static {
            static let instance: BLEMingle = BLEMingle()
        }
        return Static.instance
    }
    
    func sendDataToPeripheral(data: NSData) {
        dataToSend = data
        startAdvertisingToPeripheral()
    }
    
    func startAdvertisingToPeripheral() {
        if (dataToSend != nil)
        {
            datastring = NSString(data:dataToSend as Data, encoding:String.Encoding.utf8.rawValue) as! String
            
            let count = Double(datastring.count)
            for i in 0..<Int(ceil(count / 14.0000))
            {
                let time = DispatchTime.now() + .milliseconds(100 * i)
                let stop = DispatchTime.now() + .milliseconds(100 * (i+1))
                if ((datastring.count - (14 * i)) > 14)
                {
                    let piece = datastring[(14 * i)..<(14 * (i + 1) - 1)] + "-"
                    DispatchQueue.main.asyncAfter(deadline: time) {
                        () -> Void in self.sendMessage(message: piece);
                    }
                }
                else
                {
                    let piece = datastring[(14 * i)..<(datastring.count-1)]
                    DispatchQueue.main.asyncAfter(deadline: time) {
                        () -> Void in self.sendMessage(message: piece);
                    }
                    /*DispatchQueue.main.asyncAfter(deadline: stop) {
                        () -> Void in self.peripheralManager.stopAdvertising();
                    } */
                }
            }
        }
    }
    
    func calcCRC8(_ buf : [UInt8]) -> UInt8 {
        let tableCRC8 : [UInt8] = [
            0x00, 0x07, 0x0E, 0x09, 0x1C, 0x1B, 0x12, 0x15,0x38, 0x3F, 0x36, 0x31, 0x24, 0x23, 0x2A, 0x2D,
            0x70, 0x77, 0x7E, 0x79, 0x6C, 0x6B, 0x62, 0x65,0x48, 0x4F, 0x46, 0x41, 0x54, 0x53, 0x5A, 0x5D,
            0xE0, 0xE7, 0xEE, 0xE9, 0xFC, 0xFB, 0xF2, 0xF5, 0xD8, 0xDF, 0xD6, 0xD1, 0xC4, 0xC3, 0xCA, 0xCD,
            0x90, 0x97, 0x9E, 0x99, 0x8C, 0x8B, 0x82, 0x85,0xA8, 0xAF, 0xA6, 0xA1, 0xB4, 0xB3, 0xBA, 0xBD,
            0xC7, 0xC0, 0xC9, 0xCE, 0xDB, 0xDC, 0xD5, 0xD2, 0xFF, 0xF8, 0xF1, 0xF6, 0xE3, 0xE4, 0xED, 0xEA,
            0xB7, 0xB0, 0xB9, 0xBE, 0xAB, 0xAC, 0xA5, 0xA2,0x8F, 0x88, 0x81, 0x86, 0x93, 0x94, 0x9D, 0x9A,
            0x27, 0x20, 0x29, 0x2E, 0x3B, 0x3C, 0x35, 0x32,0x1F, 0x18, 0x11, 0x16, 0x03, 0x04, 0x0D, 0x0A,
            0x57, 0x50, 0x59, 0x5E, 0x4B, 0x4C, 0x45, 0x42,0x6F, 0x68, 0x61, 0x66, 0x73, 0x74, 0x7D, 0x7A,
            0x89, 0x8E, 0x87, 0x80, 0x95, 0x92, 0x9B, 0x9C,0xB1, 0xB6, 0xBF, 0xB8, 0xAD, 0xAA, 0xA3, 0xA4,
            0xF9, 0xFE, 0xF7, 0xF0, 0xE5, 0xE2, 0xEB, 0xEC, 0xC1, 0xC6, 0xCF, 0xC8, 0xDD, 0xDA, 0xD3, 0xD4,
            0x69, 0x6E, 0x67, 0x60, 0x75, 0x72, 0x7B, 0x7C,0x51, 0x56, 0x5F, 0x58, 0x4D, 0x4A, 0x43, 0x44,
            0x19, 0x1E, 0x17, 0x10, 0x05, 0x02, 0x0B, 0x0C,0x21, 0x26, 0x2F, 0x28, 0x3D, 0x3A, 0x33, 0x34,
            0x4E, 0x49, 0x40, 0x47, 0x52, 0x55, 0x5C, 0x5B,0x76, 0x71, 0x78, 0x7F, 0x6A, 0x6D, 0x64, 0x63,
            0x3E, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2C, 0x2B,0x06, 0x01, 0x08, 0x0F, 0x1A, 0x1D, 0x14, 0x13,
            0xAE, 0xA9, 0xA0, 0xA7, 0xB2, 0xB5, 0xBC, 0xBB,0x96, 0x91, 0x98, 0x9F, 0x8A, 0x8D, 0x84, 0x83,
            0xDE, 0xD9, 0xD0, 0xD7, 0xC2, 0xC5, 0xCC, 0xCB, 0xE6, 0xE1, 0xE8, 0xEF, 0xFA, 0xFD, 0xF4, 0xF3 ];
        
        
        var crc = UInt8.min
        
        for byte in buf {
            let x = crc ^ byte
            crc = tableCRC8[Int(x)]
        }
        
        return crc
    }
    
    func sendMessage(message: String)
    {
        //"cmugdpqiah24"
        let coupon = "cmugdpqiah"
        let studyId = "24"
        let couponUUID = StringToUUID(coupon: coupon, studyId: studyId)
        let name = sendUuid.separatedComponents(separator: "-")
        
        if name[0] != "" {
            print(couponUUID)
            peripheralManager.stopAdvertising()
            peripheralManager.startAdvertising([CBAdvertisementDataLocalNameKey: "ODIN-iOS",
                                            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: couponUUID)]])
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        if #available(iOS 10.0, *) {
            if peripheral.state != CBManagerState.poweredOn {
                return
            }
        } else {
            // Fallback on earlier versions
        }
        
        print("[BLEMingle]: " + "self.peripheralManager powered on.")
        
        transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TRANSFER_CHARACTERISTIC_UUID), properties: CBCharacteristicProperties.notify, value: nil, permissions: CBAttributePermissions.readable)
        
        let transferService = CBMutableService(type: CBUUID(string: TRANSFER_SERVICE_UUID), primary: true)
        
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager.add(transferService)
        
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        
        print("[BLEMingle]: " + "Central subscribed to characteristic: \(characteristic)")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        
        print("[BLEMingle]: " + "Central unsubscribed from characteristic")
    }
    
    func transferData() {
        if sendingEOM {
            
            var didSend:Bool = peripheralManager.updateValue("EOM".data(using: String.Encoding.utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            if didSend {
                
                sendingEOM = false
                print("[BLEMingle]: " + "sending EOM")
               // sleep(10000)
               // peripheralManager.stopAdvertising()
            }
            
            return
        }
        
        if sendDataIndex >= dataToSend.length {
            return
        }
        
        var didSend:Bool = true
        
        while(didSend) {
            var amountToSend:Int = dataToSend.length - sendDataIndex
            
            if amountToSend > MAX_TRANSFER_DATA_LENGTH {
                amountToSend = MAX_TRANSFER_DATA_LENGTH
            }
            
            var chunk = NSData(bytes: dataToSend.bytes + sendDataIndex, length: amountToSend)
            print("[BLEMingle]: " + "chunk: \(NSString(data: chunk as Data, encoding: String.Encoding.utf8.rawValue)!)")
            
            didSend = peripheralManager.updateValue(chunk as Data, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            if !didSend {
                print("[BLEMingle]: " + "didnotsend")
                return;
            }
            
            var stringFromData = NSString(data: chunk as Data, encoding: String.Encoding.utf8.rawValue)
            print("[BLEMingle]: " + "Sent: " + (stringFromData! as String))
            
            sendDataIndex = sendDataIndex + amountToSend
            
            if sendDataIndex >= dataToSend.length {
                sendingEOM = true
                
                let eomSent = peripheralManager.updateValue("EOM".data(using: String.Encoding.utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    sendingEOM = false
                    print("[BLEMingle]: " + "Sending EOM")
                }
                
                return
            }
        }
    }
    
    func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        print("[BLEMingle]: " + "Ready to transfer")
        transferData()
    }
}
