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
    
    //midi sync
    fileprivate var _midiSync:String = ""
    internal var midiSync:String {
        get { return _midiSync }
        set { _midiSync = newValue}
    }
    
    internal static let sharedInstance = Settings()
    fileprivate init() {
        _midiSync = XvMidiConstants.MIDI_CLOCK_NONE
    }
    
    
    
    
}
