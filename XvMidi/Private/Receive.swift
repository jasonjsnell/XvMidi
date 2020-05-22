//
//  MIDIIn.swift
//  Refraktions
//
//  Created by Jason Snell on 11/30/15.
//  Copyright © 2015 Jason J. Snell. All rights reserved.
//
//http://www.rockhoppertech.com/blog/swift-2-and-coremidi/
//http://stackoverflow.com/questions/13952151/can-anyone-show-me-how-to-use-coremidi-on-ios
//https://en.wikipedia.org/wiki/MIDI_beat_clock
//http://stackoverflow.com/questions/9641399/ios-how-to-receive-midi-tempo-bpm-from-host-using-coremidi
//http://stackoverflow.com/questions/13562714/calculate-accurate-bpm-from-midi-clock-in-objc-with-coremidi


import Foundation
import CoreMIDI

class Receive {
    
    fileprivate let debug:Bool = false
    fileprivate let sysDebug:Bool = false
    
    //singleton code
    static let sharedInstance = Receive()
    fileprivate init() {}
    
    //MARK: - VARS -
    
    fileprivate var appID:String = ""
    
    //bypass MIDI core receive when audiobus midi functionality is on
    fileprivate var _bypass:Bool = false
    public var bypass:Bool {
        get {return _bypass}
        set {_bypass = newValue}
    }
    
    fileprivate var midiClient:MIDIClientRef = 0
    fileprivate let settings:Settings = Settings.sharedInstance
    
    //ports, endpoints, source
    fileprivate var inputPort:MIDIPortRef = MIDIPortRef()
    fileprivate var virtualMidiInput:MIDIEndpointRef = MIDIEndpointRef()
    fileprivate var availableMidiSourceNames:[String] = []
    

    //MARK: - INIT
    
