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

struct XvMidiDestination {
    var name:String
    var ref:MIDIEndpointRef
}

class Send {
    
    fileprivate let debug:Bool = false
    fileprivate let noteDebug:Bool = false
    fileprivate let sysDebug:Bool = true
    
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
    fileprivate var virtualMidiOutput:MIDIEndpointRef = MIDIEndpointRef()
    
    fileprivate var allDestinations:[XvMidiDestination] = []
    fileprivate var userDestinations:[XvMidiDestination] = [] //destinations selected by user
    
    //MIDI constants
    fileprivate let MIDI_CHANNEL_TOTAL:Int = 16
    fileprivate let MIDI_NOTES_MAX:Int = 128
    fileprivate let NOTE_OFF_VELOCITY:UInt8 = 0
    
    //MARK: -
    //MARK: INIT
    
    
   
    internal func setup(withAppID:String, withClient:MIDIClientRef, withDestinatonNames:[String]) -> Bool {
        
        //app id
        self.appID = withAppID
        
        //grab local version of client so disconnect can happen in reset func
        self.midiClient = withClient
        
        //make sure incoming client is valid
        if (midiClient != 0) {
            
            //if output port is successfully initialized...
            if (_initOutputPort() && _initVirtualMidiOut()){
                
                //sets the user selected destinations
                setUserDestinations(with: withDestinatonNames)
                
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

        var names:[String] = []
        for dest in allDestinations {
            names.append(dest.name)
        }
        return names
    }
    
    internal func setUserDestinations(with destinationNames:[String]){
        
        //clear user list and replace with incoming
        userDestinations = []
        
        //refresh list of destinations from MIDI system
        refreshDestinations()
        
        //loop through incoming names
        for name in destinationNames {
            
            //if using virtual only, then keep user destinations blank
            if (name == XvMidiConstants.MIDI_DESTINATION_VIRTUAL_ONLY) {
                userDestinations = []
                print("MIDI -> User destinations: Virtual only")
                return
            }
            
            //if the name is omni, then add all the names and stop the loop
            if (name == XvMidiConstants.MIDI_DESTINATION_OMNI){
                
                userDestinations = allDestinations
                break
            }
            
            //loop through each avail dest
            for availableDestination in allDestinations {
                
                //if the name is in the available destinations
                if (availableDestination.name == name) {
                    
                    //add it to the active list
                    userDestinations.append(availableDestination)
                    break
                }
            }
        }
        
        print("MIDI -> User destinations", userDestinations)
    }
    
    internal func refreshDestinations() {
        
        //reset
        allDestinations = []
      
        if (debug) {print("MIDI -> Refresh, # of destinations: \(MIDIGetNumberOfDestinations())")}
        
        //check destinations
        if (MIDIGetNumberOfDestinations() > 0){
            
            //loop through destinations and names and save in arrays
            
            for i in (0 ..< MIDIGetNumberOfDestinations()){
                
                let midiDestination = MIDIGetDestination(i)
                let midiDestinationName:String = _getName(for: midiDestination)
                
                //add destinations except self, which is the virtual out
                //the virtual out is always sending midi data and not part of this user selected list of targets
                if (midiDestinationName != appID) {
                    allDestinations.append(XvMidiDestination(name: midiDestinationName, ref: midiDestination))
                }
            }
            
            if (debug) {
                print("MIDI -> MIDI Dest:    ", allDestinations)
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
        sendSystemMidi(data: midiData, toDestinations: userDestinations)
        
    }
    
    internal func sequencerStop(){
        
        if(debug){ print("MIDI -> Sequencer stop") }
        
        //MIDI Stop command
        let midiData : [UInt8] = [0xFC]
        sendSystemMidi(data: midiData, toDestinations: userDestinations)
        
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
        sendSystemMidi(data: midiData, toDestinations: userDestinations)
        
        
    }
    
    
    //MARK:- MIDI CLOCK
    //called by sequencer metronome
    internal func sendMidiClock(destinations:[String] = []){
        
        let clockData:[UInt8] = [0xF8]
        let destinationObjs:[XvMidiDestination] = _getDestinations(from: destinations)
        sendSystemMidi(data: clockData, toDestinations: destinationObjs)
    }
    
    //MARK: - NOTES
    internal func noteOn(channel:UInt8, destinations:[String], note:UInt8, velocity:UInt8){
        
        //get objects from incoming name strings
        let destinationObjs:[XvMidiDestination] = _getDestinations(from: destinations)
        
        if (noteDebug){
            print("MIDI -> note on", channel, destinationObjs, note, velocity)
        }
        
        //convert channel to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: channel)
        
        //create status byte for note on
        let statusByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.NOTE_ON_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [statusByte, UInt8(note), UInt8(velocity)]
        
        //send data
        sendMidi(data: midiData, toDestinations: destinationObjs, onChannel:channel)
        
    }
    
    internal func noteOff(channel:UInt8, destinations:[String], note:UInt8){
        
        //get objects from incoming name strings
        let destinationObjs:[XvMidiDestination] = _getDestinations(from: destinations)
        
        if (noteDebug){
            print("MIDI -> note off", channel, destinationObjs, note)
        }
        
        //convert it to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: channel)
        
        //create status byte for note off
        let statusByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.NOTE_OFF_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), note number, velocity
        let midiData : [UInt8] = [statusByte, UInt8(note), NOTE_OFF_VELOCITY]
    
        //send midi
        sendMidi(data: midiData, toDestinations: destinationObjs, onChannel: channel)
        
    }
    
    internal func allNotesOff(){
        
        if (debug){ print("MIDI -> all notes off") }
        
        for channel:Int in 0..<MIDI_CHANNEL_TOTAL {
            
            allNotesOff(ofChannel: UInt8(channel))
        }
    }
    
    internal func allNotesOff(ofChannel:UInt8) {
        
        //convert midi channel to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: ofChannel)
        
        //create status byte for note off
        let statusByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.NOTE_OFF_PREFIX + midiChannelHex)
        
        for noteNum:Int in 0 ..< MIDI_NOTES_MAX {
            
            if (debug){print("MIDI -> Note off: ch =", ofChannel, "note =", noteNum)}
            
            //midi data = status (midi command + channel), note number, velocity
            let midiData : [UInt8] = [statusByte, UInt8(noteNum), NOTE_OFF_VELOCITY]
    
            sendMidi(data: midiData, toDestinations: userDestinations, onChannel: ofChannel)
        }
    }
    
    //MARK: - CONTROL CHANGE
    internal func controlChange(channel:UInt8, destinations:[String], controller:UInt8, value:UInt8){
        
        //get objects from incoming name strings
        let destinationObjs:[XvMidiDestination] = _getDestinations(from: destinations)
        
        if (noteDebug){
            print("MIDI -> CC", controller, value, destinationObjs)
        }
        
        //convert channel to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: channel)
        
        //create byte for CC
        let statusByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.CONTROL_CHANGE_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), controller, value
        let midiData : [UInt8] = [statusByte, UInt8(controller), UInt8(value)]
        
        //MIDI Monitor: Control    1    General Purpose 2 (coarse)    81
        
        //send data
        sendMidi(data: midiData, toDestinations: destinationObjs, onChannel:channel)
        
    }
    
    //MARK: - PROGRAM CHANGE
    internal func programChange(channel:UInt8, destinations:[String], program:UInt8){
        
        //get objects from incoming name strings
        let destinationObjs:[XvMidiDestination] = _getDestinations(from: destinations)
    
        if (noteDebug){
            print("MIDI -> ProgChange", program, destinationObjs)
        }
        
        //convert channel to a hex
        let midiChannelHex:String = Utils.getHexString(fromUInt8: channel)
        
        //create byte for program change
        let statusByte:UInt8 = Utils.getByte(fromStr: XvMidiConstants.PROGRAM_CHANGE_PREFIX + midiChannelHex)
        
        //input incoming data into UInt8 array
        //midi data = status (midi command + channel), progam number
        let midiData : [UInt8] = [statusByte, UInt8(program)]
       
        //send data
        sendMidi(data: midiData, toDestinations: destinationObjs, onChannel:channel)
    }
    
    
    //MARK: - MIDI OUT
    
    //sends system data
    fileprivate func sendSystemMidi(data:[UInt8], toDestinations:[XvMidiDestination]){
        
        //route to main send func with system flag on
        sendMidi(data: data, toDestinations: toDestinations, onChannel: 0, system: true)
        
    }
    
    //main send func
    fileprivate func sendMidi(data:[UInt8], toDestinations:[XvMidiDestination], onChannel:UInt8, system:Bool = false){
        
        //prepare midi packet
        
        //https://en.wikipedia.org/wiki/Nibble#Low_and_high_nibbles
        //http://www.blitter.com/~russtopia/MIDI/~jglatt/tech/midispec/noteon.htm
        
        //packet memory management
        //http://www.gneuron.com/?p=96
        
        //create
        //var packet:UnsafeMutablePointer<MIDIPacket> = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        let packetList:UnsafeMutablePointer<MIDIPacketList> = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
        
        //init
        var packet = MIDIPacketListInit(packetList)
        
        //grab length
        let packetLength:Int = data.count
        
        //packet byte size
        let packetByteSize:Int = 1024
        
        //set to now for instant delivery
        let timeStamp:MIDITimeStamp = MIDITimeStamp(0)
        
        //add packet data to the packet list
        packet = MIDIPacketListAdd(packetList, packetByteSize, packet, timeStamp, packetLength, data)
        
        if (noteDebug){
            print("MIDI Sending:")
            Utils.printContents(ofPacket: packet)
        }
        
        //MARK: Virtual MIDI out
        //always send to MIDI virtual output
        if (virtualMidiOutput != 0){
            
            let status = MIDIReceived(virtualMidiOutput, packetList)
            
            if status == OSStatus(noErr) {
                
                if (noteDebug){
                    print("MIDI -> Success sending from virtual output")
                }
                
            } else {
                print("MIDI -> Error sending from virutal output", status)
            }
            
        } else {
            print("MIDI -> Error: virtual output is 0 during MIDI send")
        }
        
        
        if (!_bypass){
            
            //MARK: Standard MIDI out
          
            if (noteDebug){ print("MIDI -> destinations:", toDestinations) }
            
            //loop through destinations and send midi to them all
            
            for destination in toDestinations {
                MIDISend(outputPort, destination.ref, packetList)
            }
            
        } else {
            
            //MARK: Audiobus MIDI out
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
        
        //deinit and dealloc packet list
        packetList.deinitialize(count: 1)
        packetList.deallocate()
        
        // deinit packet
        packet.deinitialize(count: 1)
    
    }
    
    
    //MARK: -
    //MARK: RESET
    internal func shutdown(){
        
        if (sysDebug) { print("MIDI -> Shutdown") }
        
        //if system is active, then send all notes off command to refreshed destinations
        if (midiClient != 0 && outputPort != 0) {
            refreshDestinations()
            allNotesOff()
        }
        
        MIDIPortDispose(outputPort)
        outputPort = 0
        midiClient = 0
        allDestinations = []
        userDestinations = []
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
    
    fileprivate func _initVirtualMidiOut() -> Bool {
        
        //status var for error handling
        var status = OSStatus(noErr)
        
        //create input port with read block (that handles the incoming traffic)
        if (virtualMidiOutput == 0){
            
            status = MIDISourceCreate(
                midiClient,
                appID as CFString,
                &virtualMidiOutput)
            
            //error checking
            if status == OSStatus(noErr) {
                
                if (sysDebug) { print("MIDI <- Virtual source successfully created", virtualMidiOutput) }
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
    
    fileprivate func _getDestinations(from names:[String]) -> [XvMidiDestination] {
        
        //if using virtual only, return blank for real world destinations
        if (names.contains(XvMidiConstants.MIDI_DESTINATION_VIRTUAL_ONLY)) {
            return []
        }
        
        if (names.count == 0 || names.contains(XvMidiConstants.MIDI_DESTINATION_OMNI)) {
            return userDestinations
        }
        
        var destinations:[XvMidiDestination] = []
        
        for availableDestination in allDestinations {
            
            for name in names {
                if (name == availableDestination.name) {
                    destinations.append(availableDestination)
                    break
                }
            }
        }
        
        return destinations
    }
    
    
    fileprivate func _getName(for destination:MIDIEndpointRef) -> String {
        
        var midiDestinationName : Unmanaged<CFString>?
        var status = OSStatus(noErr)
        status = MIDIObjectGetStringProperty(destination, kMIDIPropertyDisplayName, &midiDestinationName)
        if status == noErr {
            let midiDestinationDisplayName = midiDestinationName!.takeRetainedValue() as String
            return midiDestinationDisplayName
        }
        
        return ""
    }

    
}
