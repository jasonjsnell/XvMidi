//
//  MIDIErrors.swift
//  Refraktions
//
//  Created by Jason Snell on 12/1/15.
//  Copyright © 2015 Jason J. Snell. All rights reserved.
//
// NotificationBlock for when the MIDI system detects a change

import Foundation
import CoreMIDI

public protocol NotificationBlockDelegate:class {
    
    func didReceiveMidiSetupChange()
}

class NotificationBlock {
    
    internal var debug:Bool = false
    fileprivate let debugDetail:Bool = false
    
    fileprivate let settings:Settings = Settings.sharedInstance
    
    //object that listens to updates from this notification block
    internal weak var delegate:NotificationBlockDelegate?
    
    //singleton code
    static let sharedInstance = NotificationBlock()
    fileprivate init() {}
    
    internal func notifyBlock(midiNotification: UnsafePointer<MIDINotification>) {
        
        let notification = midiNotification.pointee
        
        //https://developer.apple.com/library/ios/documentation/CoreMidi/Reference/MIDIServices_Reference/#//apple_ref/c/tdef/MIDINotificationMessageID
        
        
        switch (notification.messageID) {
            
        case .msgSetupChanged:
            
            if (debug){ print("MIDI NOTIFY: MIDI setup changed")}
            
            midiNotification.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
                
                let m = $0.pointee
                
                if (debugDetail){
                    print("MIDI NOTIFY: id \(m.messageID) / size \(m.messageSize) / object \(m.object) / objectType  \(m.objectType)")
                }
            }
            
            delegate?.didReceiveMidiSetupChange() //pass up one level to XvMidi
            
            //too specific to Refraktions
            //outputCurrentMidiStatus()
            
            break
            
        case .msgObjectAdded:
            
            if (debug){ print("MIDI NOTIFY: added") }
            
            midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                
                let m = $0.pointee
                
                if (debugDetail){
                    print("MIDI NOTIFY: id \(m.messageID) / size \(m.messageSize)")
                    print("MIDI NOTIFY: child \(m.child) / child type \(m.childType)")
                    print("MIDI NOTIFY: parent \(m.parent) / parentType \(m.parentType)")
                }
            }
            
            break
            
        case .msgObjectRemoved:
            if (debug){ print("MIDI NOTIFY: kMIDIMsgObjectRemoved") }
            break
            
        case .msgPropertyChanged:
            
            if (debug){ print("MIDI NOTIFY: kMIDIMsgPropertyChanged") }
            
            midiNotification.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
                
                let m = $0.pointee
                
                if (debugDetail){
                    print("MIDI NOTIFY: id \(m.messageID) / size \(m.messageSize) / object \(m.object) / objectType  \(m.objectType)")
                }
            }
            
            break
            
        case .msgThruConnectionsChanged:
            if (debug){ print("MIDI NOTIFY: MIDI thru connections changed.") }
            break
            
        case .msgSerialPortOwnerChanged:
                if (debug){ print("MIDI NOTIFY: MIDI serial port owner changed.") }
            break
            
        case .msgIOError:
                if (debug){ print("MIDI NOTIFY: MIDI I/O error.") }
            break
            
        @unknown default:
            if (debug){ print("MIDI NOTIFY: Unknown error.")}
        }
        
    }
    
    /*
    //too specific to Refrkations
     
    fileprivate func outputCurrentMidiStatus(){
        
        print("")
        let sync = settings.midiSync
        let clockReceive:String = XvMidiConstants.MIDI_CLOCK_RECEIVE
        let clockSend:String = XvMidiConstants.MIDI_CLOCK_SEND
        
        let msgStr:String = "CONNECT"
        
        var clockStr:String = String()
        if (sync == clockSend){
            clockStr = "CLOCK : SEND"
        } else if (sync == clockReceive){
            clockStr = "CLOCK : RECEIVE"
        } else {
            clockStr = "CLOCK: NONE"
        }
        
        var totalStr:String = String()
        if (msgStr.count > 0 && clockStr.count > 0){
            totalStr = msgStr + "  |  " + clockStr
        } else if (msgStr.count > 0){
            totalStr = msgStr
        } else if (clockStr.count > 0){
            totalStr = clockStr
        }
        
        var duration:Double = 3.5
        
        //if message is none...
        if (totalStr.count == 0){
            totalStr = "none"
            duration = 2.5
        }
        
        //post with data
        
    }
    */
    
}
