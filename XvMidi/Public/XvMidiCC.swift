
//  XvMidiCC.swift
//  XvDataMapping
//
//  Created by Jason Snell on 8/12/20.
//  Copyright © 2020 Jason Snell. All rights reserved.
//

import Foundation


//takes a wave's relative value (0.0-1.0)
//scales it to a MIDI CC
//and sends it to the set channel

public class XvMidiCC {
    
    fileprivate let midi:XvMidi = XvMidi.sharedInstance
    
    fileprivate let channel:UInt8
    public var cc:UInt8 {
        get { return _cc }
    }
    fileprivate let _cc:UInt8
    fileprivate var currMidiValue:UInt8
    fileprivate let primaryScaler:XvScaler
    
    fileprivate let midiRangeAttn:XvAttenuator = XvAttenuator(min: 0, max: 127)
    
    fileprivate var modulationA:Double
    fileprivate var modulationB:Double
    fileprivate var modulationC:Double
    fileprivate let modulationScaler:XvScaler
    
    public init(channel:UInt8, cc:UInt8, min:UInt8, max:UInt8, modMin:Double = 0, modMax:Double = 0, initialValue:UInt8? = nil) {
        
        self.currMidiValue = 0
        self.modulationA = 0
        self.modulationB = 0
        self.modulationC = 0
        
        self.channel = channel
        self._cc = cc
        
        //scales the value coming in via the set func (custom range)
        primaryScaler = XvScaler(
            inputRange: [0.0, 1.0],
            outputRange: [
                Double(midiRangeAttn.attenuate(value: min)),
                Double(midiRangeAttn.attenuate(value: max))
            ]
        )
        
        //scales the values coming in via the modulation func (0-127)
        modulationScaler = XvScaler(
            inputRange: [0.0, 1.0],
            outputRange: [
                Double(midiRangeAttn.attenuate(value: modMin)),
                Double(midiRangeAttn.attenuate(value: modMax))
            ]
        )
        
        //set init value
        if (initialValue != nil) {
            currMidiValue = initialValue!
            midi.controlChange(channel: channel, controller: cc, value: currMidiValue)
        }
        
    }
    
    //incoming: 0-1 double from wave
    
    public var value:UInt8 {
        get { return currMidiValue }
    }
    
    //takes 0-1 double, converts it, and sets a midi value
    public func set(value:Double) {
        
        if (value.isInfinite || value.isNaN) { return }
        set(midiValue: _convertPrimaryValueToMidiValue(double: value))
    }
    
    //takes a simultaneous request from multiple sources
    public func average(values:[Double]) {
        set(midiValue: _convertPrimaryValueToMidiValue(double: values.reduce(0, +) / Double(values.count)))
    }
    
    public func sum(values:[Double]) {
        set(midiValue: _convertPrimaryValueToMidiValue(double: values.reduce(0, +)))
    }
    
    public func setToLowest(values:[Double]) {
        if let min:Double = values.min() { set(value: min) }
    }
    
    public func setToHighest(values:[Double]) {
        if let max:Double = values.max() { set(value: max) }
    }
    
    public func decrease(value:Double) {
        
        if (value.isInfinite || value.isNaN) { return }
        //convert double to midi value
        let midiValue:UInt8 = _convertPrimaryValueToMidiValue(double: value)
        
        //decreases the curr value if it's below it
        if (midiValue < currMidiValue) { set(midiValue: midiValue) }
    }
    
    public func increase(value:Double) {
        
        if (value.isInfinite || value.isNaN) { return }
        //convert double to midi value
        let midiValue:UInt8 = _convertPrimaryValueToMidiValue(double: value)
        
        //increases the curr value if it's above it
        if (midiValue > currMidiValue) { set(midiValue: midiValue) }
    }
    
