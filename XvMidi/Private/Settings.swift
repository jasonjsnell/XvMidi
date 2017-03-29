//
//  MidiSettings.swift
//  XvMidi
//
//  Created by Jason Snell on 3/5/17.
//  Copyright © 2017 Jason J. Snell. All rights reserved.
//

import Foundation

class Settings {
    
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
    internal static let sharedInstance = Settings()
    fileprivate init() {
        midiSync = XvMidiConstants.MIDI_CLOCK_NONE
    }
    
    //setters
    internal func set(midiSendEnabled:Bool){
        self.midiSendEnabled = midiSendEnabled
    }
    
    internal func set(midiReceiveEnabled:Bool){
        self.midiReceiveEnabled = midiReceiveEnabled
    }
    
    internal func set(midiSync:String){
        self.midiSync = midiSync
    }
    
    internal func set(userSelectedMidiDestinationNames:[Any]){
        self.userSelectedMidiDestinationNames = userSelectedMidiDestinationNames
    }
    
    /*
     internal func set(userSelectedMidiSourceNames:[Any]){
     self.userSelectedMidiSourceNames = userSelectedMidiSourceNames
     }
     */
    
}
