//
//  midiInterface.swift
//  Refraktions
//
//  Created by Jason Snell on 11/23/15.
//  Copyright © 2015 Jason J. Snell. All rights reserved.
//
// http://www.music-software-development.com/midi-tutorial.html

/*
Port for all MIDI communication and functions
Other classes -> MIDI IO -> MIDI Receive -> MIDI Receive Clock
Other classes -> MIDI IO -> MIDI Send -> MIDI Send Clock
 
 IN
 User Input
 Sequencer
 Settings Panel (gets MIDI destinations)
 
 OUT
 Sequencer
 Visual Output
 
*/

import Foundation
import CoreMIDI


public class XvMidi {
    
    //singleton code
    public static let sharedInstance = XvMidi()
    fileprivate init() {}
    
    //MARK:- VARIABLES -
    
    //app id
    fileprivate var appID:String = ""
    
    //midi objects
    fileprivate let midiSend:Send = Send.sharedInstance
    fileprivate let midiReceive:Receive = Receive.sharedInstance
    fileprivate var midiClient = MIDIClientRef()
    fileprivate let settings:Settings = Settings.sharedInstance

    fileprivate var _midiSourceNames:[String] = []
    fileprivate var _midiDestinationNames:[String] = []
    
    //bypass when audiobus MIDI functionality is on
    fileprivate var _bypass:Bool = false
    public var bypass:Bool {
        get {return _bypass}
        set {
            _bypass = newValue
            midiSend.bypass = newValue //pass down to children
            midiReceive.bypass = newValue
        }
    }
    
    //bools
    fileprivate var active:Bool = false
    fileprivate var debug:Bool = true
    
    
    //MARK: - PUBLIC API -
    
    //MARK: INIT
    //called by DefaultsManager on app launch
    //called by DefaultsManager when leaving settings panel
    public func initMidi(withAppID:String, withSourceNames:[String], withDestinationNames:[String]) -> Bool {
        
        if (debug){
            print("")
            print("MIDI <> Assess system launch")
        }
        
        //capture incoming vars
        self.appID = withAppID
        self._midiSourceNames = withSourceNames
        self._midiDestinationNames = withDestinationNames
        
        //activate midi interface
        
        var status = OSStatus(noErr)
        
        if (!active){
            
            //MARK: INIT SESSION
            //only init if system is not active
            //this allows the device to show up in NetWork Session devices
            //http://stackoverflow.com/questions/34258035/xcode-iphone-simulator-not-showing-up-in-audio-midi-setup-midi-network-setup
            
            MIDINetworkSession.default().isEnabled = true
            MIDINetworkSession.default().connectionPolicy = MIDINetworkConnectionPolicy.anyone
            
            //MARK: INIT MIDI CLIENT
            //create notifcation blocks for watching messages
            let notifyBlock: MIDINotifyBlock = NotificationBlock.sharedInstance.notifyBlock
            
            //create MIDI client
            status = MIDIClientCreateWithBlock("com.jasonjsnell.refraktions.MyMIDIClient" as CFString, &midiClient, notifyBlock)
            
            //if client is created...
            if status == OSStatus(noErr) {
                
                //system is now active
                active = true
                if (debug){ print("MIDI <> Session now active")}
                
                //if init midi receive and send are also successful...
                if (initMidiReceive(withSourceNames: _midiSourceNames) &&
                    initMidiSend(withDestinationNames: _midiDestinationNames)) {
                    
                    //then the overall launch is a success
                    return true
                } else {
                    
                    //else error
                    print("MIDI <> ERROR initializing send or receive")
                    return false
                }
                
            } else {
                
                // error occurred, midi session was not created
                print("MIDI <> ERROR during MIDIClientCreateWithBlock")
                return false
            }
            
        } else {
            
            if (debug){ print("MIDI <> Session already activated") }
            return true
        }        
    }
    
    //MARK: INIT MIDI RECEIVE
    public func initMidiReceive(withSourceNames:[String]) -> Bool {
        
        return midiReceive.setup(withClient: midiClient, withSourceNames: withSourceNames)
    }
    
