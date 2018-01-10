//
//  MIDIOut.swift
//  Refraktions
//
//  Created by Jason Snell on 11/30/15.
//  Copyright © 2015 Jason J. Snell. All rights reserved.
//

import Foundation
import CoreMIDI

//http://wiki.cockos.com/wiki/index.php/MIDI_Specification
//https://ccrma.stanford.edu/~craig/articles/linuxmidi/misc/essenmidi.html

class Send {
    
    //singleton code
    static let sharedInstance = Send()
    fileprivate init() {}
    
    //MARK: - VARS -
    
    //bypass MIDI core sendMidi when audiobus midi functionality is on
    fileprivate var _bypass:Bool = false
    public var bypass:Bool {
        get {return _bypass}
        set {_bypass = newValue}
    }
    
    //app id
    fileprivate var appID:String = ""
    
    //midi
    fileprivate var midiClient:MIDIClientRef = 0
    fileprivate let settings:Settings = Settings.sharedInstance
    
    //ports, endpoints, destinations
    fileprivate var outputPort = MIDIPortRef()
    fileprivate var virtualSource:MIDIEndpointRef = MIDIEndpointRef()
    
    fileprivate var availableMidiDestinations:[MIDIEndpointRef] = [] //all available destinations
    fileprivate var availableMidiDestinationNames:[String] = []
    fileprivate var activeGlobalMidiDestinationNames:[String] = [] //destinations selected by user
    
    
    
    //MIDI constants
    fileprivate let MIDI_CHANNEL_TOTAL:Int = 16
    fileprivate let MIDI_NOTES_MAX:Int = 128
    fileprivate let NOTE_OFF_VELOCITY:UInt8 = 0
    
    fileprivate let debug:Bool = true
    fileprivate let noteDebug:Bool = true
    fileprivate let sysDebug:Bool = true
    
    //MARK: -
    //MARK: INIT
    
    
   
