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
    fileprivate let settings:XvMidiSettings = XvMidiSettings.sharedInstance
    
    //ports, endpoints, source
    fileprivate var inputPort = MIDIPortRef()
    fileprivate var sourceEndpointRef = MIDIEndpointRef()
    fileprivate var midiSources:[MIDIEndpointRef] = []
    fileprivate var midiSourceNames:[String] = []
    fileprivate var activeMidiSourceIndexes:[Int] = []
    
    internal var debug:Bool = false
    

    //MARK: -
    //MARK: INIT
    
    internal func setup(withClient:MIDIClientRef){
        
        //grab local version of client so disconnect can happen in reset func
        midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            if (initInputPort()){
                
                refreshMidiSources()
                
            } else {
                
                if (debug) { print("MIDI IN: ERROR initializing input port") }
                
                initComplete()
            }
            
            
        } else {
            
            if (debug) { print("MIDI IN: ERROR client not valid") }
            initComplete()
            
        }
        
        
    }
    
    //when the init is complete, move on to init send
    fileprivate func initComplete(){
        if (debug) { print("MIDI IN: Init complete") }
        XvMidi.sharedInstance.initMidiSend()
    }
    
    //MARK: - ACCESSORS
    internal func getMidiSourceNames() -> [String] {
        return midiSourceNames
    }
    
    internal func getActiveMidiSourceIndexes() -> [Int] {
        return activeMidiSourceIndexes
    }
    
    
    
    //MARK: - SOURCES
    internal func refreshMidiSources(){
        
        //reset all
        midiSources = []
        midiSourceNames = []
        activeMidiSourceIndexes = []
        
        if (debug) {print("MIDI SEND: # of destinations: \(MIDIGetNumberOfSources())")}
        
        
        //check sources
        
        if (MIDIGetNumberOfSources() > 0){
            
            //loop through sources and save sources and names in array
            
            for s:Int in 0 ..< MIDIGetNumberOfSources(){
                
                let midiSource = MIDIGetSource(s)
                midiSources.append(midiSource)
                
                var midiSourceName : Unmanaged<CFString>?
                let status = MIDIObjectGetStringProperty(midiSource, kMIDIPropertyDisplayName, &midiSourceName)
                if status == noErr {
                    let midiSourceDisplayName = midiSourceName!.takeRetainedValue() as String
                    midiSourceNames.append(midiSourceDisplayName)
                }
                
            }
            
            
            //temp: assign to first in port
            sourceEndpointRef = MIDIGetSource(0)
            MIDIPortConnectSource(inputPort, sourceEndpointRef, nil)
            
            //not used yet
            // if there are multiple sources...
            /*if (MIDIGetNumberOfSources() > 1){
                
                //compare names with array in defaults
                //when there is a match, add that index to the active index array
                
                //loop through midiSource names
                /*for n:Int in 0 ..< midiSourceNames.count {
                    
                    //grab midi destination name
                    let midiSourceName:String = midiSourceNames[n]
                    
                    //loop through user selected names
                    for userSelectedMidiSourceName in settings.userSelectedMidiSourceNames {
                        
                        if (midiSourceName == String(describing: userSelectedMidiSourceName)) {
                            activeMidiSourceIndexes.append(n)
                        }
                        
                    }
                }*/
                
                if (debug) {
                    //print("MIDI IN: User Selected:", settings.userSelectedMidiSourceNames) // not used yet
                    print("MIDI IN: MIDI Sources: ", midiSources)
                    print("MIDI IN: MIDI Names:   ", midiSourceNames)
                    print("MIDI IN: MIDI Active:  ", activeMidiSourceIndexes)
                }
                
            }*/
            
        } else {
            
            if (debug) { print("MIDI IN: ERROR no sources detected") }
            
            initComplete()
            
        }

        
    }


    //MARK: - READ BLOCK
    // read block for handing incoming messages
    
    fileprivate func readBlock(_ packetList: UnsafePointer<MIDIPacketList>, srcConnRefCon: Optional<UnsafeMutableRawPointer>) -> Void {
        
        let packets = packetList.pointee
        
        let packet:MIDIPacket = packets.packet
        
        var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        ap.initialize(to: packet)
        
        //loop through packets. Sometimes a note on /off is in the same packet as timeclock
        for _ in 0 ..< packets.numPackets {
            
            let p = ap.pointee
            
            if (debug){print("MIDI IN: Read block: timestamp: \(p.timeStamp)", terminator: " data: ")}
            var hex = String(format:"0x%X", p.data.0)
            if (debug){ print(hex, terminator: " : ") }
            hex = String(format:"0x%X", p.data.1)
            if (debug){ print(hex, terminator: " : ") }
            hex = String(format:"0x%X", p.data.2)
            if (debug){ print(hex) }
            
            let status = packet.data.0
            let d1 = packet.data.1
            let d2 = packet.data.2
            let rawStatus = status & 0xF0 // without channel
            let channel = status & 0x0F
            
            //MIDI system / sync messages
            if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_RECEIVE) {
                
                //target the main thread since we are in the read block, a background thread
                DispatchQueue.main.async(execute: {
                    
                    //midi clock
                    if (status == 0xF8){
                        ReceiveClock.sharedInstance.setTempo(withPacket:packet)
                    }
                    
                    //TODO: test all notifications
                    
                    //midi start (abelton)
                    if (status == 0xFA){
                        Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveSystemStart, userInfo: nil)
                        //Sequencer.sharedInstance.start()
                    }
                    
                    //midi position (abelton, maschine)
                    if (status == 0xF2){
                        let steps:Int = Int(d1)
                        let patternsOf128Steps:Int = Int(d2)
                        let totalSteps:Int = (patternsOf128Steps * 128) + steps
                        Utils.postNotification(
                            name: XvMidiConstants.kXvMidiReceiveSystemPosition,
                            userInfo: ["newPosition" : totalSteps])
                        
                        //Sequencer.sharedInstance.move(toNewPosition: totalSteps)
                    }
                    
                    //midi stop (ableton, maschine)
                    if (status == 0xFC){
                        Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveSystemStop, userInfo: nil)
                        //Sequencer.sharedInstance.stop()
                    }
                    
                    //midi continue (ableton)
                    if (status == 0xFB){
                        Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveSystemContinue, userInfo: nil)
                        //Sequencer.sharedInstance.start()
                    }
                    
                })
                
            }
            
            //MARK: note on
            if (rawStatus == 0x90 && settings.midiReceiveEnabled == true){
                
                if (debug) { print("Note on. Channel \(channel) note \(d1) velocity \(d2)") }
                
                //TODO: test notifications
                
                //grab instrument for row num
                //let instrument:Instrument = InstrumentRack.sharedInstance.getInstrument(fromRowNum: Int(channel))
                
                //target the main thread since we are in the read block, a background thread
                DispatchQueue.main.async(execute: {
                    
                    Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveNoteOn, userInfo: nil)
                    
                    /*
                    //play instrument
                    let notePlayed:Bool = instrument.play(
                        velocity: d2,
                        midiNote: d1)
                    if (self.debug){
                        print("MIDI IN: Note played?", notePlayed)
                    }
                    
                    //turn midi light on
                    VisualOutput.sharedInstance.midiIndicatorOn()
                    */
                })
            }
            
            //TODO: test notificatio
            //MARK: note off
            if (rawStatus == 0x80 && settings.midiReceiveEnabled == true){
                
                //target the main thread since we are in the read block, a background thread
                DispatchQueue.main.async(execute: {
                    
                    Utils.postNotification(name: XvMidiConstants.kXvMidiReceiveNoteOff, userInfo: nil)
                    //turn midi light off
                    //VisualOutput.sharedInstance.midiIndicatorOff()
                    
                })
            }
            
            ap = MIDIPacketNext(ap)
            
        }
        
    }
    
    
    
    //MARK: -
    //MARK: RESET
    internal func reset(){
        
        if midiClient != 0 {
            MIDIPortDisconnectSource(inputPort, sourceEndpointRef)
            midiClient = 0
            midiSources = []
            midiSourceNames = []
        }
    }
    
    
    //MARK:- helper sub funcs
    
    fileprivate func initInputPort() -> Bool {
        
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
                
                if (debug) { print("MIDI IN: SUCCESS created input port") }
                return true
                
            } else {
                
                if (debug) {
                    
                    if (debug) {
                        print("MIDI IN: ERROR creating input port : \(status)")
                        Utils.showError(withStatus: status)
                    }
                    
                    return false
                    
                }
                
            }
            
        }
        
        return true
  
    }


}
