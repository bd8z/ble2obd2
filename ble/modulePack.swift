import SwiftUI
import CoreBluetooth

import CoreLocation
import CoreLocationUI


final class Bluetooth: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    @Published var buttonText:String = "Scan Start"
    @Published var recorButtonText:String = "Record Start"
    @Published var isPushed = false
    
    var CENTRAL:CBCentralManager?
    @Published public var foundPeripheralNameArray:[foundPeripheral] = []
    @Published public var foundPeripheralArray:[CBPeripheral] = []
  
    
    public var discoveredPeripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic? = nil
    var readCharacteristic: CBCharacteristic? = nil

    @Published public var responseMessage:String = "start"
    @Published public var debugMessage:String = "debag Start"

    
    var isRecordingStarted = false
    var wrimane = fileWriteManager.shared
    var myloopTimer:Timer = Timer.init()
    
    var conncectedDeciveSetting:bleDeciveSetting?
    var deviceNameArray:[String] = []
    
    private let deviceList = deviceLibrary().deviceList
    public let timeInterval:Double = 0.005
    public var commandtext:[String] = ["010C","010D"] //if not selected
    public var stremaer = dataStream.shared
    public var writeTimeCounter:Int = 0
    var writeCounter:Int64 = 0

    //メンバ変数初期化 NSObject
    override init() {
        super.init()
        CENTRAL = CBCentralManager( delegate:self,queue:nil )
    }

    
    // status update
    func centralManagerDidUpdateState( _ central:CBCentralManager ) {
        print("centralManagerDidUpdateState.state=\(central.state.rawValue)")
        //central.state is .poweredOff,.poweredOn,.resetting,.unauthorized,.unknown,.unsupported
        if central.state == .poweredOn {
        }
        else{
            stopScan()
        }
    }
    
    func disconnectPeripheral() {
        if discoveredPeripheral != nil {
            CENTRAL?.cancelPeripheralConnection( discoveredPeripheral! )
            discoveredPeripheral = nil
        }
        readCharacteristic = nil
        writeCharacteristic = nil
    }
    
    func startScan(){
        stopScan()
        foundPeripheralNameArray = []
        buttonText = "Scanning"
        CENTRAL?.scanForPeripherals( withServices:nil,options:nil )
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.stopScan()
            self.isPushed = true
            self.buttonText = "Scan Restart"
        }
    }
    
    func stopScan(){
        CENTRAL?.stopScan()
    }
    
    @objc func scanTimeout() {
        stopScan()
    }
    

    
    // discover peripheral
    func centralManager( _ central:CBCentralManager,didDiscover peripheral:CBPeripheral,
                         advertisementData:[String:Any],rssi RSSI:NSNumber ) {
        foundPeripheralNameArray.append(foundPeripheral(name: (peripheral.name ?? "no name"),identifier: peripheral.identifier.uuidString, signalLevel:String(RSSI.int32Value)))
        foundPeripheralArray.append(peripheral)
    }
    
    func connectePeripheral(conncetUUID:String){
        for peripheral in foundPeripheralArray {
            if (peripheral.identifier.uuidString == conncetUUID) {
                CENTRAL?.connect(peripheral, options: nil)
                print("didDiscover and start connect")
                discoveredPeripheral = peripheral
            }
        }
    }
    
    // connect peripheral OK
    func centralManager( _ central:CBCentralManager,didConnect peripheral:CBPeripheral ) {
        print("didConnect")
        self.buttonText = "Disconnect"
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        discoveredPeripheral = peripheral
    }
    
    // connect peripheral NG
    func centralManager( _ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error? ) {
        print("didFailToConnect")
    }
    
    // disconnect peripheral RESULT
    func centralManager( _ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error? ) {
        print("didDisconnectPeripheral")
        self.buttonText = "Scan Restart"
    }
    
    // discover services
    func peripheral( _ peripheral:CBPeripheral,didDiscoverServices error:Error? ) {
        print("didDiscoverServices")
        if let error = error {
            print("Error discovering services: %s", error.localizedDescription)
            return
        }
        
        print("start")
        for service in peripheral.services! {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("end")
    }
    
    // discover characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        //print(service.characteristics!)
        if let error = error {
            print("Error discovering characteristics: %s", error.localizedDescription)
            return
        }
        
        
        let tmpCharaArray = service.characteristics!.map({ st -> String in return st.uuid.uuidString})
        let foundSrv = foundService(serviceUUID: service.uuid.uuidString, characteristicUUID: tmpCharaArray)
        //Set Wirte and Read characteristic
        for device in deviceList{
            if discoveredPeripheral!.name == device.deviceName{
                if (foundSrv.characteristicUUID.contains(device.readUUID) && foundSrv.characteristicUUID.contains(device.writeUUID)){
                    print("setOK")
                    print(device)
                    conncectedDeciveSetting = device
                    for characteristic in service.characteristics!{
                        if (characteristic.uuid.uuidString == conncectedDeciveSetting?.writeUUID){
                            self.writeCharacteristic = characteristic
                            print("書き込み先")
                            print(characteristic)
                        }
                        
                        if (characteristic.uuid.uuidString == conncectedDeciveSetting?.readUUID){
                            self.readCharacteristic = characteristic
                            print("読み込み先`")
                            print(characteristic)
                            discoveredPeripheral?.setNotifyValue(true, for: characteristic)
                        }
                    }
                    break
                }
            }
        }
    }
}


