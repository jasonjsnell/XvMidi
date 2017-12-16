//
//  XvMidiConstants.swift
//  XvMidi
//
//  Created by Jason Snell on 3/6/17.
//  Copyright © 2017 Jason J. Snell. All rights reserved.
//

import Foundation

public class XvMidiConstants {
    
    //MARK: - NOTIFICATIONS -
    //MARK: receive system commands
    public static let kXvMidiReceiveSystemStart:String = "kXvMidiReceiveSystemStart"
    public static let kXvMidiReceiveSystemStop:String = "kXvMidiReceiveSystemStop"
    public static let kXvMidiReceiveSystemContinue:String = "kXvMidiReceiveSystemContinue"
    public static let kXvMidiReceiveSystemPosition:String = "kXvMidiReceiveSystemPosition"
    public static let kXvMidiReceiveSystemTempoChange:String = "kXvMidiReceiveSystemTempoChange"
    public static let kXvMidiReceiveSystemClock:String = "kXvMidiReceiveSystemClock"
    
    //MARK: receive note commands
    public static let kXvMidiReceiveNoteOn:String = "kXvMidiReceiveNoteOn"
    public static let kXvMidiReceiveNoteOff:String = "kXvMidiReceiveNoteOff"
    
    //MARK: control changes
    public static let kXvMidiReceiveControlChange:String = "kXvMidiReceiveControlChange"
    
    //MARK: setup notifications
    public static let kXvMidiSetupChanged:String = "kXvMidiSetupChanged"
    
    //MARK: destinations
    public static let kXvMidiNoDestinationError:String = "kXvMidiNoDestinationError"
    
    //MARK: bypass
    public static let kXvMidiSendBypass:String = "kXvMidiSendBypass"
    
    //MARK: - CONSTANTS -

    //MARK: Midi Sync
    public static let MIDI_CLOCK_RECEIVE:String = "midiClockReceive"
    public static let MIDI_CLOCK_SEND:String = "midiClockSend"
    public static let MIDI_CLOCK_NONE:String = "midiClockNone"
    
    public static let MIDI_DESTINATION_OMNI:String = "Omni"
    public static let MIDI_SOURCE_OMNI:String = "Omni"
    
    public static let MIDI_SYSTEM_CHANNEL:Int = -1
    
    //translations into MIDI friendly data
    
    public static let NOTE_ON_PREFIX:String = "9"
    public static let NOTE_OFF_PREFIX:String = "8"
}
