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
        let pct = fromVolume * 100
        
        //convert to number based on velocity max
        var velocity:Int = Int((127 * pct) / 100)
        
        //boost
        velocity += 70
        if (velocity > 127){
            velocity = 127
        }
        
        return UInt8(velocity)
        
    }
 
    
    //MARK: - HEX BYTE CONVERSTIONS
    //called by internal and by MidiSend
    class func getHexString(fromInt:Int) -> String {
        return String(fromInt, radix: 16, uppercase: true)
    }
    
    //http://stackoverflow.com/questions/24229505/how-to-convert-an-int-to-hex-string-in-swift
    //called by MidiSend
    class func getByte(fromInt:Int) -> UInt8 {
        return getByte(fromStr: getHexString(fromInt: fromInt))
    }
    
    //called by internal and by MidiSend
    class func getByte(fromStr:String) -> UInt8 {
        
        //http://stackoverflow.com/questions/30197819/given-a-hexadecimal-string-in-swift-convert-to-hex-value
        var byteArray = [UInt8]()
        
        let charCount:Int = fromStr.characters.count
        
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

    //MARK: - ERRORS
    
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

    
    //MARK: HELPERS
    
    class func getArrayOfCommonElements(fromArray1:[String], andArray2:[String]) -> [String]{
        
        return [""]
    }

    
    
}
