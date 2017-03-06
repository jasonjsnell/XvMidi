//
//  MIDITempo.swift
//  Refraktions
//
//  Created by Jason Snell on 12/1/15.
//  Copyright © 2015 Jason J. Snell. All rights reserved.

// Receives MIDI clock data from external source and converts it to a tempo
//

import Foundation
import CoreMIDI
import CoreAudioKit

class ReceiveClock{
    
    //singleton code
    static let sharedInstance = ReceiveClock()
    fileprivate init() {}
    
    fileprivate var exactTempo:Double = 0
    fileprivate var currRoundedTempo:Double = 0
    fileprivate var prevRoundedTempo:Double = 0
    
    //vars to store timestamp from midi packet
    fileprivate var currentClockTime:UInt64 = 0
    fileprivate var previousClockTime:UInt64 = 0
    
    // array to get last several tempos to calculate average
    fileprivate var previousTempos:[Double] = []
    fileprivate let TEMPO_SAMPLE_MAX:Int = 50
    
    internal var debug:Bool = false
    
    
    //MARK:-
    //MARK:PUBLIC
    internal func setTempo(withPacket:MIDIPacket){
        
        //measure distance between this timestamp and the last to calc tempo
        previousClockTime = currentClockTime
        currentClockTime = withPacket.timeStamp
        
        //if both times are valid, above 0
        if(previousClockTime > 0 && currentClockTime > 0) {
            
            //user mach_timebase_info to get nanoseconds
            let intervalInNanoseconds:UInt64 = nanosecondConversion(forTime: currentClockTime-previousClockTime)
            
            //if interval is valid, above 0
            if (intervalInNanoseconds > 0 ){
                
                //use all doubles, otherwise tempo gets rounded to nearest 60
                let intervalAsDouble = Double(intervalInNanoseconds)
                let secondsPerMinute:Double = 60
                let timesPerQuarterNote:Double = 24
                let kMillion:Double = 1000000
                let currTempo:Double = (kMillion / intervalAsDouble / timesPerQuarterNote) * secondsPerMinute
                
                //append curr tempo to array
                previousTempos.append(currTempo)
                
                //remove first values so it's the most recent values
                if (previousTempos.count > TEMPO_SAMPLE_MAX){
                    repeat {
                        previousTempos.remove(at: 0)
                    } while previousTempos.count > TEMPO_SAMPLE_MAX
                }
                
                //tally up the recent values to calc the average
                var temposTotal:Double = 0
                for i:Int in 0 ..< previousTempos.count{
                    temposTotal += previousTempos[i]
                }
                
                //calc exact tempo by averaging the array
                exactTempo = temposTotal / Double(previousTempos.count)
                
                //round the double
                currRoundedTempo = round(exactTempo)
               
                //the real tempo jitters, so round it off to see if it's changed
                if (currRoundedTempo != prevRoundedTempo){
                    
                    //if so, update the tempo class 
                    //TODO: set tempo becomes a notification
                    //let acceptedTempo:Double = Sequencer.sharedInstance.set(bpm:exactTempo)
                    //let roundedTempoString:String = String(round(10.0 * acceptedTempo) / 10.0)
                    //VisualOutput.sharedInstance.pulseText(header: "", sub: roundedTempoString)
        
                }
                prevRoundedTempo = currRoundedTempo
                
                if (debug){
                    print ("MIDI CLOCK IN: exact: \(exactTempo) prev: \(prevRoundedTempo) curr:\(currRoundedTempo)")
                }
                
                
            }
            
        }
    }
    
    //MARK: -
    //MARK: PRIVATE
    
    fileprivate func nanosecondConversion(forTime:UInt64) -> UInt64 {
        
        let kOneThousand:UInt64 = 1000
        
        var s_timebase_info = mach_timebase_info(numer: 0, denom: 0)
        let status = mach_timebase_info(&s_timebase_info)
        if status == KERN_SUCCESS {
            return ((forTime * UInt64(s_timebase_info.numer)) / (kOneThousand * UInt64(s_timebase_info.denom)))
        }
        
        return 0
    }

    
    
}
