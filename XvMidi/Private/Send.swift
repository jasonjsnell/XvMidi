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
    
    //app id
    fileprivate var appID:String = ""
    
    //midi
    fileprivate var midiClient:MIDIClientRef = 0
    fileprivate let settings:Settings = Settings.sharedInstance
    
    //ports, endpoints, destinations
    fileprivate var outputPort = MIDIPortRef()
    fileprivate var midiDestinations:[MIDIEndpointRef] = []
    fileprivate var midiDestinationNames:[String] = []
    
    //translations into MIDI friendly data
    
    fileprivate let NOTE_ON_PREFIX:String = "9"
    fileprivate let NOTE_OFF_PREFIX:String = "8"
    
    //MIDI constants
    fileprivate let MIDI_CHANNEL_TOTAL:Int = 16
    fileprivate let MIDI_NOTES_MAX:Int = 128
    fileprivate let NOTE_OFF_VELOCITY:UInt8 = 0
    
    fileprivate let debug:Bool = true
    fileprivate let noteDebug:Bool = true
    fileprivate let sysDebug:Bool = true
    
    //MARK: -
    //MARK: INIT
   
    internal func setup(withAppID:String, withClient:MIDIClientRef){
        
        //app id
        self.appID = withAppID
        
        //grab local version of client so disconnect can happen in reset func
        midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            //if output port is successfully initialized...
            if (_initOutputPort()){
                
                refreshMidiDestinations()
                
                if (sysDebug) { print("MIDI -> Launch") }
                
            } else {
                if (debug) { print("MIDI -> ERROR initializing output port") }
            }
            
        } else {
            if (debug) { print("MIDI -> ERROR client not valid") }
        }
        
    }
   
    //MARK: - ACCESSORS
    internal func getMidiDestinationNames() -> [String] {
        
        return midiDestinationNames
    }
    
    //MARK: - DESTINATIONS
    
    internal func refreshMidiDestinations() {
        
        //reset all
        midiDestinations = []
        midiDestinationNames = []
      
        if (debug) {print("MIDI -> # of destinations: \(MIDIGetNumberOfDestinations())")}
        
        
        //check destinations
        if (MIDIGetNumberOfDestinations() > 0){
            
            //loop through destinations and names and save in arrays
            
            for d:Int in 0 ..< MIDIGetNumberOfDestinations(){
                
                let midiDestination = MIDIGetDestination(d)
                let midiDestinationName:String = _getName(forMidiDestination: midiDestination)
                
                //add destinations except self (no need to have this app's own virtual destination as a target)
                if (midiDestinationName != appID) {
                    midiDestinations.append(midiDestination)
                    midiDestinationNames.append(midiDestinationName)
                }
                
            }
            
            if (debug) {
                print("MIDI -> MIDI Dest:    ", midiDestinations)
                print("MIDI -> MIDI Names:   ", midiDestinationNames)
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
        sendMidi(data: midiData)
        
    }
    
    internal func sequencerStop(){
        
        if(debug){ print("MIDI -> Sequencer stop") }
        
        //MIDI Stop command
        let midiData : [UInt8] = [0xFC]
        sendMidi(data: midiData)
        
    }
    
    
    
    internal func sequencerMove(toNewPosition:Int){
        
        //http://www.recordingblogs.com/sa/Wiki/topic/MIDI-Song-Position-Pointer-message
        //https://ccrma.stanford.edu/~craig/articles/linuxmidi/misc/essenmidi.html
        
        var sixteenthPosition:Int = toNewPosition
        let phrasePosition:Int = Int(toNewPosition / MIDI_NOTES_MAX)
        
        if (sixteenthPosition > MIDI_NOTES_MAX){
            sixteenthPosition = sixteenthPosition % MIDI_NOTES_MAX
        }
        
        let sixteenthPositionByte = Utils.getByte(fromInt: sixteenthPosition)
        let phrasePositionByte = Utils.getByte(fromInt: phrasePosition)
        
        if(debug){ print("MIDI -> Sequencer move to", sixteenthPositionByte, phrasePositionByte) }
        
        let midiData : [UInt8] = [0xF2, sixteenthPositionByte, phrasePositionByte]
        sendMidi(data: midiData)
        
        
    }
    
    
    //MARK:- MIDI CLOCK
    //called by sequencer metronome
    internal func sendMidiClock(){
        let clockData:[UInt8] = [0xF8]
        sendMidi(data: clockData)
    }
    
    //MARK: - NOTES
    internal func noteOn(channel:Int, destinations:[String], note:UInt8, velocity:UInt8){
        
        if (noteDebug){
            print("MIDI -> note on", channel, destinations, note)
        }
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromInt: channel)
        
        //create byte for note on
        let noteOnByte:UInt8 = Utils.getByte(fromStr: NOTE_ON_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [noteOnByte, UInt8(note), UInt8(velocity)]
        
        //send data
        sendMidi(data: midiData, toDestinations: destinations)
        
    }
    
    internal func noteOff(channel:Int, destinations:[String], note:UInt8){
        
        if (noteDebug){
            print("MIDI -> note off", channel, destinations, note)
        }
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromInt: channel)
        
        //create byte for note off
        let noteOffByte:UInt8 = Utils.getByte(fromStr: NOTE_OFF_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [noteOffByte, UInt8(note), NOTE_OFF_VELOCITY]
    
        //send midi
        sendMidi(data: midiData, toDestinations: destinations)
        
    }
    
    internal func allNotesOff(){
        
        if (debug){
            print("MIDI -> all notes off")
        }
        
        
        for channel:Int in 0 ..< MIDI_CHANNEL_TOTAL {
            
            allNotesOff(ofChannel: channel)
        }
        
    }
    
    internal func allNotesOff(ofChannel:Int) {
        
        //convert midi channel to a hex
        let midiChannelHex:String = Utils.getHexString(fromInt: ofChannel)
        
        //create byte for note off
        let noteOffByte:UInt8 = Utils.getByte(fromStr: NOTE_OFF_PREFIX + midiChannelHex)
        
        for noteNum:Int in 0 ..< MIDI_NOTES_MAX {
            
            if (debug){print("MIDI -> Note off: ch =", ofChannel, "note =", noteNum)}
            
            //midi data = status (midi command + channel), note number, velocity
            let midiData : [UInt8] = [noteOffByte, UInt8(noteNum), NOTE_OFF_VELOCITY]
            
            sendMidi(data: midiData)
            
        }

    }
    
    
    //MARK: -
    //MARK: SEND DATA
    fileprivate func sendMidi(data:[UInt8]) {

        sendMidi(data: data, toDestinations: midiDestinationNames)
    }
    
    fileprivate func sendMidi(data:[UInt8], toDestinations:[String]){
        
        //prep empty array of final destinations
        var finalDestinations:[MIDIEndpointRef] = []
        
        //loop through available destinations
        for midiDestination in midiDestinations {
            
            //get name for each
            let midiDestinationName:String = _getName(forMidiDestination: midiDestination)
            
            //if that name has an index in the incoming destinations...
            if let _:Int = toDestinations.index(of: midiDestinationName){
                
                // then add it to the final array
                finalDestinations.append(midiDestination)
            }
        }
        
        //if there are no final destinations
        if (finalDestinations.count == 0){
            
            //check to see if default was selected by user in global settings
            if let _:Int = toDestinations.index(of: "Omni"){
                
                //if so, are there ANY available active destinations?
                if (midiDestinations.count > 0){
                    
                    //add first midi destination as the default
                    finalDestinations.append(midiDestinations[0])
                }
            }
        }
        
        
        //if there are any destinations
        if (finalDestinations.count > 0){
            
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
            
            //loop through destinations and send midi to them all
            
            for destEndpointRef in finalDestinations {
                
                MIDISend(outputPort, destEndpointRef, packetList)
            }
            
            //release
            free(packetList)

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
        midiDestinations = []
        midiDestinationNames = []
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
