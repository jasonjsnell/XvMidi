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
    public var midiSendEnabled:Bool = false
    public var midiReceiveEnabled:Bool = false
    
    //midi sync
    public var midiSync:String = ""
    
    //names of sources / destinations selected in user prefs
    public var userSelectedMidiDestinationNames:[Any] = []
    // public var userSelectedMidiSourceNames:[String] = [] // not used yet
    
    //MARK: - INIT -
    //singleton code
    public static let sharedInstance = XvMidiSettings()
    fileprivate init() {
        midiSync = XvMidiConstants.MIDI_CLOCK_NONE
    }
    
}