extension Bluetooth{
    
    public func writeFunction(){
        let command_:String = commandtext[writeTimeCounter % commandtext.count]

            guard let data2 = (command_ + "\r").data(using: .utf8) else {
                return
            }
        discoveredPeripheral?.writeValue(data2, for: self.writeCharacteristic!, type: conncectedDeciveSetting!.writeType)
        writeTimeCounter += 1
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        //print("Peripheral is ready, send data")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value, let callbackString = String(data: value, encoding: .utf8), !callbackString.isEmpty else {
            return
        }
        var tmpString:String
        tmpString = callbackString.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "/")
        print("<---tempString ",tmpString, " tempString--->")
        stremaer.dataAppend(tmpData: tmpString)
        responseMessage = stremaer.dataGet()
        debugMessage = stremaer.sendData

        // Deal with errors (if any)
        if let error = error {
            print("Error discovering characteristics: %s", error.localizedDescription)
            return
        }
    }
    
    func startRecord(){
        isRecordingStarted = true
        recorButtonText = "Record Stop"
        
        if wrimane.isStarted == false{
            wrimane.recordStart()
        }
        
        writeCounter = 0
        stremaer.writableFlag = true
        
        
        
        
        // Once this is complete, we just need to wait for the data to come in.
        let interval_func = { [self] (time:Timer) in
            if stremaer.writableFlag == true{
                print("Write! counter:" + String(writeCounter))
                stremaer.writableFlag = false
                self.writeFunction()
                writeCounter = writeCounter + 1
            }
                
            }
        myloopTimer = Timer.scheduledTimer(withTimeInterval: timeInterval,
                                           repeats: true,
                                           block: interval_func)
    }
    
    func stopRecord(){
        myloopTimer.invalidate()
        isRecordingStarted = false
        wrimane.isStarted = false
        stremaer.resetBuffer()
        recorButtonText = "Record Start"

    }
}

final public class dataStream{
    public var receivedData:String = ""
    public var responce:String = "Start!"
    let dateFormatter = DateFormatter()
    var dateString:String = ""
    var sendData:String = ""
    public var writableFlag = true
    public var responceFirstMessage:String = ""
    var wrimane = fileWriteManager.shared
    public var dataSendFlg = false
    public var writeData:String = ""
    
    private init(){}
    public static let shared = dataStream()
    
    let errorMessageArray:[String] = deviceLibrary().errorMessageArray

    func dataAppend(tmpData:String){
        receivedData = receivedData + tmpData
        print("recievdData:" + receivedData)
        
        if receivedData.contains(">"){
            let tmpSeparatedDataArray = (receivedData.split(separator: ">", maxSplits: 1))
            
        //prev stream data
        if tmpSeparatedDataArray.count > 1 {
            receivedData = String(tmpSeparatedDataArray[1])
            responce = String(tmpSeparatedDataArray[0])
            dataSendFlg = true
        }
        else if tmpSeparatedDataArray.count == 1 && receivedData.hasSuffix(">"){
            receivedData = ""
            responce = String(tmpSeparatedDataArray[0])
            dataSendFlg = true
        }
        
        else{
            dataSendFlg = false
        }
          
        if dataSendFlg == true{
            print("<--response:" + responce)
            //prepalation for obdCal function
            sendData = responce.replacingOccurrences(of: " ", with: "").split(separator: "/").joined(separator: "/")
            print("<--sendData generation:" + sendData)
            
            let tmpResponceFirstMessage = responce.split(separator: "/")
            if tmpResponceFirstMessage.count > 1{
                responceFirstMessage = String(tmpResponceFirstMessage[1])
                print(responceFirstMessage)

            }
            
            //understand reply from obd and write file
            if errorMessageArray.firstIndex(of: responceFirstMessage)  != nil || (sendData.count < 5) {
                print("detect no data")
                writeData = (responce).split(separator: "/").joined(separator: ",")
            }
            else{
                print("<---obdCallToSend " + sendData + " obdCallToSend--->")
                writeData = (obdCal(input:sendData)).split(separator: "/").joined(separator: ",")
            }
            wrimane.appendText(inputString: writeData)
            writableFlag = true

        }
        else{
            print("data collecting...")
        }
        }
    }
    func dataGet() -> String{
        return responce
    }
    