    //MARK: INIT MIDI SEND
    public func initMidiSend(withDestinationNames:[String]) -> Bool {
        
        return midiSend.setup(withAppID:appID, withClient: midiClient, withDestinatonNames: withDestinationNames)
    }
    
    //MARK: - ACCESSORS
    
    public func getVelocity(fromVolume:Float) -> UInt8 {
        return Utils.getVelocity(fromVolume: fromVolume)
    }
    
    public func isReceivingExternalClock() -> Bool {
        return ReceiveClock.sharedInstance.active
    }
    
    //MARK: - SETTERS
    
    //setters
    //TODO: change to variable
    public func set(midiSync:String){
        settings.set(midiSync: midiSync)
    }
    
    //MARK: - NOTES
    
    public func noteOn(channel:Int, destinations:[String], note:UInt8, velocity:UInt8){
        
        //convert values to MIDI usable and send out
        midiSend.noteOn(
            channel: channel,
            destinations: destinations,
            note: note,
            velocity: velocity
        )
    }
    
    public func noteOff(channel:Int, destinations:[String], note:UInt8){
        
        //convert values to MIDI usable and send out
        midiSend.noteOff(channel: channel, destinations: destinations, note: note)
    }
    
    
    //MARK: - SYSTEM MESSAGES
    //MARK: start
    //called by
    public func sequencerStart(){
        
        if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.sequencerStart()
        }
        
    }
    
    //MARK: stop
    public func sequencerStop(){
        
        if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.sequencerStop()
        }
        
    }
    
    //MARK: restart
    public func sequencerRestart(){
        
        if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.sequencerStop()
            midiSend.sequencerStart()
        }
        
    }
    
    //MARK: position
    public func sequencerMove(toNewPosition:Int){
        
        if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.sequencerMove(toNewPosition: toNewPosition)
        }
    }
    
    //MARK: midi clock
    //User input -> sequencer -> MIDI IO -> MIDI SEND
    public func sendMidiClock(){
        if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.sendMidiClock()
        }
    }
    
    //MARK: midi destinations
    //AppDel -> MIDI IO -> MIDI SEND
    
    public func refreshMidiDestinations(){
        
        midiSend.refreshMidiDestinations()
    }
    
    
    //RootVC -> MIDI IO -> MIDI SEND
    public func getAvailableMidiDestinationNames() -> [String] {
        
        return midiSend.getAvailableMidiDestinationNames()
    }
    
    public func setActiveGlobalMidiDestinations(withDestinationNames:[String]){
        
        midiSend.setActiveGlobalMidiDestinations(withDestinationNames: withDestinationNames)
    }
    
    //MARK: midi sources
    //AppDel -> MIDI IO -> MIDI RECEIVE
    public func setActiveMidiSources(withSourceNames:[String]){
        
        midiReceive.setActiveMidiSources(withSourceNames: withSourceNames)
    }
    
    //RootVC -> MIDI IO -> MIDI RECEIVE
    public func getAvailableMidiSourceNames() -> [String] {
        
        return midiReceive.getAvailableMidiSourceNames()
    }
    
    
    //MARK: - RECEIVE BLOCK
    //called by audiobus receive block
    public func process(packetList:UnsafePointer<MIDIPacketList>){
        
        midiReceive.process(packetList: packetList)
    }
    
    //MARK: - RESET 
    
    //called by user input
    //called by defaults manager when new kit is loaded
    //called by shutdown func locally
    
    public func allNotesOff(){
        midiSend.allNotesOff()
    }
    
    //called by user input when instrument area is cleared via gesture
    public func allNotesOff(ofChannel:Int){
        midiSend.allNotesOff(ofChannel: ofChannel)
    }
    
    //called by app delegate if leaving app and background mode is off
    //called by settings panel if toggle is switched off
    public func shutdown(){
    
        if (debug){ print("MIDI <> Shutdown") }
        sequencerStop()
        midiReceive.shutdown()
        midiSend.shutdown()
        MIDIClientDispose(midiClient)
        midiClient = 0
        active = false
        
    }
    
}

