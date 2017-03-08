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
    public static let kXvMidiReceiveSystemClock:String = "kXvMidiReceiveSystemClock"
    
    //MARK: receive note commands
    public static let kXvMidiReceiveNoteOn:String = "kXvMidiReceiveNoteOn"
    public static let kXvMidiReceiveNoteOff:String = "kXvMidiReceiveNoteOff"
    
    //MARK: setup notifications
    public static let kXvMidiSetupChanged:String = "kXvMidiSetupChanged"
    
    //MARK: - CONSTANTS -
    
    //MARK: Midi Sync
    public static let MIDI_CLOCK_RECEIVE:String = "midi_clock_receive"
    public static let MIDI_CLOCK_SEND:String = "midi_clock_send"
    public static let MIDI_CLOCK_NONE:String = "midi_clock_none"
    
    //MARK: Midi send, receive
    public static let kMidiSendEnabled:String = "midi_send_enabled"
    public static let kMidiReceiveEnabled:String = "midi_receive_enabled"
    
    //MARK: Midi sources, destinations
    public static let kMidiDestinations:String = "midi_destinations"
    
    //MARK: Midi sync
    public static  let kMidiSync:String = "midi_sync"
    
}