    internal func setup(withAppID:String, withClient:MIDIClientRef, withDestinatonNames:[String]) -> Bool {
        
        //app id
        self.appID = withAppID
        
        //grab local version of client so disconnect can happen in reset func
        midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            //if output port is successfully initialized...
            if (_initOutputPort() && _initVirtualSource()){
                
                //sets the user selected destinations
                setActiveGlobalMidiDestinations(withDestinationNames: withDestinatonNames)
                
                if (sysDebug) { print("MIDI -> Launch") }
                return true
                
            } else {
                
                print("MIDI -> ERROR initializing output port")
                return false
            }
            
        } else {
            
            print("MIDI -> ERROR client not valid")
            return false
        }
        
    }
    
    
   
    //MARK: - DESTINATIONS
    internal func getAvailableMidiDestinationNames() -> [String] {
        
        return availableMidiDestinationNames
    }
    
    internal func setActiveGlobalMidiDestinations(withDestinationNames:[String]){
        
        //clear array
        activeGlobalMidiDestinationNames = []
        
        //refresh list of destinations from MIDI system
        refreshMidiDestinations()
        
        //loop through incoming names
        for name in withDestinationNames {
            
            //if the name is omni, then add all the names and stop the loop
            if (name == XvMidiConstants.MIDI_DESTINATION_OMNI){
                
                activeGlobalMidiDestinationNames = availableMidiDestinationNames
                break
            }
            
            //if the name is in the available midi destinations
            if availableMidiDestinationNames.contains(name){
                
                //add it to the active list
                activeGlobalMidiDestinationNames.append(name)
            }
            
        }
        
    }
    
    internal func refreshMidiDestinations() {
        
        //reset all
        availableMidiDestinations = []
        availableMidiDestinationNames = []
      
        if (debug) {print("MIDI -> Refresh, # of destinations: \(MIDIGetNumberOfDestinations())")}
        
        
        //check destinations
        if (MIDIGetNumberOfDestinations() > 0){
            
            //loop through destinations and names and save in arrays
            
            for d:Int in 0 ..< MIDIGetNumberOfDestinations(){
                
                let midiDestination = MIDIGetDestination(d)
                let midiDestinationName:String = _getName(forMidiDestination: midiDestination)
                
                //add destinations except self (no need to have this app's own virtual destination as a target)
                if (midiDestinationName != appID) {
                    availableMidiDestinations.append(midiDestination)
                    availableMidiDestinationNames.append(midiDestinationName)
                }
                
            }
            
            if (debug) {
                print("MIDI -> MIDI Dest:    ", availableMidiDestinations)
                print("MIDI -> MIDI Names:   ", availableMidiDestinationNames)
            }
            
            
        } else {
            if (debug) { print("MIDI -> ERROR no destinations detected") }
        }

    }
    
    
    //MARK:- SEQUENCER
    internal func sequencerStart(){
        
        if(debug){ print("MIDI -> Sequencer start") }
        
        //MIDI Start command
        let midiData : [UInt8] = [0xFA]
        sendSystemMidi(data: midiData, toDestinations: activeGlobalMidiDestinationNames)
        
    }
    
    internal func sequencerStop(){
        
        if(debug){ print("MIDI -> Sequencer stop") }
        
        //MIDI Stop command
        let midiData : [UInt8] = [0xFC]
        sendSystemMidi(data: midiData, toDestinations: activeGlobalMidiDestinationNames)
        
    }
    
    
    
    internal func sequencerMove(toNewPosition:Int){
        
        //http://www.recordingblogs.com/sa/Wiki/topic/MIDI-Song-Position-Pointer-message
        //https://ccrma.stanford.edu/~craig/articles/linuxmidi/misc/essenmidi.html
        
        var sixteenthPosition:Int = toNewPosition
        let phrasePosition:Int = Int(toNewPosition / MIDI_NOTES_MAX)
        
        if (sixteenthPosition > MIDI_NOTES_MAX){
            sixteenthPosition = sixteenthPosition % MIDI_NOTES_MAX
        }
        
        let sixteenthPositionByte:UInt8 = Utils.getByte(fromUInt8: UInt8(sixteenthPosition))
        let phrasePositionByte:UInt8 = Utils.getByte(fromUInt8: UInt8(phrasePosition))
        
        if(debug){ print("MIDI -> Sequencer move to", sixteenthPositionByte, phrasePositionByte) }
        
        let midiData : [UInt8] = [0xF2, sixteenthPositionByte, phrasePositionByte]
        sendSystemMidi(data: midiData, toDestinations: activeGlobalMidiDestinationNames)
        
        
    }
    
    
    //MARK:- MIDI CLOCK
    //called by sequencer metronome
    internal func sendMidiClock(){
        let clockData:[UInt8] = [0xF8]
        sendSystemMidi(data: clockData, toDestinations: activeGlobalMidiDestinationNames)
    }
    
    //MARK: - NOTES
    internal func noteOn(channel:UInt8, destinations:[String], note:UInt8, velocity:UInt8){
        
        if (noteDebug){
            print("MIDI -> note on", channel, destinations, note)
        }
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: channel)
        
        //create byte for note on
        let noteOnByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.NOTE_ON_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [noteOnByte, UInt8(note), UInt8(velocity)]
        
        //send data
        sendMidi(data: midiData, toDestinations: destinations, onChannel:channel)
        
    }
    
    internal func noteOff(channel:UInt8, destinations:[String], note:UInt8){
        
        if (noteDebug){
            print("MIDI -> note off", channel, destinations, note)
        }
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: channel)
        
        //create byte for note off
        let noteOffByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.NOTE_OFF_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [noteOffByte, UInt8(note), NOTE_OFF_VELOCITY]
    
        //send midi
        sendMidi(data: midiData, toDestinations: destinations, onChannel: channel)
        
    }
    
    internal func allNotesOff(){
        
        if (debug){
            print("MIDI -> all notes off")
        }
        
        
        for channel:Int in 0..<MIDI_CHANNEL_TOTAL {
            
            allNotesOff(ofChannel: UInt8(channel))
        }
        
    }
    
    internal func allNotesOff(ofChannel:UInt8) {
        
        //convert midi channel to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: ofChannel)
        
        //create byte for note off
        let noteOffByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.NOTE_OFF_PREFIX + midiChannelHex)
        
        for noteNum:Int in 0 ..< MIDI_NOTES_MAX {
            
            if (debug){print("MIDI -> Note off: ch =", ofChannel, "note =", noteNum)}
            
            //midi data = status (midi command + channel), note number, velocity
            let midiData : [UInt8] = [noteOffByte, UInt8(noteNum), NOTE_OFF_VELOCITY]
    
            sendMidi(data: midiData, toDestinations: activeGlobalMidiDestinationNames, onChannel: ofChannel)
            
        }

    }
    
    
    //MARK: -
    //MARK: SEND DATA
    
    fileprivate func _getActiveDestinations(targetDestinationNames:[String]) -> [MIDIEndpointRef] {
        
        var activeDestinations:[MIDIEndpointRef] = []
        
        //loop through available destinations
        for midiDestination in availableMidiDestinations {
            
            //get name for each
            let midiDestinationName:String = _getName(forMidiDestination: midiDestination)
            
            //if that name has an index in the incoming destinations...
            if let _:Int = targetDestinationNames.index(of: midiDestinationName){
                
                // then add it to the final array
                activeDestinations.append(midiDestination)
            }
        }
        
        //if there are no final destinations
        if (activeDestinations.count == 0){
            
            //check to see if omni was selected by user in global settings
            if let _:Int = targetDestinationNames.index(of: XvMidiConstants.MIDI_DESTINATION_OMNI){
                
                //if so, all destinations are the target
                activeDestinations = availableMidiDestinations
                
            } else {
                
                Utils.postNotification(
                    name: XvMidiConstants.kXvMidiNoDestinationError,
                    userInfo: nil
                )
            }
        }
        
        return activeDestinations
    }
    
    //sends system data
    fileprivate func sendSystemMidi(data:[UInt8], toDestinations:[String]){
        
        //route to main send func with system flag on
        sendMidi(data: data, toDestinations: toDestinations, onChannel: 0, system: true)
        
    }
    
    //main send func
    fileprivate func sendMidi(data:[UInt8], toDestinations:[String], onChannel:UInt8, system:Bool = false){
        
        //prep empty array of final destinations
        let activeDestinations:[MIDIEndpointRef] = _getActiveDestinations(targetDestinationNames: toDestinations)
        
        //if there are any destinations
        if (activeDestinations.count > 0){
            
            //https://en.wikipedia.org/wiki/Nibble#Low_and_high_nibbles
            //http://www.blitter.com/~russtopia/MIDI/~jglatt/tech/midispec/noteon.htm
            
            //create
            var packet = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
            let packetList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
            
            //init
            packet = MIDIPacketListInit(packetList)
            
            //grab length
            let packetLength:Int = data.count
            
            //packet byte size
            let packetByteSize:Int = 1024
            
            //set to now for instant delivery
            let timeStamp:MIDITimeStamp = 0
            
            //add packet data to the packet list
            packet = MIDIPacketListAdd(packetList, packetByteSize, packet, timeStamp, packetLength, data)
            
            if (!_bypass){
                
                if (noteDebug){
                    print("MIDI -> destinations:", activeDestinations)
                }
                
                //normal - send midi out via CoreMIDI
                //loop through destinations and send midi to them all
                if (debug){
                    print("MIDI Sending:")
                    Utils.printContents(ofPacket: packet)
                }
                
                for destEndpointRef in activeDestinations {
                    
                    MIDISend(outputPort, destEndpointRef, packetList)
                }
                
            } else {
                
                if (noteDebug){
                    print("MIDI -> Audiobus")
                }
                
                //audiobus bypass - send packetlist out through a notification
                Utils.postNotification(
                    name: XvMidiConstants.kXvMidiSendBypass,
                    userInfo: [
                        "packetList" : packetList,
                        "channel" : onChannel,
                        "system" : system
                    ]
                )
            }
            
            //always send to MIDI virtual source (used in both normal and audiobus / aum modes
            if (virtualSource != 0){
                
                let status = MIDIReceived(virtualSource, packetList)
                
                if status == OSStatus(noErr) {
                    
                    if (sysDebug){
                        print("MIDI -> Success sending from virtual source")
                    }
                    
                } else {
                    print("MIDI -> Error sending to virutal port", status)
                }
                
            } else {
                print("MIDI -> Error: virtual source is 0 during MIDI send")
            }
            
            
        } else {
            if (debug){ print("MIDI -> Error no MIDI destinations during sendMidi") }
        }
        
    }
    
    
    //MARK: -
    //MARK: RESET
    internal func shutdown(){
        
        if (sysDebug) { print("MIDI -> Shutdown") }
        
        //if system is active, then send all notes off command to refreshed destinations
        if (midiClient != 0 && outputPort != 0) {
            refreshMidiDestinations()
            allNotesOff()
        }
        
        MIDIPortDispose(outputPort)
        outputPort = 0
        midiClient = 0
        availableMidiDestinations = []
        availableMidiDestinationNames = []
        activeGlobalMidiDestinationNames = []
    }

    //MARK:- helper sub funcs
    
    fileprivate func _initOutputPort() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create an output port if it doesn't exist yet
        if (outputPort == 0){
            
            status = MIDIOutputPortCreate(midiClient, "com.jasonjsnell.refraktions.OutputPort" as CFString, &outputPort)
            
            //error checking
            if status == OSStatus(noErr) {
                
                if (sysDebug) { print("MIDI -> Output port successfully created", outputPort) }
                return true
                
            } else {
                
                if (debug) {
                    Utils.showError(withStatus:status)
                }
                
                if (sysDebug) { print("MIDI -> Error creating output port : \(status)") }
                
                return false
                
            }
            
        } else {
            if (sysDebug) { print("MIDI -> Output port already created") }
            return true
        }
        
    }
    
    fileprivate func _initVirtualSource() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create input port with read block (that handles the incoming traffic)
        if (virtualSource == 0){
            
            status = MIDISourceCreate(
                midiClient,
                appID as CFString,
                &virtualSource)
            
            //error checking
            if status == OSStatus(noErr) {
                
                if (sysDebug) { print("MIDI <- Virtual source successfully created", virtualSource) }
                return true
                
            } else {
                
                print("MIDI <- Error creating virtual source port : \(status)")
                if (String(describing: status) == "-10844"){
                    print("MIDI <- Error 10844 solution: Add 'Audio' to Background Modes to enable virtual source creation")
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
    
    
    fileprivate func _getName(forMidiDestination:MIDIEndpointRef) -> String {
        
        var midiDestinationName : Unmanaged<CFString>?
        var status = OSStatus(noErr)
        status = MIDIObjectGetStringProperty(forMidiDestination, kMIDIPropertyDisplayName, &midiDestinationName)
        if status == noErr {
            let midiDestinationDisplayName = midiDestinationName!.takeRetainedValue() as String
            return midiDestinationDisplayName
        }
        
        return ""
        
    }

    
}
