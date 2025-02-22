//
//  HapticPulseBeacon.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation
import Combine

class HapticPulseBeacon: HapticBeacon {
    /// Haptic engine for rendering haptics for the physical UI at decision points
    private let engine = HapticEngine()
    
    /// Wand for tracking when the user is pointing their phone at the beacon's
    /// location so that corresponding haptics can be triggered appropriately
    private let wand = PreviewWand()
    
    /// Angular window over which the wand audio plays surrounding the bearing to the beacon
    private let audioWindow = 60.0
    
    /// ID for the beacon that plays ambient audio when the wand isn't pointed at a road
    private(set) var beacon: AudioPlayerIdentifier?
    
    private var beaconLocation: CLLocation
    
    private var isBeaconFocussed = false
    
    private var timerHeading: Heading?
    private var timerToken: AnyCancellable?
    
    private var phoneIsFlat: Bool = false
    private var deviceOrientationToken: AnyCancellable?
    
    private let includeAHaptics = false
    
    static var description: String {
        return String(describing: self)
    }
    
    required init(at: CLLocation) {
        beaconLocation = at
        wand.delegate = self
    }
    
    deinit {
        timerHeading = nil
        
        timerToken?.cancel()
        timerToken = nil
        
        deviceOrientationToken?.cancel()
        deviceOrientationToken = nil
    }
    
    func start() {
        guard let orientation = BeaconOrientation(beaconLocation) else {
            return
        }
        
        phoneIsFlat = DeviceMotionManager.shared.isFlat
        deviceOrientationToken = NotificationCenter.default.publisher(for: .phoneIsFlatChanged).sink { _ in
            self.phoneIsFlat = DeviceMotionManager.shared.isFlat
            
            if self.phoneIsFlat {
                self.playBeaconAudio()
            } else {
                self.stopBeaconAudio()
            }
        }
        
        // Create a target that spans the A+ and A regions but cuts off before B and Behind
        let target = WandTarget(orientation, window: includeAHaptics ? 110.0 : 30.0)
        let heading = AppContext.shared.geolocationManager.heading(orderedBy: [.device])
        
        wand.start(with: [target], heading: heading)
    }
    
    func stop() {
        // Stop feedback from the wand
        wand.stop()
        
        timerHeading = nil
        timerToken?.cancel()
        timerToken = nil
        
        deviceOrientationToken?.cancel()
        deviceOrientationToken = nil
        
        if let player = beacon {
            AppContext.shared.audioEngine.stop(player)
            beacon = nil
        }
    }
    
    private func playBeaconAudio () {
        guard let sound = BeaconSound(PreviewWandAsset.self, at: beaconLocation, isLocalized: false) else {
            return
        }
        
        beacon = AppContext.shared.audioEngine.play(sound, heading: AppContext.shared.geolocationManager.heading(orderedBy: [.device]))
    }
    
    private func stopBeaconAudio() {
        guard let id = beacon else {
            return
        }
        
        AppContext.shared.audioEngine.stop(id)
    }
    
    func wandDidStart(_ wand: Wand) {
        // Set up the ambient audio for the road finder
        let silentDistance = 15.0
        let maxDistance = audioWindow / 2 - silentDistance
        
        PreviewWandAsset.selector = { [weak self] input -> (PreviewWandAsset, PreviewWandAsset.Volume)? in
            if case .heading(let userHeading, _) = input {
                guard let `self` = self, let heading = userHeading else {
                    return (PreviewWandAsset.noTarget, 0.0)
                }
                
                guard self.isBeaconFocussed else {
                    return (PreviewWandAsset.noTarget, 0.0)
                }
                
                let distance = self.wand.angleFromCurrentTarget(heading) ?? 0.0
                let volume = distance < silentDistance ? 1.0 : 1.0 - max(min((distance - silentDistance) / maxDistance, 1.0), 0.0)
                
                return (PreviewWandAsset.noTarget, Float(volume))
            }
            
            return nil
        }
        
        if phoneIsFlat {
            playBeaconAudio()
        }
    }
    
    func wand(_ wand: Wand, didCrossThreshold target: Orientable) {
        guard phoneIsFlat else {
            return
        }
        
        // Always trigger the road haptics
        engine.trigger(for: .error)
        engine.prepare(for: .error)
    }
    
    func wand(_ wand: Wand, didGainFocus target: Orientable, isInitial: Bool) {
        isBeaconFocussed = true
        
        timerToken?.cancel()
        timerToken = nil
        
        if includeAHaptics {
            timerHeading = AppContext.shared.geolocationManager.heading(orderedBy: [.device])
            timerToken = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                guard self?.phoneIsFlat ?? false else {
                    return
                }
                
                guard let userHeading: CLLocationDirection = self?.timerHeading?.value else {
                    return
                }
                
                let angle = userHeading.add(degrees: -target.bearing)
                
                if angle >= 345 || angle <= 15 {
                    self?.engine.trigger(for: .impactHeavy)
                    self?.engine.prepare(for: .impactHeavy)
                } else if (angle >= 310 && angle <= 345) || (angle >= 15 && angle <= 50) {
                    self?.engine.trigger(for: .impactLight)
                    self?.engine.prepare(for: .impactLight)
                }
            }
        } else {
            // If we are only using A+ haptics, we don't need to worry about the device's heading
            // since it is already guaranteed to be in the A+ range
            timerToken = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                guard self?.phoneIsFlat ?? false else {
                    return
                }
                
                self?.engine.trigger(for: .impactHeavy)
                self?.engine.prepare(for: .impactHeavy)
            }
        }
    }
    
    func wand(_ wand: Wand, didLongFocus target: Orientable) {
        // No-op currently
    }
    
    func wand(_ wand: Wand, didLoseFocus target: Orientable) {
        isBeaconFocussed = false
        
        timerHeading = nil
        timerToken?.cancel()
        timerToken = nil
    }
}
