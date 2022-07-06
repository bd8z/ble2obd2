//
//  bleApp.swift
//  ble
//

import SwiftUI

@main
struct bleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var editText = ""
    @ObservedObject public var cbman = Bluetooth()
    @ObservedObject public var location = LocationManager()
    @State private var selection: Int?
    @State private var showingAlert = false
    @State private var selectedItem:String = ""
    @State private var selectedItemUUID:String = ""
    @State private var viewState:Int = 0
    @State private var signalStrength:Double = 0
    var buttonText:String = "Start Record"
    let obdCodes = obdCodesLibrary().obdCodes
    @State private var selectedCodes = Set<UUID>()
    let dynamicColor = UIColor { (traitCollection: UITraitCollection) -> UIColor in
       if traitCollection.userInterfaceStyle == .dark {
           return .white
       } else {
           return .black
       }
   }
    
    
    var body: some View {
            
            Text("OBD BLE Scan Tool")
            Button(action: {
                
                if viewState == 0{
                    self.cbman.startScan()
                }
                else if viewState == 1 || viewState == 2{
                    self.cbman.disconnectPeripheral()
                    location.stop()
                    viewState = 0
                }

            })
            {
                Text(self.cbman.buttonText)
                    .padding()
                    .frame(width: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 1))
            }
        
        if viewState == 0{
            if cbman.isPushed {
                
                //ここで警告が出る多分Listの使い方がよくない
                NavigationView{
                    List(cbman.foundPeripheralNameArray)
                    { singleitem in
                        Button(action: {
                            self.showingAlert = true
                            self.selectedItem = singleitem.name
                            self.selectedItemUUID = singleitem.identifier
                            
                        }, label: {
                            VStack(alignment: .leading){
                                Text(singleitem.name).bold().font(.system(size: 24)).foregroundColor(Color(dynamicColor))
                                Text(singleitem.identifier)
                                HStack{Text("lv: " + singleitem.signalLevel)
                                Rectangle()
                                  .fill(Color.blue)
                                  .frame(width: CGFloat(Double(130 + min(0,Double(singleitem.signalLevel)!))*2 ), height: 5.0)
                                }

                            }
                        }).alert("Confirm", isPresented: $showingAlert, actions: {
                            Button {cbman.connectePeripheral(conncetUUID: selectedItemUUID)
                                viewState = 1
                            }label:{
                                Text("Connect to device").fontWeight(.bold)
                            }
                            Button("Cancel") {}
                          }, message: {
                              Text("Are you sure to conncet to " + selectedItem + "?")
                          })
                        .navigationBarTitle(Text("BLE Device List"))
                    }
                }
            }
            
        }
        else if viewState == 1{

            
            HStack{
                Button(action: {
                    if cbman.isRecordingStarted == false{
                        self.cbman.startRecord()
                        location.start()
                    }
                    else if cbman.isRecordingStarted == true{
                        self.cbman.stopRecord()
                        location.stop()
                        cbman.isRecordingStarted = false
                    }

                })
                {
                    Text(cbman.recorButtonText)
                        .padding()
                        .frame(width: 150)
                        .foregroundColor(Color(.red))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red, lineWidth: 1))
                }
                
                Button(action: {
                    viewState  = 2
                })
                {
                    Text("Setting")
                        .padding()
                        .frame(width: 150)
                        .foregroundColor(Color(dynamicColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(dynamicColor), lineWidth: 1))
                }
            }
            Spacer()
            Group{
                HStack{
                    Text("Read")
                    Text((cbman.readCharacteristic?.uuid.uuidString) ?? "None")
                    Text("0x" + String(format: "%02x",cbman.readCharacteristic?.properties.rawValue ?? 0))
                }
                HStack{
                    Text("Write")
                    Text((cbman.writeCharacteristic?.uuid.uuidString) ?? "None")
                    Text("0x" + String(format: "%02x",cbman.writeCharacteristic?.properties.rawValue ?? 0))

                }
                Spacer()


            }
            Group{
                Text("responseMessage")
                Text(cbman.responseMessage)
                Spacer()
                Text("send to obdCal")
                Text(cbman.debugMessage)
                Spacer()
                Text("0" + " rpm").bold().font(.system(size: 24))
                Text("0" + "km/h").bold().font(.system(size: 24))
                Spacer()
            }
            Group{
                Text(location.spd + " km/h").bold().font(.system(size: 24))
                Text(location.spdAcc + "km/h").bold().font(.system(size: 24))
                Spacer()
            }
            Group{
                Text("GPS location")
                Text("lat: "+location.lat)
                Text("lon: "+location.lon)
                Text("elv: "+location.elv+"m")
                Spacer()
                Text("Accuracy")
                Text("holizontal: "+location.AccH+"m")
                Text("vertical: "+location.AccV+"m")
                Spacer()
            }
        }
        
        else if viewState == 2 {
            HStack{
                Button(action: {
                    if cbman.isRecordingStarted == false{
                        self.cbman.startRecord()
                        location.start()
                    }
                    else if cbman.isRecordingStarted == true{
                        self.cbman.stopRecord()
                        location.stop()
                        cbman.isRecordingStarted = false
                    }

                })
                {
                    Text(cbman.recorButtonText)
                        .padding()
                        .frame(width: 150)
                        .foregroundColor(Color(.red))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red, lineWidth: 1))
                }
                Button(action: {
                    viewState  = 1
                    print("here")
                    let cft = obdCodes.map({ (st) -> String in
                        return st.id.uuidString
                    })
                    
                    var selectedObdCodeArray:[String] = []
                    for item in selectedCodes{
                        let idx:Int = cft.firstIndex(of: item.uuidString) ?? 00
                        selectedObdCodeArray.append(obdCodes[idx].code)
                        cbman.commandtext = selectedObdCodeArray
                    }
                })
                {
                    Text("Finish Setting")
                        .padding()
                        .frame(width: 150)
                        .foregroundColor(Color(dynamicColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(dynamicColor), lineWidth: 1))
                }
        }
            
            NavigationView {
                    List(selection: $selectedCodes) {
                        ForEach(obdCodes) { singleCode in
                            obdCodeListView(obdCodeStructure: singleCode)
                        }
                    }
                    .navigationTitle("Select Code")
                    .toolbar { EditButton() }
                }
            }
    }
}




struct obdCodeListView: View {
    var obdCodeStructure: obdCodeStructure
    var body: some View {
        VStack(alignment: .leading){
            Text("name: " + obdCodeStructure.name)
            Text("code: " + obdCodeStructure.code)
            Text("units: " + obdCodeStructure.units)
        }
    }
}



