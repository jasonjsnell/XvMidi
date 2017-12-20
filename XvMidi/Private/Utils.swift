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
    
    //MARK: - REPACKAGING
    
    class func repackage(
        packetList: UnsafePointer<MIDIPacketList>,
        withChannel:UInt8) -> UnsafeMutablePointer<MIDIPacketList> {
        
        //set up vars
        let inPacketList:MIDIPacketList = packetList.pointee
        let inPacket:MIDIPacket = inPacketList.packet
        
        var outPacket:UnsafeMutablePointer<MIDIPacket> = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        let outPacketList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
        
        var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        ap.initialize(to: inPacket)
        
        //loop through packets. Sometimes a note on / off is in the same packet as timeclock
        for _ in 0 ..< inPacketList.numPackets {
            
            //print packet
            print("MIDI repackage")
            printContents(ofPacket: ap)
            
            //extract data
            let timeStamp:MIDITimeStamp = inPacket.timeStamp
            let status:UInt8 = inPacket.data.0
            let rawStatus:UInt8 = status & 0xF0 // without channel
            let d1:UInt8 = inPacket.data.1
            let d2:UInt8 = inPacket.data.2
            
            var outData:[UInt8]
            
            //if status is note on or off
            if (rawStatus == XvMidiConstants.NOTE_ON || rawStatus == XvMidiConstants.NOTE_OFF){
                
                //convert it to a hex
                let midiChannelHex:String = getHexString(fromUInt8: withChannel)
                var noteByte:UInt8 = 0
                
                if (rawStatus == XvMidiConstants.NOTE_ON){
                    
                    if (d2 == 0x0) {
                        
                        print("note off")
                        //some midi controllers request a note off by putting the velocity to 0
                        noteByte = Utils.getByte(fromStr: XvMidiConstants.NOTE_OFF_PREFIX + midiChannelHex)
                        
                    } else {
                        print("note on")
                        //else normal note on
                        noteByte = Utils.getByte(fromStr: XvMidiConstants.NOTE_ON_PREFIX + midiChannelHex)
                    }
                    
                } else if (rawStatus == XvMidiConstants.NOTE_OFF){
                    print("note off")
                    //note off
                    noteByte = Utils.getByte(fromStr: XvMidiConstants.NOTE_OFF_PREFIX + midiChannelHex)
                    
                } else {
                    
                    //catch all
                    noteByte = status
                }
                
                //input incoming data into UInt8 array
                outData = [noteByte, d1, d2]
                
            } else {
                
                //duplicate the same data
                outData = [status, d1, d2]
            }
            
            outPacket = MIDIPacketListInit(outPacketList)
            let outLength:Int = outData.count
            let outPacketByteSize:Int = 1024
            
            //add packet data to the packet list
            outPacket = MIDIPacketListAdd(outPacketList, outPacketByteSize, outPacket, timeStamp, outLength, outData)
            
            //prep next round
            ap = MIDIPacketNext(ap)
            
        }
        
        return outPacketList
    }
    
    
    class func getNoteData(fromPacketList: UnsafePointer<MIDIPacketList>) -> [UInt8]? {
        
        //set up vars
        let packetList:MIDIPacketList = fromPacketList.pointee
        let packet:MIDIPacket = packetList.packet
        
        var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        ap.initialize(to: packet)
        
        //loop through packets. Sometimes a note on / off is in the same packet as timeclock
        for _ in 0 ..< packetList.numPackets {
            
            //print packet
            print("")
            printContents(ofPacket: ap)
            
            //extract data
            let status:UInt8 = packet.data.0
            let rawStatus:UInt8 = status & 0xF0 // without channel
            let d1:UInt8 = packet.data.1
            let d2:UInt8 = packet.data.2
            
            //if status is note on or off
            if (rawStatus == XvMidiConstants.NOTE_ON || rawStatus == XvMidiConstants.NOTE_OFF){
                return [status, d1, d2]
            }
            
            //prep next round
            ap = MIDIPacketNext(ap)
            
        }
        
        return nil
    }
    
    //MARK: - VELOCITY / VOLUMES
    // convert a note volume (0.0 - 1.0) to a MIDI volume (0-127)
    // plus a boost tweak
    
    class func getVelocity(fromVolume:Float) -> UInt8 {
        
        //convert volume to percentage
        let pct:Float = fromVolume * 100
        
        //convert to number based on velocity max
        var velocity:Int = Int((XvMidiConstants.VELOCITY_MAX * pct) / 100)
        
        //TODO: test - may need to up default volumes
        //boost
        velocity += 70
        if (velocity > 127){
            velocity = 127
        }
        
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
