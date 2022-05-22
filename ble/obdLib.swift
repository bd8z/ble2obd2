//
//  obdLib.swift
//  ble
//
//  Created by 江口由祐 on 2022/05/21.
//

import Foundation
import CoreBluetooth

//Ble
struct deviceLibrary{
    let deviceList:[bleDeciveSetting] = [
        bleDeciveSetting(deviceName: "OBDII", serviceUUID: "FFF0", writeUUID: "FFF2", readUUID: "FFF1", writeType: .withoutResponse),
        bleDeciveSetting(deviceName: "OBDBLE", serviceUUID: "FFE0", writeUUID: "FFE1", readUUID: "FFE1", writeType: .withResponse),
        bleDeciveSetting(deviceName: "Viecar", serviceUUID: "FFF0", writeUUID: "FFF2", readUUID: "FFF1", writeType: .withoutResponse)
    ]
    let errorMessageArray:[String] = ["STOPPED", "SEARCHING...", "SEARCHING...","NO DATA", "CAN ERROR"]
}

struct foundPeripheral: Identifiable {
    let id = UUID()
    let name: String
    let identifier: String
    let signalLevel: String
}

struct bleDeciveSetting: Identifiable {
    let id = UUID()
    let deviceName: String
    let serviceUUID: String
    let writeUUID: String
    let readUUID: String
    let writeType: CBCharacteristicWriteType
}

//obd
struct obdCodesLibrary{
    let obdCodes:[obdCodeStructure] = [
        obdCodeStructure(code: "010C", name: "Engine speed", units: "rpm"),
        obdCodeStructure(code: "010D", name: "Vehicle speed", units: "km/h"),
        obdCodeStructure(code: "0111", name: "Throttle position", units: "%"),
        obdCodeStructure(code: "0104", name: "Calculated engine load", units: "%"),
        obdCodeStructure(code: "015B", name: "Hybrid battery pack remaining life", units: "%"),
        obdCodeStructure(code: "0166", name: "Control module voltage", units: "V"),
        obdCodeStructure(code: "0100", name: "PIDs supported [01 - 20]", units: "-"),
        obdCodeStructure(code: "0120", name: "PIDs supported [21 - 40]", units: "-"),
        obdCodeStructure(code: "0140", name: "PIDs supported [41 - 60]", units: "-"),
        obdCodeStructure(code: "0160", name: "PIDs supported [61 - 80]", units: "-"),
        obdCodeStructure(code: "0180", name: "PIDs supported [81 - A0]", units: "-"),
        obdCodeStructure(code: "01A0", name: "PIDs supported [A1 - C0]", units: "-"),
        obdCodeStructure(code: "01C0", name: "PIDs supported [C1 - E0]", units: "-"),
        obdCodeStructure(code: "0900", name: "Service 9 supported PIDs (01 to 20)", units: "-"),
        obdCodeStructure(code: "0902", name: "VIN", units: "-"),
        obdCodeStructure(code: "0151", name: "Fuel Type", units: "-"),
        obdCodeStructure(code: "019A", name: "Hybrid/EV Vehicle System Data, Battery, Voltage", units: "V"),
    ]
    
}


struct obdCodeStructure: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let units: String
}

//caseにする、共通処理にするためにCODEと実態に分離して下位アプリに流す
func obdCal(input:String)->String{
    var caldValue:String = ""
    let obdCode:String = String(String(input.split(separator: "/")[0]))
    let tmp_:String = String(input.split(separator: "/")[input.split(separator: "/").count - 2])
    let receivedData:String = String(tmp_.suffix(tmp_.count - 4))
    if obdCode == "010C"{
        let (A, B):(Double, Double) = twoByteRetrun(receivedData: receivedData)
        caldValue = getCodeName(inputCode: obdCode) + "/" + String(format:"%.2f", (A * 256 + B) / 4)
    }
    else if obdCode == "010D"{
        let A:Double = oneByteRetrun(receivedData: receivedData)
        caldValue = getCodeName(inputCode: obdCode) + "/" + String(format:"%.0f", A)
    }
    else if obdCode == "015B"{
        let A:Double = oneByteRetrun(receivedData: receivedData)
        caldValue = getCodeName(inputCode: obdCode) + "/" + String(format:"%.2f", A * 100 / 255)
    }
    else{caldValue = input}
    return caldValue
}

func oneByteRetrun(receivedData:String) -> Double{
    let valueA:Int = Int(receivedData.suffix(2), radix: 16)!
    return Double(valueA)
}
func twoByteRetrun(receivedData:String) -> (Double, Double){
    let valueA:Int = Int(receivedData.prefix(2), radix: 16)!
    let valueB:Int = Int(receivedData.suffix(2), radix: 16)!
    return (Double(valueA), Double(valueB))
}
func threeByteRetrun(receivedData:String) -> (Double, Double, Double){
    let valueA:Int = Int(receivedData.prefix(2), radix: 16)!
    let valueB:Int = Int(receivedData[receivedData.index(receivedData.startIndex, offsetBy: 2)..<receivedData.index(receivedData.startIndex, offsetBy:4)] , radix: 16)!
    let valueC:Int = Int(receivedData.suffix(2), radix: 16)!
    return (Double(valueA), Double(valueB), Double(valueC))
}
func fourByteRetrun(receivedData:String) -> (Double, Double, Double, Double){
    let valueA:Int = Int(receivedData.prefix(2), radix: 16)!
    let valueB:Int = Int(receivedData[receivedData.index(receivedData.startIndex, offsetBy: 2)..<receivedData.index(receivedData.startIndex, offsetBy:4)] , radix: 16)!
    let valueC:Int = Int(receivedData[receivedData.index(receivedData.startIndex, offsetBy: 4)..<receivedData.index(receivedData.startIndex, offsetBy:6)] , radix: 16)!
    let valueD:Int = Int(receivedData.suffix(2), radix: 16)!
    return (Double(valueA), Double(valueB), Double(valueC), Double(valueD))
}

func getCodeName (inputCode:String)-> String{
    let obdCodes = obdCodesLibrary().obdCodes
    var foundCode:obdCodeStructure?
    let result = obdCodes.map({ (device) -> String in return device.code})
    if result.firstIndex(of: inputCode)  != nil {
        foundCode = obdCodes.filter { codes in
            codes.code == inputCode
        }[0]
    }
    return foundCode!.name
}