    internal func setup(appID:String, withClient:MIDIClientRef, withSourceNames:[String]) -> Bool {
        
        //grab appID, used in virutual client
        self.appID = appID
        
        //grab local version of client so disconnect can happen in reset func
        midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            if (_initInputPort() && _initVirtualMidiIn()){
                
                setActiveMidiSources(withSourceNames: withSourceNames)
                
                if (sysDebug) { print("MIDI <- Launch") }
                
                return true
                
            } else {
                
                print("MIDI <- ERROR initializing input port")
                return false
                
            }
            
            
        } else {
            
            print("MIDI <- ERROR client not valid")
            return false
            
        }
    }
    
    //MARK: - SOURCES
    internal func getAvailableMidiSourceNames() -> [String] {
        
        return availableMidiSourceNames
    }
    
    
    internal func setActiveMidiSources(withSourceNames:[String]){
        
        //reset all
        _disconnectAllSources()
        availableMidiSourceNames = []
        
        if (debug) { print("MIDI <- # of sources: \(MIDIGetNumberOfSources())")}
        
        //check for omni
        var omni:Bool = false
        if let _:Int = withSourceNames.firstIndex(of: XvMidiConstants.MIDI_SOURCE_OMNI) {
            omni = true
        }
        
        //check sources
        
        if (MIDIGetNumberOfSources() > 0){
            
            //loop through sources and save sources and names in array
        
            for s:Int in 0 ..< MIDIGetNumberOfSources(){
                
                let midiSource:MIDIEndpointRef = MIDIGetSource(s)
                let midiSourceName:String = _getName(forMidiSource: midiSource)
                
                //only add sources names that are not the app name (which means it's the virtual input)
                //virtual input has it's own read block and will be added twice if added here, causing a midi feedback loop
                if (midiSourceName != appID){
                    
                    //add source name to the available sources list
                    availableMidiSourceNames.append(midiSourceName)
                
                }
                
                //if omni, add all except virtual input
                if (omni && midiSourceName != appID) {
                    
                    MIDIPortConnectSource(inputPort, midiSource, nil)
                    if (debug) { print("MIDI <- Add all sources") }
                    
                } else {
                    
                    //connect only sources from incoming list
                    if let _:Int = withSourceNames.firstIndex(of: midiSourceName) {
                        
                        MIDIPortConnectSource(inputPort, midiSource, nil)
                        if (debug) { print("MIDI <- Add", midiSourceName) }
                        
                    }
                }
            }
    
            if (debug) {
                
                print("MIDI <- MIDI Available names:   ", availableMidiSourceNames)
            }
        } else {
            
            if (debug) { print("MIDI <- ERROR no sources detected") }
        }
    }

    
    //MARK: RECEIVING
    //called by internal read block and audiobus read block
    internal func process(packetList: UnsafePointer<MIDIPacketList>){
        
        let packets = packetList.pointee
        let packet:MIDIPacket = packets.packet
  
        var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        ap.initialize(to: packet)
        
        //loop through packets. Sometimes a note on /off is in the same packet as timeclock
        for _ in 0 ..< packets.numPackets {
            
            if (debug) {
                print("MIDI Receiving:")
                Utils.printContents(ofPacket: ap)
            }
            
            let status:UInt8 = packet.data.0
            let rawStatus:UInt8 = status & 0xF0 // without channel
            let d1:UInt8 = packet.data.1
            let d2:UInt8 = packet.data.2
           
            //let rawStatus:UInt8 = status & 0xF0 // without channel
            let channel:UInt8 = status & 0x0F
            
            //MIDI system / sync messages
            if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_RECEIVE) {
                
                //MARK: - MIDI CLOCK
                if (status == 0xF8){
                    ReceiveClock.sharedInstance.clockFire(withPacket:packet)
                }
                
                //MARK: - SEQUENCER
                //midi start (abelton)
                if (status == 0xFA){
                    Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveSystemStart, userInfo: nil)
                }
                
                //midi position (abelton, maschine)
                if (status == 0xF2){
                    
                    let steps:Int = Int(d1)
                    let patternsOf128Steps:Int = Int(d2)
                    let totalSteps:Int = (patternsOf128Steps * 128) + steps
                    
                    Utils.postNotification(
                        name: XvMidiConstants.kXvMidiReceiveSystemPosition,
                        userInfo: ["newPosition" : totalSteps])
                    
                }
                
                //midi stop (ableton, maschine)
                if (status == 0xFC){
                    
                    ReceiveClock.sharedInstance.active = false //clock is now in inactive state
                    
                    Utils.postNotification(
                        name: XvMidiConstants.kXvMidiReceiveSystemStop,
                        userInfo: nil)
                }
                
                //midi continue (ableton)
                if (status == 0xFB){
                    Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveSystemContinue, userInfo: nil)
                }
                
            }
            
            //MARK: - NOTES
            //MARK: note on
            if (rawStatus == XvMidiConstants.NOTE_ON){
                
                if (debug) { print("MIDI <- Note on. Channel \(channel) note \(d1) velocity \(d2)") }
            
                if (d2 == 0x0){
                    
                    //some midi controllers request a note off by putting the velocity to 0
                    Utils.postNotification(
                        name: XvMidiConstants.kXvMidiReceiveNoteOff,
                        userInfo: ["channel" : channel, "note" : d1]
                    )
                    
                } else {
                    
                    //else send normal note on
                    Utils.postNotification(
                        name: XvMidiConstants.kXvMidiReceiveNoteOn,
                        userInfo: ["channel" : channel, "note" : d1, "velocity" : d2]
                    )
                    
                }
            }
            
            
            //MARK: note off
            if (rawStatus == XvMidiConstants.NOTE_OFF){
                
                Utils.postNotification(
                    name: XvMidiConstants.kXvMidiReceiveNoteOff,
                    userInfo: ["channel" : channel, "note" : d1]
                )
            }
            
            //MARK: - CONTROL CHANGES: DATA ENTRY
            if (rawStatus == XvMidiConstants.CONTROL_CHANGE) {
                
                Utils.postNotification(
                    name: XvMidiConstants.kXvMidiReceiveControlChange,
                    userInfo: ["channel" : channel, "control" : d1, "value" : d2]
                )
            }
           
            //prep next round
            ap = MIDIPacketNext(ap)
            
        }
        
    }

    //MARK: - READ BLOCKS
    // read block - catch packet list from background thread and process it in foreground
    
    fileprivate func inputPortReadBlock(
        _ packetList: UnsafePointer<MIDIPacketList>,
        srcConnRefCon: Optional<UnsafeMutableRawPointer>) -> Void {
        
        if (debug) { print("MIDI <- normal input readblock") }
        
        //if bypass is off, send along for processing
        if (!bypass) {
            DispatchQueue.main.async(execute: {
                self.process(packetList: packetList)
            })
        }
    }
    
    //although this is the same code as above, it's a seperate read block for easier debugging
    fileprivate func virtualMidiInputReadBlock(
        _ packetList: UnsafePointer<MIDIPacketList>,
        srcConnRefCon: Optional<UnsafeMutableRawPointer>) -> Void {
        
        if (debug) { print("MIDI <- virtual input readblock") }
        
        //if bypass is off, send along for processing
        if (!bypass) {
            DispatchQueue.main.async(execute: {
                self.process(packetList: packetList)
            })
        }
    }

    
    //MARK: -
    //MARK: RESET
    internal func shutdown(){
        
        if (sysDebug) { print("MIDI <- Shutdown") }
        
        if (MIDIGetNumberOfSources() > 0){
            
            //loop through sources and disconnect them
            
            for s:Int in 0 ..< MIDIGetNumberOfSources(){
                
                let midiSource = MIDIGetSource(s)
                MIDIPortDisconnectSource(inputPort, midiSource)
            }
        }
        
        MIDIPortDispose(inputPort)
        inputPort = 0
        midiClient = 0
        availableMidiSourceNames = []
        
    }
    
    
    //MARK:- helper sub funcs
    
    fileprivate func _initInputPort() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create input port with read block (that handles the incoming traffic)
        if (inputPort == 0){
            
            status = MIDIInputPortCreateWithBlock(
                midiClient,
                "com.jasonjsnell."+appID+".InputPort" as CFString,
                &inputPort,
                inputPortReadBlock)
            
            //error checking
            if status == OSStatus(noErr) {
                
                if (sysDebug) { print("MIDI <- Input port successfully created", inputPort) }
                return true
                
            } else {
                
                if (sysDebug) { print("MIDI <- Error creating input port : \(status)") }
                
                if (debug) {
                    Utils.showError(withStatus: status)
                }
                
                return false
                
            }
            
        } else {
            if (sysDebug) { print("MIDI <- Input port already created") }
            return true
        }
  
    }
    
    fileprivate func _initVirtualMidiIn() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create input port with read block (that handles the incoming traffic)
        if (virtualMidiInput == 0){
            
            status = MIDIDestinationCreateWithBlock(
                midiClient,
                appID as CFString,
                &virtualMidiInput,
                virtualMidiInputReadBlock)
            
            //error checking
            if status == OSStatus(noErr) {
                
                if (sysDebug) { print("MIDI <- Virtual dest successfully created", virtualMidiInput) }
                return true
                
            } else {
                
                print("MIDI <- Error creating virtual destination port : \(status)")
                if (String(describing: status) == "-10844"){
                    print("MIDI <- Error 10844 solution: Add 'Audio' to Background Modes to enable virtual dest creation")
                }
                
                if (debug) {
                    Utils.showError(withStatus: status)
                }
                
                return false
                
            }
          
        } else {
            if (sysDebug) { print("MIDI <- Virtual dest already created") }
            return true
        }
        
    }
    
    fileprivate func _getName(forMidiSource:MIDIEndpointRef) -> String {
        
        var midiSourceName : Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(forMidiSource, kMIDIPropertyDisplayName, &midiSourceName)
        if status == noErr {
            let midiSourceDisplayName = midiSourceName!.takeRetainedValue() as String
            return midiSourceDisplayName
        }
        
        return ""
        
    }
    
    
    
    fileprivate func _disconnectAllSources(){
        
        for s:Int in 0 ..< MIDIGetNumberOfSources(){
            
            let midiSource:MIDIEndpointRef = MIDIGetSource(s)
            MIDIPortDisconnectSource(inputPort, midiSource)
            
        }
    }
    
    


}
