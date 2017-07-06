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
    
    //midi
    fileprivate var midiClient:MIDIClientRef = 0
    fileprivate let settings:Settings = Settings.sharedInstance
    
    //ports, endpoints, destinations
    fileprivate var outputPort = MIDIPortRef()
    fileprivate var midiDestinations:[MIDIEndpointRef] = []
    fileprivate var midiDestinationNames:[String] = []
    fileprivate var activeMidiDestinationIndexes:[Int] = []
    
    //translations into MIDI friendly data
    
    fileprivate let NOTE_ON_PREFIX:String = "9"
    fileprivate let NOTE_OFF_PREFIX:String = "8"
    
    //MIDI constants
    fileprivate let MIDI_CHANNEL_TOTAL:Int = 16
    fileprivate let MIDI_NOTES_MAX:Int = 128
    
    fileprivate let debug:Bool = false
    fileprivate let noteDebug:Bool = false
    fileprivate let sysDebug:Bool = false
    
    //MARK: -
    //MARK: INIT
   
    func setup(withClient:MIDIClientRef){
        
        //grab local version of client so disconnect can happen in reset func
        midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            //if output port is successfully initialized...
            if (initOutputPort()){
                
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
        refreshMidiDestinations()
        return midiDestinationNames
    }
    
    //MARK: - DESTINATIONS
    
    internal func refreshMidiDestinations() {
        
        //reset all
        midiDestinations = []
        midiDestinationNames = []
        activeMidiDestinationIndexes = []
        
        if (debug) {print("MIDI -> # of destinations: \(MIDIGetNumberOfDestinations())")}
        
        //check destinations
        if (MIDIGetNumberOfDestinations() > 0){
            
            //loop through destinations and names and save in arrays
            
            for d:Int in 0 ..< MIDIGetNumberOfDestinations(){
                
                let midiDestination = MIDIGetDestination(d)
                midiDestinations.append(midiDestination)
                
                var midiDestinationName : Unmanaged<CFString>?
                var status = OSStatus(noErr)
                status = MIDIObjectGetStringProperty(midiDestination, kMIDIPropertyDisplayName, &midiDestinationName)
                if status == noErr {
                    let midiDestinationDisplayName = midiDestinationName!.takeRetainedValue() as String
                    midiDestinationNames.append(midiDestinationDisplayName)
                }
                
            }
            
            //compare names with array in defaults
            //when there is a match, add that index to the active index array
            
            //loop through midiDestinations names
            for n:Int in 0 ..< midiDestinationNames.count {
                
                //grab midi destination name
                let midiDestinationName:String = midiDestinationNames[n]
                
                //TODO: get user selected midi destinations names from the incoming instrument
                //loop through user selected names
                /*
                for userSelectedMidiDestinationName in settings.userSelectedMidiDestinationNames {
                    
                    if (midiDestinationName == String(describing: userSelectedMidiDestinationName)) {
                        activeMidiDestinationIndexes.append(n)
                    }
                    
                }*/
            }
            
            if (debug) {
                //print("MIDI -> User Selected:", settings.userSelectedMidiDestinationNames)
                print("MIDI -> MIDI Dest:    ", midiDestinations)
                print("MIDI -> MIDI Names:   ", midiDestinationNames)
                print("MIDI -> MIDI Active:  ", activeMidiDestinationIndexes)
            }
            
            
        } else {
            if (debug) { print("MIDI -> ERROR no destinations detected") }
        }

    }
    
    
    
    //MARK:-
    //MARK: SEQUENCER
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
    
    
    //MARK:-
    //MARK: MIDI CLOCK
    //called by sequencer metronome
    internal func sendMidiClock(){
        let clockData:[UInt8] = [0xF8]
        sendMidi(data: clockData)
    }
    
    //MARK: -
    //MARK: NOTES
    internal func noteOn(channel:Int, destinations:[String], note:UInt8, velocity:UInt8){
        
        //if (noteDebug){
            print("MIDI -> note on", channel, destinations, note)
        //}
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromInt: channel)
        
        //create byte for note on
        let noteOnByte:UInt8 = Utils.getByte(fromStr: NOTE_ON_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [noteOnByte, UInt8(note), UInt8(velocity)]
        
        //send data
        sendMidi(data: midiData)
        
    }
    
    internal func noteOff(channel:Int, note:UInt8){
        
        if (noteDebug){ print("MIDI -> note off", channel, note) }
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromInt: channel)
        
        //create byte for note off
        let noteOffByte:UInt8 = Utils.getByte(fromStr: NOTE_OFF_PREFIX + midiChannelHex)
        
        //note off has zero velocity
        let noteOffVelocity:UInt8 = 0
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [noteOffByte, UInt8(note), noteOffVelocity]
    
        //send midi
        sendMidi(data: midiData)
        
    }
    
    internal func allNotesOff(){
        
        if (debug){
            print("MIDI -> all notes off")
        }
        
        //note off has zero velocity
        let noteOffVelocity:UInt8 = 0
        
        for channel:Int in 0 ..< MIDI_CHANNEL_TOTAL {
            
            //convert midi channel to a hex
            let midiChannelHex:String = Utils.getHexString(fromInt: channel)
            
            //create byte for note off
            let noteOffByte:UInt8 = Utils.getByte(fromStr: NOTE_OFF_PREFIX + midiChannelHex)
            
            for noteNum:Int in 0 ..< MIDI_NOTES_MAX {
                
                if (debug){print("MIDI -> Note off: ch =", channel, "note =", noteNum)}
                
                //midi data = status (midi command + channel), note number, velocity
                let midiData : [UInt8] = [noteOffByte, UInt8(noteNum), noteOffVelocity]
                
                sendMidi(data: midiData)

            }
            
        }
        
    }
    
    
    //MARK: -
    //MARK: SEND DATA
    fileprivate func sendMidi(data:[UInt8]){
        
        
        //TODO: fix hack
        //activeMidiDestinationIndexes = midiDestinations
        
        //if there are any active destinations
        //if (activeMidiDestinationIndexes.count > 0){
            
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
            
            //loop through active destinations and send midi to them all
            //TODO: how to caluculate which destinations are active...?
            for destEndpointRef in midiDestinations {
               // let destEndpointRef:MIDIEndpointRef = midiDestinations[index]
                MIDISend(outputPort, destEndpointRef, packetList)
            }
            
            //release
            free(packetList)

       // } else {
         //   if (debug){ print("MIDI -> Error no active MIDI destinations during sendMidi") }
        //}
        
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
    
    fileprivate func initOutputPort() -> Bool {
        
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

    
}
