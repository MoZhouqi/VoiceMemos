//
//  RecordViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/24/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit
import AVFoundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class RecordViewController: UIViewController {
    
    // MARK: Property
    
    var audioRecorder: AVAudioRecorder?
    var meterTimer: Timer?
    let recordDuration = 120.0
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var voiceRecordHUD: KMVoiceRecordHUD!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        voiceRecordHUD.update(0.0)
        voiceRecordHUD.fillColor = UIColor.green
        durationLabel.text = ""
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
    }
    
    // MARK: Target Action
    
    @IBAction func finishRecord(_ sender: AnyObject) {
        meterTimer?.invalidate()
        meterTimer = nil
        voiceRecordHUD.update(0.0)
        if audioRecorder?.currentTime > 0 {
            audioRecorder?.stop()
            performSegue(withIdentifier: "Update Recording", sender: self)
        } else {
            audioRecorder = nil
            performSegue(withIdentifier: "Cancel Recording", sender: self)
        }
        AudioSessionHelper.setupSessionActive(false)
    }
    
    // MARK: Notification
    
    func handleInterruption(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as! UInt
            if interruptionType == AVAudioSessionInterruptionType.began.rawValue {
                if audioRecorder?.isRecording == true {
                    audioRecorder?.pause()
                }
                meterTimer?.invalidate()
                meterTimer = nil
                voiceRecordHUD.update(0.0)
            } else if interruptionType == AVAudioSessionInterruptionType.ended.rawValue {
                let alertController = UIAlertController(title: nil, message: "Do you want to continue the recording?", preferredStyle: .alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    self.finishRecord(self)
                }
                alertController.addAction(cancelAction)
                
                let resumeAction = UIAlertAction(title: "Resume", style: .default) { _ in
                    self.delay(0.8) {
                        if let recorder = self.audioRecorder {
                            recorder.record()
                            self.updateRecorderCurrentTimeAndMeters()
                            self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                target: self,
                                selector: #selector(RecordViewController.updateRecorderCurrentTimeAndMeters),
                                userInfo: nil,
                                repeats: true)
                            
                        }
                    }
                }
                alertController.addAction(resumeAction)
                
                present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: Other
    
    func delay(_ time: TimeInterval, block: @escaping () -> Void) {
        let time =  DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time, execute: block)
    }
    
    func updateRecorderCurrentTimeAndMeters() {
        if let recorder = audioRecorder {
            let currentTime = Int(recorder.currentTime)
            let timeLeft = Int(recordDuration) - currentTime
            if timeLeft > 10 {
                durationLabel.text = "\(currentTime)″"
            } else {
                voiceRecordHUD.fillColor = UIColor.red
                durationLabel.text = "\(timeLeft) seconds left"
                if timeLeft == 0 {
                    durationLabel.text = "Time is up"
                    finishRecord(self)
                }
            }
            
            if recorder.isRecording {
                recorder.updateMeters()
                let ALPHA = 0.05
                let peakPower = pow(10, (ALPHA * Double(recorder.peakPower(forChannel: 0))))
                var rate: Double = 0.0
                if (peakPower <= 0.2) {
                    rate = 0.2
                } else if (peakPower > 0.9) {
                    rate = 1.0
                } else {
                    rate = peakPower
                }
                voiceRecordHUD.update(CGFloat(rate))
            }
        }
    }
    
    func configRecorderWithURL(_ url: URL, delegate: AVAudioRecorderDelegate) {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        session.requestRecordPermission {granted in
            if granted {
                debugPrint("Recording permission has been granted")
                let recordSettings: [String : AnyObject]  = [
                    AVFormatIDKey : NSNumber(value: kAudioFormatLinearPCM as UInt32),
                    AVSampleRateKey : 44100.0 as AnyObject,
                    AVNumberOfChannelsKey : 2 as AnyObject,
                    AVLinearPCMBitDepthKey : 16 as AnyObject,
                    AVLinearPCMIsBigEndianKey : false as AnyObject,
                    AVLinearPCMIsFloatKey : false as AnyObject,
                ]
                self.audioRecorder = try? AVAudioRecorder(url: url, settings: recordSettings)
                guard let recorder = self.audioRecorder else {
                    return
                }
                recorder.delegate = delegate
                recorder.isMeteringEnabled = true
                AudioSessionHelper.postStartAudioNotificaion(recorder)
                self.delay(0.8) {
                    AudioSessionHelper.setupSessionActive(true, catagory: AVAudioSessionCategoryRecord)
                    if recorder.prepareToRecord() {
                        recorder.record(forDuration: self.recordDuration)
                        debugPrint("Start recording")
                        
                        NotificationCenter.default.addObserver(self, selector: #selector(RecordViewController.handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
                        
                        self.updateRecorderCurrentTimeAndMeters()
                        self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                            target: self,
                            selector: #selector(RecordViewController.updateRecorderCurrentTimeAndMeters),
                            userInfo: nil,
                            repeats: true)
                    }
                }
            } else {
                debugPrint("Recording permission has been denied")
            }
        }
    }
    
}
