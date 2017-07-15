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
    
    //singleton code
    static let sharedInstance = Receive()
    fileprivate init() {}
    
    //MARK: - VARS -
    
    fileprivate var midiClient:MIDIClientRef = 0
    fileprivate let settings:Settings = Settings.sharedInstance
    
    //ports, endpoints, source
    fileprivate var inputPort:MIDIPortRef = MIDIPortRef()
    fileprivate var virtualDest:MIDIEndpointRef = MIDIEndpointRef()
    fileprivate var midiSources:[MIDIEndpointRef] = []
    fileprivate var midiSourceNames:[String] = []
    
    fileprivate let debug:Bool = true
    fileprivate let sysDebug:Bool = true
    

    //MARK: -
    //MARK: INIT
    
    internal func setup(withClient:MIDIClientRef){
        
        //grab local version of client so disconnect can happen in reset func
        midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            if (_initInputPort() && _initVirtualDestination()){
                
                refreshMidiSources()
                
                if (sysDebug) { print("MIDI <- Launch") }
                
                _initComplete()
                
            } else {
                
                if (debug) { print("MIDI <- ERROR initializing input port") }
                
                _initComplete()
            }
            
            
        } else {
            
            if (debug) { print("MIDI <- ERROR client not valid") }
            _initComplete()
            
        }
        
        
    }
    
    //when the init is complete, move on to init send
    fileprivate func _initComplete(){
        if (debug) { print("MIDI <- Init complete") }
        XvMidi.sharedInstance.initMidiSend()
    }
    
    //MARK: - ACCESSORS
    internal func getMidiSourceNames() -> [String] {
        
        return midiSourceNames
    }
    
    //MARK: - SOURCES
    internal func refreshMidiSources(){
        
        //reset all
        midiSources = []
        midiSourceNames = []
        
        if (debug) {print("MIDI <- # of sources: \(MIDIGetNumberOfSources())")}
        
        
        //check sources
        
        if (MIDIGetNumberOfSources() > 0){
            
            //loop through sources and save sources and names in array
            
            for s:Int in 0 ..< MIDIGetNumberOfSources(){
                
                let midiSource = MIDIGetSource(s)
                midiSources.append(midiSource)
                midiSourceNames.append(_getName(forMidiSource: midiSource))
                
                //connect each port
                MIDIPortConnectSource(inputPort, midiSource, nil)

            }
            
            
            
            
            if (debug) {
                print("MIDI <- MIDI Sources: ", midiSources)
                print("MIDI <- MIDI Names:   ", midiSourceNames)
                
            }
            
        
        } else {
            
            if (debug) { print("MIDI <- ERROR no sources detected") }
            
        }

        
    }


    //MARK: - READ BLOCK
    // read block for handing incoming messages
    
    fileprivate func readBlock(_ packetList: UnsafePointer<MIDIPacketList>, srcConnRefCon: Optional<UnsafeMutableRawPointer>) -> Void {
        
        //TODO: HERE - trying to get the midiSource of the incoming message so its name can be passed along in a post notifiation
        
        //TODO: Change Default to Omni?
        
        
        print("sources = ", midiSources)
        print("srcConnRefCon = ", srcConnRefCon)
        
        let packets = packetList.pointee
        
        let packet:MIDIPacket = packets.packet
        
        var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        ap.initialize(to: packet)
        
        //loop through packets. Sometimes a note on /off is in the same packet as timeclock
        for _ in 0 ..< packets.numPackets {
            
            let p = ap.pointee
            
            if (debug){print("MIDI <- Read block: timestamp: \(p.timeStamp)", terminator: " data: ")}
            var hex = String(format:"0x%X", p.data.0)
            if (debug){ print(hex, terminator: " : ") }
            hex = String(format:"0x%X", p.data.1)
            if (debug){ print(hex, terminator: " : ") }
            hex = String(format:"0x%X", p.data.2)
            if (debug){ print(hex) }
            
            let status:UInt8 = packet.data.0
            let d1:UInt8 = packet.data.1
            let d2:UInt8 = packet.data.2
            let rawStatus:UInt8 = status & 0xF0 // without channel
            let channel:UInt8 = status & 0x0F
            
            //MIDI system / sync messages
            if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_RECEIVE) {
                
                //target the main thread since we are in the read block, a background thread
                DispatchQueue.main.async(execute: {
                    
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
                        Utils.postNotification(
                            name: XvMidiConstants.kXvMidiReceiveSystemStop,
                            userInfo: nil)
                    }
                    
                    //midi continue (ableton)
                    if (status == 0xFB){
                        Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveSystemContinue, userInfo: nil)
                    }
                    
                })
                
            }
            
            //MARK: - NOTES
            
            if (rawStatus == 0x90){
                
                if (debug) { print("Note on. Channel \(channel) note \(d1) velocity \(d2)") }
                
                //target the main thread since we are in the read block, a background thread
                DispatchQueue.main.async(execute: {
                    
                    Utils.postNotification(
                        name: XvMidiConstants.kXvMidiReceiveNoteOn,
                        userInfo: ["channel" : channel, "note" : d1, "velocity" : d2])
                    
                })
            }
            
            
            //MARK: note off
            if (rawStatus == 0x80){
                
                //target the main thread since we are in the read block, a background thread
                DispatchQueue.main.async(execute: {
                    
                    Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveNoteOff, userInfo: nil)
                    
                })
            }
            
            ap = MIDIPacketNext(ap)
            
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
        midiSources = []
        midiSourceNames = []
        
    }
    
    
    //MARK:- helper sub funcs
    
    fileprivate func _initInputPort() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create input port with read block (that handles the incoming traffic)
        if (inputPort == 0){
            
            status = MIDIInputPortCreateWithBlock(
                midiClient,
                "com.jasonjsnell.refraktions.InputPort" as CFString,
                &inputPort,
                readBlock)
            
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
    
    fileprivate func _initVirtualDestination() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create input port with read block (that handles the incoming traffic)
        if (virtualDest == 0){
        
            status = MIDIDestinationCreateWithBlock(
                midiClient,
                "Repercussion" as CFString,
                &virtualDest,
                readBlock)
            
            //error checking
            if status == OSStatus(noErr) {
                
                if (sysDebug) { print("MIDI <- Virtual dest successfully created", virtualDest) }
                return true
                
            } else {
                
                if (sysDebug) { print("MIDI <- Error creating virtual destination port : \(status)") }
                
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


}
