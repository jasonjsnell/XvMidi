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
    static let sharedInstance = XvMidi()
    fileprivate init() {}
    
    //MARK:- VARIABLES -
    
    //midi objects
    fileprivate let midiSend:Send = Send.sharedInstance
    fileprivate let midiReceive:Receive = Receive.sharedInstance
    fileprivate var midiClient = MIDIClientRef()
    fileprivate let utils:Utils = Utils.sharedInstance
    fileprivate let settings:XvMidiSettings = XvMidiSettings.sharedInstance
    
    //bools
    fileprivate var active:Bool = false
    fileprivate var debug:Bool = false
    
    
    //MARK: - PUBLIC API -
    
    //MARK: INIT
    //called by app delegate on app launch
    //called by DefaultsManager when leaving settings panel
    public func initMidi() {
        
        //MARK: CHECK USER DEFAULTS
        //if any midi functionality is on...
        
        if (settings.midiSendEnabled ||
            settings.midiReceiveEnabled ||
            settings.midiSync != XvMidiConstants.MIDI_CLOCK_NONE) {
            
            //... activate midi interface
            
            if (debug){ print("MIDI: Init")}
            
            //MARK: INIT SESSION
            //this allows the device to show up in NetWork Session devices
            //http://stackoverflow.com/questions/34258035/xcode-iphone-simulator-not-showing-up-in-audio-midi-setup-midi-network-setup
            let session = MIDINetworkSession.default()
            session.isEnabled = true
            session.connectionPolicy = MIDINetworkConnectionPolicy.anyone
            
            
            //MARK: INIT MIDI CLIENT
            //create notifcation blocks for watching messages
            let notifyBlock: MIDINotifyBlock = NotificationBlock.sharedInstance.notifyBlock
            
            //create MIDI client
            var status = OSStatus(noErr)
            status = MIDIClientCreateWithBlock("com.jasonjsnell.refraktions.MyMIDIClient" as CFString, &midiClient, notifyBlock)
            
            
            //if client is created...
            if status == OSStatus(noErr) {
                
                //system is now active
                active = true
                
                //start with receive (send comes after receive is complete or declined
                initMidiReceive()
                
            }
            
        } else {
            if (debug){ print("MIDI: MIDI not enabled in user prefs, shutdown system") }
            shutdown()
        }
        
    }
    
    //MARK: - ACCESSORS
    //checked by app delegate
    public func isActive() -> Bool {
        return active
    }
    
    public func set(debug:Bool) {
        self.debug = debug
        NotificationBlock.sharedInstance.debug = debug
        Receive.sharedInstance.debug = debug
        ReceiveClock.sharedInstance.debug = debug
        Send.sharedInstance.debug = debug
    }

    
    //MARK: - NOTES
    
    public func noteOn(channel:Int, note:UInt8, velocity:UInt8){
        
        //if send is enabled
        if (settings.midiSendEnabled){
            
            //convert values to MIDI usable and send out
            midiSend.noteOn(
                channel: channel,
                note: note,
                velocity: velocity
            )
            
        }
        
    }
    
    public func noteOff(channel:Int, note:UInt8){
        
        //if send is enabled
        if (settings.midiSendEnabled){
            
            //convert values to MIDI usable and send out
            midiSend.noteOff(channel: channel, note: note)
            
        }
        
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
    //SetMain -> MIDI IO -> MIDI SEND
    public func refreshMidiDestinations(){
        midiSend.refreshMidiDestinations()
    }
    
    //SetMain -> MIDI IO -> MIDI SEND
    public func getMidiDestinationNames() -> [String] {
        return midiSend.getMidiDestinationNames()
    }
    
    //SetMain -> MIDI IO -> MIDI SEND
    public func getActiveMidiDestinationIndexes() -> [Int] {
        return midiSend.getActiveMidiDestinationIndexes()
    }

    //MARK: - RESET 
    
    //called by user input
    //called by defaults manager when new kit is loaded
    //called by shutdown func locally
    
    public func allNotesOff(){
        if (settings.midiSendEnabled){
            midiSend.allNotesOff()
        }
    }
    
    //called by app delegate if leaving app and background mode is off
    //called by settings panel if toggle is switched off
    public func shutdown(){
        if (debug){ print("MIDI: shutdown") }
        active = false
        sequencerStop()
        midiReceive.reset()
        midiSend.reset()
        midiClient = 0
    }


    
    //MARK: - PRIVATE API -
    
    //MARK: INIT MIDI RECEIVE
    //called locally
    fileprivate func initMidiReceive(){
        
        //if receive enabled or midi clock is set to receive...
        
        if (settings.midiReceiveEnabled ||
            settings.midiSync == XvMidiConstants.MIDI_CLOCK_RECEIVE)
        {
            
            //...then init receive
            midiReceive.setup(withClient: midiClient)
            
        } else {
            
            //...else move on to init send
            initMidiSend()
        }
        
    }
    
    //MARK: INIT MIDI SEND
    //called by MidiReceive when its setup is complete
    internal func initMidiSend(){
        
        //if send enabled or midi clock is set to send, then init send
        if (settings.midiSendEnabled || settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.setup(withClient: midiClient)
        }
        
    }
    
}