    //set midiValue directly
    public func set(midiValue:UInt8) {
        
        //sum all the modulation changes
        let modulationsSum:Double = modulationA + modulationB + modulationC
        
        //add to midi value (as a double)
        var modulatedMidiDouble:Double = (Double(midiValue) + modulationsSum)
        
        //keep above zero
        if (modulatedMidiDouble < 0) { modulatedMidiDouble = 0 }
        if (modulatedMidiDouble > 127) { modulatedMidiDouble = 127 }
        
        //convert back to UInt8
        let modulatedMidiValue:UInt8 = UInt8(modulatedMidiDouble)
        
        //only send if the value is new
        if (modulatedMidiValue != currMidiValue) {
            
            //send into midi system
            midi.controlChange(channel: channel, controller: _cc, value: modulatedMidiValue)
           
            //update value for next round
            currMidiValue = modulatedMidiValue
        }
    }
    
    //during a program change, all the current midi values need to be pushed to the new pattern / program / kit
    public func didReceiveProgramChange(){
        
        //push the curr value out to the midi system
        midi.controlChange(channel: channel, controller: _cc, value: currMidiValue)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            midi.controlChange(channel: channel, controller: _cc, value: currMidiValue)
        }
    }
    
    //modulations
    
    //takes asynchronous request from up to 3 sources (A, B, C) besides the primary sources which use the set() func
    //example: alpha wave is setting the value, but a PPG LFO is modulating it
    public func setModulationA(withValue:Double) {
        modulationA = _convertModulationValueToMidiValue(double: withValue)
        set(midiValue: currMidiValue)
    }
    
    public func setModulationB(withValue:Double) {
        modulationB = _convertModulationValueToMidiValue(double: withValue)
        set(midiValue: currMidiValue)
    }
    
    public func setModulationC(withValue:Double) {
        modulationC = _convertModulationValueToMidiValue(double: withValue)
        set(midiValue: currMidiValue)
    }
    
    //takes a 0-1 double and converts it to 0-127 midi value
    //(or within the set range, like 40-64)
    fileprivate func _convertPrimaryValueToMidiValue(double:Double) -> UInt8 {
        
        //scale
        let scaledDouble:Double = primaryScaler.scale(value: double)
        
        //convert to UInt8
        return UInt8( midiRangeAttn.attenuate(value: scaledDouble) )
    }
    
    fileprivate func _convertModulationValueToMidiValue(double:Double) -> Double {
        
        //scale
        let scaledDouble:Double = modulationScaler.scale(value: double)
        
        //convert to UInt8
        return midiRangeAttn.attenuate(value: scaledDouble)
    }
    
    
}


//MARK: XvDataMapping objects as structs
struct XvScaleRange {
    
    var low:Double
    var high:Double
    var range:Double
    
    init (low:Double, high:Double) {
        self.low = low
        self.high = high
        self.range = high-low
    }
}

struct XvScaler {
    
    fileprivate var _inputRange:XvScaleRange
    fileprivate var _outputRange:XvScaleRange
    
    public init(inputRange:[Double] = [0, 1], outputRange:[Double] = [0,1]) {
        
        //error checking
        //make sure input and output range arrays are only 2 characters,
        if (inputRange.count != 2 || outputRange.count != 2) {
            print("XvMidiCC: XvScaler: Error: inputRange and outputRange each need 2 values for init")
            fatalError()
        }
        self._inputRange = XvScaleRange(low: inputRange[0], high: inputRange[1])
        self._outputRange = XvScaleRange(low: outputRange[0], high: outputRange[1])
    }
    
    public func scale(value:Double) -> Double {
        return ((_outputRange.range * value) / _inputRange.range) + _outputRange.low
    }
}

struct XvAttenuator {
    
    fileprivate var min:Double
    fileprivate var max:Double
    
    //MARK: - Init
    public init(min:Double, max:Double) {
        
        if (min >= max) {
            print("XvMidiCC: XvAttenuator: Error: min value", min, "must be less than max value", max)
            fatalError()
        }
        self.min = min
        self.max = max
    }
    
    public func attenuate(value:UInt8) -> UInt8 {
        return UInt8(attenuate(value: Double(value)))
    }
    
    public func attenuate(value:Double) -> Double {
        
        var newValue:Double = value
        if (newValue.isNaN || newValue.isInfinite) { newValue = 0 }
        newValue = Double(Int(newValue * 100000)) / 100000
        
        //attenuate
        if (newValue > max) {
            return max
        } else if (newValue < min) {
            return min
        } else {
            return newValue
        }
    }
}



