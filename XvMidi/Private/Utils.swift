//
//  MidiUtils.swift
//  Refraktions
//
//  Created by Jason Snell on 12/14/16.
//  Copyright © 2016 Jason J. Snell. All rights reserved.
//

import Foundation
import CoreMIDI

class Utils {

    //MARK: - NOTIFICATIONS
    class func postNotification(name:String, userInfo:[AnyHashable : Any]?){
        
        let notification:Notification.Name = Notification.Name(rawValue: name)
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: userInfo)
    }
    
    
    //MARK: - VELOCITY / VOLUMES
    // convert a note volume (0.0 - 1.0) to a MIDI volume (0-127)
    // plus a boost tweak
    
    class func getVelocity(fromVolume:Float) -> UInt8 {
        
        //convert volume to percentage
        let pct:Float = fromVolume * 100

        //convert to number based on velocity max
        let velocity:Int = Int((XvMidiConstants.VELOCITY_MAX * pct) / 100)
        
        return UInt8(velocity)
        
    }
    
    //MARK: - HEX BYTE CONVERSTIONS
    //called by internal and by MidiSend
    class func getHexString(fromUInt8:UInt8) -> String {
        return String(fromUInt8, radix: 16, uppercase: true)
    }
    
    //http://stackoverflow.com/questions/24229505/how-to-convert-an-int-to-hex-string-in-swift
    //called by MidiSend
    class func getByte(fromUInt8:UInt8) -> UInt8 {
        return getByte(fromStr: getHexString(fromUInt8: fromUInt8))
    }
    
    //called by internal and by MidiSend
    class func getByte(fromStr:String) -> UInt8 {
        
        //http://stackoverflow.com/questions/30197819/given-a-hexadecimal-string-in-swift-convert-to-hex-value
        var byteArray = [UInt8]()
        
        let charCount:Int = fromStr.count
        
        if (charCount > 1){
            var from = fromStr.startIndex
            while from != fromStr.endIndex {
                let to = fromStr.index(from, offsetBy:2, limitedBy: fromStr.endIndex)
                if (to == nil){
                    break
                } else {
                    byteArray.append(UInt8(fromStr[from ..< to!], radix: 16) ?? 0)
                    from = to!
                }
            }
        } else {
            byteArray.append(UInt8(fromStr, radix: 16) ?? 0)
        }
        
        return byteArray[0]
    }

    
    //MARK: - OUTPUT
    
    //deprecated
    class func printContents(ofPacket:UnsafeMutablePointer<MIDIPacket>){
        
        let p = ofPacket.pointee
        
        
        let statusHex = String(format:"0x%X", p.data.0)
        let d1Hex = String(format:"0x%X", p.data.1)
        let d2Hex = String(format:"0x%X", p.data.2)
        
        let status:UInt8 = p.data.0
        let channel:UInt8 = status & 0x0F
        let rawStatus:UInt8 = status & 0xF0 // without channel
        let d1:UInt8 = p.data.1
        let d2:UInt8 = p.data.2
        
        print("MIDI Packet: CH:", (channel+1), "| Status:", statusHex, "/", rawStatus, "|", d1Hex, "/", d1, "|", d2Hex, "/", d2)
    }
    
    class func printContents(ofEventPacket:UnsafeMutablePointer<MIDIEventPacket>){
        
        let p = ofEventPacket.pointee
        
        print("")
        print("p", p)
        
      
        print("p.words.0", p.words.0)
        print("p.words.1", p.words.1)
        print("p.words.2", p.words.2)
        /*
         let statusHex = String(format:"0x%X", p.data.0)
        let d1Hex = String(format:"0x%X", p.data.1)
        let d2Hex = String(format:"0x%X", p.data.2)
        
        let status:UInt8 = p.data.0
        let channel:UInt8 = status & 0x0F
        let rawStatus:UInt8 = status & 0xF0 // without channel
        let d1:UInt8 = p.data.1
        let d2:UInt8 = p.data.2*/
        
        //print("MIDI Packet: CH:", (channel+1), "| Status:", statusHex, "/", rawStatus, "|", d1Hex, "/", d1, "|", d2Hex, "/", d2)
    }
    
    //used to show OSStatus errors from interface
    class func showError(withStatus:OSStatus) {
        
        switch withStatus {
            
        case OSStatus(kMIDIInvalidClient):
            print("MIDI ERROR: invalid client")
            break
        case OSStatus(kMIDIInvalidPort):
            print("MIDI ERROR: invalid port")
            break
        case OSStatus(kMIDIWrongEndpointType):
            print("MIDI ERROR: invalid endpoint type")
            break
        case OSStatus(kMIDINoConnection):
            print("MIDI ERROR: no connection")
            break
        case OSStatus(kMIDIUnknownEndpoint):
            print("MIDI ERROR: unknown endpoint")
            break
        case OSStatus(kMIDIUnknownProperty):
            print("MIDI ERROR: unknown property")
            break
        case OSStatus(kMIDIWrongPropertyType):
            print("MIDI ERROR: wrong property type")
            break
        case OSStatus(kMIDINoCurrentSetup):
            print("MIDI ERROR: no current setup")
            break
        case OSStatus(kMIDIMessageSendErr):
            print("MIDI ERROR: message send")
            break
        case OSStatus(kMIDIServerStartErr):
            print("MIDI ERROR: server start")
            break
        case OSStatus(kMIDISetupFormatErr):
            print("MIDI ERROR: setup format")
            break
        case OSStatus(kMIDIWrongThread):
            print("MIDI ERROR: wrong thread")
            break
        case OSStatus(kMIDIObjectNotFound):
            print("MIDI ERROR: object not found")
            break
        case OSStatus(kMIDIIDNotUnique):
            print("MIDI ERROR: not unique")
            break
        case OSStatus(kMIDINotPermitted):
            print("MIDI ERROR: not permitted")
            break
        default:
            print("MIDI ERROR: unknown status error \(withStatus)")
        }
    }

    
    //MARK: - HELPERS
    
    class func getArrayOfCommonElements(fromArray1:[String], andArray2:[String]) -> [String]{
        
        return [""]
    }

    
    
}
