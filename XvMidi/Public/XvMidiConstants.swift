//
//  XvMidiConstants.swift
//  XvMidi
//
//  Created by Jason Snell on 3/6/17.
//  Copyright © 2017 Jason J. Snell. All rights reserved.
//

import Foundation

public class XvMidiConstants {
    
    //MARK: - CONSTANTS -

    //MARK: Midi Sync
    public static let MIDI_CLOCK_RECEIVE:String = "midiClockReceive"
    public static let MIDI_CLOCK_SEND:String = "midiClockSend"
    public static let MIDI_CLOCK_NONE:String = "midiClockNone"
    
    public static let MIDI_DESTINATION_OMNI:String = "Omni"
    public static let MIDI_DESTINATION_VIRTUAL_ONLY:String = "Virtual"
    public static let MIDI_SOURCE_OMNI:String = "Omni"
    
    //translations into MIDI friendly data
    
    public static let VELOCITY_MAX:Float = 127
    
    //https://ccrma.stanford.edu/~craig/articles/linuxmidi/misc/essenmidi.html
    //http://fmslogo.sourceforge.net/manual/midi-table.html
    
    public static let NOTE_ON_PREFIX:String = "9"
    public static let NOTE_OFF_PREFIX:String = "8"
    public static let CONTROL_CHANGE_PREFIX:String = "B"
    public static let PROGRAM_CHANGE_PREFIX:String = "C"
    
    public static let NOTE_ON:UInt8 = 144
    public static let NOTE_OFF:UInt8 = 128
    public static let CONTROL_CHANGE:UInt8 = 176
    public static let PROGRAM_CHANGE:UInt8 = 192
    
}