    func resetBuffer(){
        responce = ""
        receivedData = ""
        dataSendFlg = false
        writableFlag = true
        writeData = ""
        responceFirstMessage = ""
    }

}


class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var lastKnownLocation: CLLocation?
    @Published var lastKnownHead: CLHeading?
//    @Published var heading:CLLocationDirection = 0
//    @Published var headingAcc:CLLocationDirectionAccuracy = 0
    
    @Published var lat = "0.0"
    @Published var lon = "0.0"
    @Published var elv = "0.0"
    @Published var AccH = "0.0"
    @Published var AccV = "0.0"
    @Published var spd = "0.0"
    @Published var spdAcc = "0.0"
    @Published var gpsHaed = "0.0"
    @Published var gpsHeadAcc = "0.0"
    @Published var magHaed = "0.0"
    @Published var magHeadAcc = "0.0"
    @Published var trueHead = "0.0"
    @Published var cnt = 0

    var wrimane = fileWriteManager.shared

    
    //gps setting
    override init(){
        //gps
        self.manager.requestWhenInUseAuthorization() //
        self.manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation //highest possible accuracy
        self.manager.distanceFilter = 0 //filetr
        self.manager.pausesLocationUpdatesAutomatically = true //ポーズしても位置取得を続ける
        
        
        //compass
        self.manager.headingFilter = kCLHeadingFilterNone
        self.manager.headingOrientation = .portrait
    }
    
    
    func start() {
        self.manager.delegate = self
        self.manager.startUpdatingLocation()
        self.manager.startUpdatingHeading()
        if wrimane.isStarted == false{
            wrimane.recordStart()
        }
    }
    
    func stop() {
        self.manager.delegate = self
        self.manager.stopUpdatingLocation()
        self.manager.stopUpdatingHeading()
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastKnownHead = newHeading
        
        //Optional Double
        magHaed = String(format:"%.3f", lastKnownHead?.magneticHeading ?? 0.0)
        magHeadAcc = String(format:"%.3f", lastKnownHead?.headingAccuracy ?? 0.0)
        trueHead = String(format:"%.3f", lastKnownHead?.trueHeading ?? 0.0)
        
        //print(magHaed)
        
    }

    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
        
        //Optional Double
        lat = String(format:"%.7f", lastKnownLocation?.coordinate.latitude ?? 0.0)
        lon = String(format:"%.7f", lastKnownLocation?.coordinate.longitude ?? 0.0)
        elv = String(format:"%.3f", lastKnownLocation?.altitude ?? 0.0)
        AccH = String(format:"%.3f", lastKnownLocation?.horizontalAccuracy ?? 0.0)
        AccV = String(format:"%.3f", lastKnownLocation?.verticalAccuracy ?? 0.0)
        spd = String(format:"%.3f", (lastKnownLocation?.speed ?? 0.0)*3.6)
        spdAcc = String(format:"%.3f", (lastKnownLocation?.speedAccuracy ?? 0.0)*3.6)
        gpsHaed = String(format:"%.3f", lastKnownLocation?.course ?? 0.0)
        gpsHeadAcc = String(format:"%.3f", lastKnownLocation?.courseAccuracy ?? 0.0)
        cnt = cnt + 1
        
        

        let writeData:String = "loc," + [lat, lon, elv, AccH, AccV, spd, spdAcc, gpsHaed, gpsHeadAcc].joined(separator: ",")
        wrimane.appendText(inputString: writeData)
    }
}

final public class fileWriteManager{
    let dateFormatter = DateFormatter()
    var dateString:String = ""
    var filepath = ""

    private init(){}
    public static let shared = fileWriteManager()
    
    var isStarted = false
    
    func recordStart(){
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.timeZone = TimeZone(identifier:  "Asia/Tokyo")
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        dateString = dateFormatter.string(from: Date())

        filepath = NSHomeDirectory() + "/Documents/" + dateString + ".txt"
        let text = "header"
        do {
            // テキストの書き込みを実行
            try text.write(toFile: filepath, atomically: true, encoding: .utf8)
            print("成功\nopen ", filepath)
            isStarted = true

        } catch {
            //　テストの書き込みに失敗
            print("失敗:", error )
        }
    }
    func appendText(inputString: String) {
        let now = Date()
        let timeStamp:String = String(now.timeIntervalSince1970) + ","
 
        
        do {
            let fileHandle = try FileHandle(forWritingTo: URL(string:filepath)!)
            // 改行を入れる
            let stringToWrite = "\n" + timeStamp + inputString
            // ファイルの最後に追記
            fileHandle.seekToEndOfFile()
            fileHandle.write(stringToWrite.data(using: String.Encoding.utf8)!)
        } catch let error as NSError {
            print("failed to append: \(error)")
        }
    }
    
}







