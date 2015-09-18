//
//  RecordViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/24/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit
import AVFoundation

class RecordViewController: UIViewController {
    
    // MARK: Property
    
    var audioRecorder: AVAudioRecorder?
    var meterTimer: NSTimer?
    let recordDuration = 120.0
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var voiceRecordHUD: KMVoiceRecordHUD!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        voiceRecordHUD.update(0.0)
        voiceRecordHUD.fillColor = UIColor.greenColor()
        durationLabel.text = ""
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVAudioSessionInterruptionNotification, object: AVAudioSession.sharedInstance())
    }
    
    // MARK: Target Action
    
    @IBAction func finishRecord(sender: AnyObject) {
        meterTimer?.invalidate()
        meterTimer = nil
        voiceRecordHUD.update(0.0)
        if audioRecorder?.currentTime > 0 {
            audioRecorder?.stop()
            performSegueWithIdentifier("Update Recording", sender: self)
        } else {
            audioRecorder = nil
            performSegueWithIdentifier("Cancel Recording", sender: self)
        }
        AudioSessionHelper.setupSessionActive(false)
    }
    
    // MARK: Notification
    
    func handleInterruption(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as! UInt
            if interruptionType == AVAudioSessionInterruptionType.Began.rawValue {
                if audioRecorder?.recording == true {
                    audioRecorder?.pause()
                }
                meterTimer?.invalidate()
                meterTimer = nil
                voiceRecordHUD.update(0.0)
            } else if interruptionType == AVAudioSessionInterruptionType.Ended.rawValue {
                let alertController = UIAlertController(title: nil, message: "Do you want to continue the recording?", preferredStyle: .Alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { _ in
                    self.finishRecord(self)
                }
                alertController.addAction(cancelAction)
                
                let resumeAction = UIAlertAction(title: "Resume", style: .Default) { _ in
                    self.delay(0.8) {
                        if let recorder = self.audioRecorder {
                            recorder.record()
                            self.updateRecorderCurrentTimeAndMeters()
                            self.meterTimer = NSTimer.scheduledTimerWithTimeInterval(0.1,
                                target: self,
                                selector: "updateRecorderCurrentTimeAndMeters",
                                userInfo: nil,
                                repeats: true)
                            
                        }
                    }
                }
                alertController.addAction(resumeAction)
                
                presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: Other
    
    func delay(time: NSTimeInterval, block: () -> Void) {
        let time =  dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        dispatch_after(time, dispatch_get_main_queue(), block)
    }
    
    func updateRecorderCurrentTimeAndMeters() {
        if let recorder = audioRecorder {
            let currentTime = Int(recorder.currentTime)
            let timeLeft = Int(recordDuration) - currentTime
            if timeLeft > 10 {
                durationLabel.text = "\(currentTime)″"
            } else {
                voiceRecordHUD.fillColor = UIColor.redColor()
                durationLabel.text = "\(timeLeft) seconds left"
                if timeLeft == 0 {
                    durationLabel.text = "Time is up"
                    finishRecord(self)
                }
            }
            
            if recorder.recording {
                recorder.updateMeters()
                let ALPHA = 0.05
                let peakPower = pow(10, (ALPHA * Double(recorder.peakPowerForChannel(0))))
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
    
    func configRecorderWithURL(url: NSURL, delegate: AVAudioRecorderDelegate) {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        session.requestRecordPermission {granted in
            if granted {
                debugPrint("Recording permission has been granted")
                let recordSettings: [String : AnyObject]  = [
                    AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatLinearPCM),
                    AVSampleRateKey : 44100.0,
                    AVNumberOfChannelsKey : 2,
                    AVLinearPCMBitDepthKey : 16,
                    AVLinearPCMIsBigEndianKey : false,
                    AVLinearPCMIsFloatKey : false,
                ]
                self.audioRecorder = try? AVAudioRecorder(URL: url, settings: recordSettings)
                guard let recorder = self.audioRecorder else {
                    return
                }
                recorder.delegate = delegate
                recorder.meteringEnabled = true
                AudioSessionHelper.postStartAudioNotificaion(recorder)
                self.delay(0.8) {
                    AudioSessionHelper.setupSessionActive(true, catagory: AVAudioSessionCategoryRecord)
                    if recorder.prepareToRecord() {
                        recorder.recordForDuration(self.recordDuration)
                        debugPrint("Start recording")
                        
                        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleInterruption:", name: AVAudioSessionInterruptionNotification, object: AVAudioSession.sharedInstance())
                        
                        self.updateRecorderCurrentTimeAndMeters()
                        self.meterTimer = NSTimer.scheduledTimerWithTimeInterval(0.1,
                            target: self,
                            selector: "updateRecorderCurrentTimeAndMeters",
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
