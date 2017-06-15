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
    internal var midiSync:String = ""
    
    internal static let sharedInstance = Settings()
    fileprivate init() {
        midiSync = XvMidiConstants.MIDI_CLOCK_NONE
    }
    
    internal func set(midiSync:String){
        self.midiSync = midiSync
    }
    
}
