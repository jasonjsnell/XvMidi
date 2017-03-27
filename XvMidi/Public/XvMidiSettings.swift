//
//  MidiSettings.swift
//  XvMidi
//
//  Created by Jason Snell on 3/5/17.
//  Copyright © 2017 Jason J. Snell. All rights reserved.
//

import Foundation

public class XvMidiSettings {
    
    //MARK: - VARS -
    
    //bools to indicate which parts of the system are active or inactive
    internal var midiSendEnabled:Bool = false
    internal var midiReceiveEnabled:Bool = false
    
    //midi sync
    internal var midiSync:String = ""
    
    //names of sources / destinations selected in user prefs
    internal var userSelectedMidiDestinationNames:[Any] = []
    // internal var userSelectedMidiSourceNames:[String] = [] // not used yet
    
    //MARK: - INIT -
    //singleton code
    public static let sharedInstance = XvMidiSettings()
    fileprivate init() {
        midiSync = XvMidiConstants.MIDI_CLOCK_NONE
    }
    
    //setters
    public func set(midiSendEnabled:Bool){
        self.midiSendEnabled = midiSendEnabled
    }
    
    public func set(midiReceiveEnabled:Bool){
        self.midiReceiveEnabled = midiReceiveEnabled
    }
    
    public func set(midiSync:String){
        self.midiSync = midiSync
    }
    
    public func set(userSelectedMidiDestinationNames:[Any]){
        self.userSelectedMidiDestinationNames = userSelectedMidiDestinationNames
    }
    
    /*
     public func set(userSelectedMidiSourceNames:[Any]){
     self.userSelectedMidiSourceNames = userSelectedMidiSourceNames
     }
     */
    
}
