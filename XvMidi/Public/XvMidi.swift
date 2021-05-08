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


@objc public protocol XvMidiDelegate:AnyObject {
    func didReceiveMidiSystemStart()
    func didReceiveMidiSystemStop()
    func didReceiveMidiContinue()
    func didReceiveMidi(position:Int)
    func didReceiveMidi(tempo:Double)
    func didReceiveMidiClock()
    func didReceiveMidiOn(note:UInt8, channel:UInt8, velocity:UInt8)
    func didReceiveMidiOff(note:UInt8, channel:UInt8)
    func didReceiveMidi(control:UInt8, channel:UInt8, value:UInt8)
    func didReceiveMidi(program:UInt8, channel:UInt8)
    func didReceiveMidiSetupChange()
    @objc optional func sendToAudiobus(packetList:UnsafeMutablePointer<MIDIPacketList>, channel:UInt8, system:Bool)
}


import Foundation
import CoreMIDI

public class XvMidi:NotificationBlockDelegate {
    
    fileprivate var debug:Bool = false
    
    //singleton code
    public static let sharedInstance = XvMidi()
    fileprivate init() {}
    
    //delegate
    fileprivate weak var delegate:XvMidiDelegate?
    public func set(delegate:XvMidiDelegate) {
        
        self.delegate = delegate
        midiSend.set(delegate: delegate)
        midiReceive.set(delegate: delegate)
    }
    
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
    
    
    
    //MARK: - PUBLIC API -
    
    //MARK: INIT
    
    //generic init using Omni sources and destinations for a quick setup
    public func initMidi(withAppID:String) -> Bool {
        
        return initMidi(
            withAppID: withAppID,
            withSourceNames: [XvMidiConstants.MIDI_SOURCE_OMNI],
            withDestinationNames: [XvMidiConstants.MIDI_DESTINATION_OMNI]
        )
    }
    
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
            NotificationBlock.sharedInstance.delegate = self
            let notifyBlock: MIDINotifyBlock = NotificationBlock.sharedInstance.notifyBlock
        
            
            //create MIDI client
            status = MIDIClientCreateWithBlock("com.jasonjsnell."+appID+".MyMIDIClient" as CFString, &midiClient, notifyBlock)
            
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
            
            if (debug){ print("MIDI <> Session already activated, but refresh destinations") }
            midiSend.refreshDestinations()
            return true
        }        
    }
    
    //MARK: INIT MIDI RECEIVE
    public func initMidiReceive(withSourceNames:[String]) -> Bool {
        
        return midiReceive.setup(appID: appID, withClient: midiClient, withSourceNames: withSourceNames)
    }
    
    //MARK: INIT MIDI SEND
    public func initMidiSend(withDestinationNames:[String]) -> Bool {
        
        return midiSend.setup(withAppID:appID, withClient: midiClient, withDestinatonNames: withDestinationNames)
    }
    
    //MARK: - ACCESSORS
    
    public func getVelocity(fromVolume:Float) -> UInt8 {
        return Utils.getVelocity(fromVolume: fromVolume)
    }
    
    public var isReceivingExternalClock:Bool {
        get {
            return ReceiveClock.sharedInstance.active
        }
    }
    
    //MARK: - SETTERS
    
    //setters

    public var midiSync:String {
        set { settings.midiSync = newValue }
        get { return settings.midiSync }
    }
    
    //MARK: - NOTES
    
    public func noteOn(channel:UInt8, destinations:[String] = [], note:UInt8, velocity:UInt8){
        
        midiSend.noteOn(
            channel: channel,
            destinations: destinations,
            note: note,
            velocity: velocity
        )
    }
    
    public func noteOff(channel:UInt8, destinations:[String] = [], note:UInt8){
        
        //convert values to MIDI usable and send out
        midiSend.noteOff(channel: channel, destinations: destinations, note: note)
    }
    
    //MARK: - CC
    public func controlChange(channel:UInt8, destinations:[String] = [], controller:UInt8, value:UInt8){
        
        midiSend.controlChange(
            channel: channel,
            destinations: destinations,
            controller: controller,
            value: value
        )
        
    }
    
    public func programChange(channel:UInt8, destinations:[String] = [], program:UInt8){
     
        midiSend.programChange(
            channel: channel,
            destinations: destinations,
            program: program
        )
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
    public func sendMidiClock(destinations:[String] = []){
        if (settings.midiSync == XvMidiConstants.MIDI_CLOCK_SEND){
            midiSend.sendMidiClock(destinations: destinations)
        }
    }
    
    //MARK: midi destinations
    //AppDel -> MIDI IO -> MIDI SEND
    
    public func refreshMidiDestinations(){
 
        midiSend.refreshDestinations()
    }
    
    
    //RootVC -> MIDI IO -> MIDI SEND
    public func getAvailableMidiDestinationNames() -> [String] {
    
        return midiSend.getAvailableMidiDestinationNames()
    }
    
    public func setUserMidiDestinations(with names:[String]){
        
        midiSend.setUserDestinations(with: names)
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
    
    //MARK: - NOTIFICATION BLOCK
    public func didReceiveMidiSetupChange() {
        
        //update midi send destinations
        midiSend.refreshDestinations()
        
        //pass up to delegate
        delegate?.didReceiveMidiSetupChange()
    }
    
    //MARK: - RECEIVE BLOCK
    //called by audiobus receive block
    public func process(packetList:UnsafePointer<MIDIPacketList>){
        
        midiReceive.process(packetList: packetList)
    }
    
    //MARK: - RESET 
    
    //called by user input
    //TODO: Future: called by defaults manager when new config is loaded
    //called by shutdown func locally
    
    public func allNotesOff(){
        midiSend.allNotesOff()
    }
    
    //called by user input when track area is cleared via gesture
    public func allNotesOff(ofChannel:UInt8){
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

