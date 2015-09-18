//
//  DetailViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/20/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation
import CoreData
import KMPlaceholderTextView

// MARK: Protocol - DetailViewControllerDelegate

protocol DetailViewControllerDelegate : class {
    func didFinishViewController(detailViewController: DetailViewController, didSave: Bool)
}

// MARK: DetailViewController

class DetailViewController: UIViewController {
    
    // MARK: Property
    
    // Public Property
    var coreDataStack: CoreDataStack!
    var context: NSManagedObjectContext!
    var voice: Voice!
    var currentAudioPlayer: AVAudioPlayer?
    weak var delegate: DetailViewControllerDelegate?
    var directoryURL: NSURL!
    var voiceHasChanges: Bool {
        if isViewLoaded() && view.window != nil {
            if voice.filename != nil && context.hasChanges {
                return true
            }
        }
        return false
    }
    
    // Private Property
    
    @IBOutlet weak var tableView: UITableView!
    var dateLabel: UILabel!
    var subjectTextView: KMPlaceholderTextView!
    var recordButton: UIButton!
    var dateToggle = false
    var recordingHasUpdates = false
    var overlayTransitioningDelegate: KMOverlayTransitioningDelegate?
    
    lazy var dateFormatter: NSDateFormatter = {
        var formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        return formatter
        }()
    
    let tmpStoreURL = NSURL.fileURLWithPath(NSTemporaryDirectory()).URLByAppendingPathComponent("tmpVoice.caf")
    
    // MARK: Constants
    
    struct Constants {
        struct TableViewCell {
            static let subjectCellIdentifier = "Subject Cell"
            static let dateCellIdentifier = "Date Cell"
            static let datePickerCellIdentifier = "Date Picker Cell"
            static let audioCellIdentifier = "Audio Cell"
        }
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50.0
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWasShown:", name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillBeHidden:", name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleInterruption:", name: AVAudioSessionInterruptionNotification, object: AVAudioSession.sharedInstance())
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "audioObjectWillStart:", name: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "proximityStateDidChange:", name: UIDeviceProximityStateDidChangeNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        if playback.audioPlayer?.playing == true {
            playback.state = .Default(deactive: true)
        } else {
            playback.state = .Default(deactive: false)
        }
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVAudioSessionInterruptionNotification, object: AVAudioSession.sharedInstance())
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceProximityStateDidChangeNotification, object: nil)
    }
    
    // MARK: Notification
    
    func keyboardWasShown(notification: NSNotification) {
        let info = notification.userInfo
        var kbRect = info![UIKeyboardFrameEndUserInfoKey]!.CGRectValue
        kbRect = view.convertRect(kbRect, fromView: nil)
        
        var contentInsets = tableView.contentInset
        contentInsets.bottom = kbRect.size.height
        tableView.contentInset = contentInsets
        tableView.scrollIndicatorInsets = contentInsets
        
        var aRect = view.frame
        aRect.size.height -= kbRect.size.height
        if !CGRectContainsPoint(aRect, subjectTextView.frame.origin) {
            tableView.scrollRectToVisible(subjectTextView.frame, animated: true)
        }
    }
    
    func keyboardWillBeHidden(notification: NSNotification) {
        var contentInsets = tableView.contentInset
        contentInsets.bottom = 0.0
        tableView.contentInset = contentInsets
        tableView.scrollIndicatorInsets = contentInsets
    }
    
    func handleInterruption(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as! UInt
            if interruptionType == AVAudioSessionInterruptionType.Began.rawValue {
                if playback.audioPlayer?.playing == true {
                    playback.state = .Pause(deactive: true)
                }
            }
        }
    }
    
    func audioObjectWillStart(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let audioObject: AnyObject = userInfo[AudioSessionHelper.Constants.Notification.AudioObjectWillStart.UserInfo.AudioObjectKey] {
                if playback.audioPlayer != audioObject as? AVAudioPlayer && playback.audioPlayer?.playing == true {
                    playback.state = .Pause(deactive: false)
                }
            }
        }
    }
    
    func proximityStateDidChange(notification: NSNotification) {
        if playback.audioPlayer?.playing == true {
            if UIDevice.currentDevice().proximityState {
                AudioSessionHelper.setupSessionActive(true, catagory: AVAudioSessionCategoryPlayAndRecord)
            } else {
                AudioSessionHelper.setupSessionActive(true)
            }
        }
    }
    
    // MARK: Target Action
    
    @IBAction func unwindToDetailViewController(segue: UIStoryboardSegue) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func hideKeyboard(sender: UITapGestureRecognizer) {
        tableView.endEditing(true)
    }
    
    @IBAction func datePickerValueChanged(datePicker: UIDatePicker) {
        voice.date = datePicker.date
        dateLabel.text = dateFormatter.stringFromDate(datePicker.date)
    }
    
    @IBAction func progressSliderTapped(sender: UITapGestureRecognizer) {
        if let slider = sender.view as? UISlider {
            let point = sender.locationInView(slider)
            let percentage = Float(point.x / slider.bounds.width)
            let value = slider.minimumValue + percentage * (slider.maximumValue - slider.minimumValue)
            slider.value = value
            slider.sendActionsForControlEvents(.ValueChanged)
        }
    }
    
    @IBAction func progressSliderValueChanged(sender: UISlider) {
        if let audioPlayer = playback.audioPlayer {
            audioPlayer.currentTime = NSTimeInterval(sender.value) * audioPlayer.duration
        }
    }
    
    @IBAction func playAudioButtonTapped(sender: AnyObject) {
        if let player = playback.audioPlayer {
            if player.playing {
                playback.state = .Pause(deactive: true)
            } else {
                playback.state = .Play
            }
        } else {
            let url: NSURL = {
                if self.recordingHasUpdates {
                    return self.tmpStoreURL
                } else {
                    return self.directoryURL.URLByAppendingPathComponent(self.voice.filename!)
                }
                }()
            do {
                try playback.audioPlayer = AVAudioPlayer(contentsOfURL: url)
                playback.audioPlayer!.delegate = self
                playback.audioPlayer!.prepareToPlay()
                playback.state = .Play
            } catch {
                let alertController = UIAlertController(title: nil, message: "The audio file seems to be corrupted. Do you want to retake?", preferredStyle: .Alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { _ in
                    
                }
                alertController.addAction(cancelAction)
                
                let OKAction = UIAlertAction(title: "Retake", style: .Destructive) { _ in
                    self.performSegueWithIdentifier("Record", sender: self)
                }
                alertController.addAction(OKAction)
                
                presentViewController(alertController, animated: true, completion: nil)
            }
            
        }
    }
    
    @IBAction func saveVoiceButtonTapped(sender: AnyObject) {
        updateVoice()
        if voice.filename != nil {
            delegate?.didFinishViewController(self, didSave: true)
        } else {
            shakeRecordButton()
        }
    }
    
    // MARK: - Playback Control
    
    class KMPlayback {
        var playButton: UIButton!
        var progressSlider: UISlider!
        var audioPlayer: AVAudioPlayer?
        var timer: NSTimer?
        
        var state: KMPlaybackState = .Default(deactive: false) {
            didSet {
                state.changePlaybackState(self)
            }
        }
        
        @objc func updateprogressSliderValue() {
            if let player = audioPlayer {
                progressSlider.value = Float(player.currentTime / player.duration)
            }
        }
    }
    
    enum KMPlaybackState {
        case Play
        case Pause(deactive: Bool)
        case Finish
        case Default(deactive: Bool)
        
        func changePlaybackState(playback: KMPlayback) {
            switch self {
            case .Play:
                if let player = playback.audioPlayer {
                    AudioSessionHelper.postStartAudioNotificaion(player)
                    playback.timer?.invalidate()
                    playback.timer = NSTimer(
                        timeInterval: 0.1,
                        target: playback,
                        selector: "updateprogressSliderValue",
                        userInfo: nil,
                        repeats: true)
                    NSRunLoop.currentRunLoop().addTimer(playback.timer!, forMode: NSRunLoopCommonModes)
                    AudioSessionHelper.setupSessionActive(true)
                    if !player.playing {
                        player.currentTime = NSTimeInterval(playback.progressSlider.value) * player.duration
                        player.play()
                    }
                    UIDevice.currentDevice().proximityMonitoringEnabled = true
                    playback.playButton.setImage(UIImage(named: "Pause"), forState: .Normal)
                    playback.updateprogressSliderValue()
                }
            case .Pause(let deactive):
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer?.pause()
                UIDevice.currentDevice().proximityMonitoringEnabled = false
                if deactive {
                    AudioSessionHelper.setupSessionActive(false)
                }
                playback.playButton.setImage(UIImage(named: "Play"), forState: .Normal)
                playback.updateprogressSliderValue()
            case .Finish:
                playback.timer?.invalidate()
                playback.timer = nil
                UIDevice.currentDevice().proximityMonitoringEnabled = false
                AudioSessionHelper.setupSessionActive(false)
                playback.playButton.setImage(UIImage(named: "Play"), forState: .Normal)
                playback.progressSlider.value = 1.0
            case .Default(let deactive):
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer = nil
                UIDevice.currentDevice().proximityMonitoringEnabled = false
                if deactive {
                    AudioSessionHelper.setupSessionActive(false)
                }
                playback.playButton.setImage(UIImage(named: "Play"), forState: .Normal)
                playback.progressSlider.value = 0.0
            }
        }
    }
    
    lazy var playback = KMPlayback()
    
    //MARK: Other
    
    func generateVoiceFileName() -> String {
        return NSProcessInfo.processInfo().globallyUniqueString + ".caf"
    }
    
    func saveReocrding() {
        let storeURL: NSURL = {
            if let filename = self.voice.filename {
                return self.directoryURL.URLByAppendingPathComponent(filename)
            } else {
                let filename = self.generateVoiceFileName()
                self.voice.filename = filename
                return self.directoryURL.URLByAppendingPathComponent(filename)
            }
            }()
        _ = try? NSFileManager.defaultManager().removeItemAtURL(storeURL)
        _ = try? NSFileManager.defaultManager().moveItemAtURL(tmpStoreURL, toURL: storeURL)
    }
    
    func updateSubject(textView: KMPlaceholderTextView) {
        if !textView.text.isEmpty {
            voice.subject = textView.text
        } else {
            voice.subject = textView.placeholder
        }
    }
    
    func updateVoice() {
        updateSubject(subjectTextView)
        if recordingHasUpdates {
            saveReocrding()
        }
    }
    
    func shakeRecordButton() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.07
        animation.repeatCount = 4
        animation.autoreverses = true
        animation.fromValue = NSValue(CGPoint: CGPointMake(recordButton.center.x - 10, recordButton.center.y))
        animation.toValue = NSValue(CGPoint: CGPointMake(recordButton.center.x + 10, recordButton.center.y))
        recordButton.layer.addAnimation(animation, forKey: "position")
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "Record" {
            playback.state = .Default(deactive: false)
            
            let recordViewController = segue.destinationViewController as! RecordViewController
            recordViewController.configRecorderWithURL(tmpStoreURL, delegate: self)
            
            overlayTransitioningDelegate = KMOverlayTransitioningDelegate()
            transitioningDelegate = overlayTransitioningDelegate
            recordViewController.modalPresentationStyle = .Custom
            recordViewController.transitioningDelegate = overlayTransitioningDelegate
        }
    }
    
}

// MARK: - AVAudioRecorderDelegate

extension DetailViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            recordingHasUpdates = true
            playback.playButton.hidden = false
            playback.progressSlider.hidden = false
            recordButton.setTitle("", forState: .Normal)
            
            let asset = AVURLAsset(URL: recorder.url, options: nil)
            let duration = asset.duration
            let durationInSeconds = Int(ceil(CMTimeGetSeconds(duration)))
            voice.duration = durationInSeconds
        }
    }
    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder, error: NSError?) {
        assertionFailure("Encode Error occurred! Error: \(error)")
    }
    
}

// MARK: - AVAudioPlayerDelegate

extension DetailViewController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        playback.state = .Finish
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        assertionFailure("Decode Error occurred! Error: \(error)")
    }
    
}

// MARK: - UITableViewDelegate

extension DetailViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            if cell.reuseIdentifier == Constants.TableViewCell.dateCellIdentifier {
                toggleDatePickerForSelectedIndexPath(indexPath)
            } else {
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
        }
    }
    
    func toggleDatePickerForSelectedIndexPath(indexPath: NSIndexPath) {
        let indexPaths = [NSIndexPath(forRow: indexPath.row + 1, inSection: indexPath.section)]
        tableView.beginUpdates()
        if dateToggle {
            dateToggle = false
            dateLabel.textColor = UIColor.blackColor()
            tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        } else {
            dateToggle = true
            dateLabel.textColor = view.tintColor
            tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        tableView.endUpdates()
    }
    
}

// MARK: - UITableViewDataSource

extension DetailViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return dateToggle ? 2: 1
        case 2:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var resuseIdentifier = ""
        switch indexPath.section {
        case 0:
            resuseIdentifier = Constants.TableViewCell.subjectCellIdentifier
        case 1:
            if indexPath.row == 0 {
                resuseIdentifier = Constants.TableViewCell.dateCellIdentifier
            } else {
                resuseIdentifier = Constants.TableViewCell.datePickerCellIdentifier
            }
        case 2:
            resuseIdentifier = Constants.TableViewCell.audioCellIdentifier
        default:
            break
        }
        let cell = tableView.dequeueReusableCellWithIdentifier(resuseIdentifier, forIndexPath: indexPath)
        
        if let subheadlineTableViewCell = cell as? SubheadlineTableViewCell {
            subheadlineTableViewCell.updateFonts()
        }
        
        if let subjectCell = cell as? SubjectTableViewCell {
            subjectCell.subjectTextView.text = voice.subject
            subjectCell.subjectTextView.placeholder = dateFormatter.stringFromDate(voice.date)
            subjectCell.subjectTextView.textContainerInset = UIEdgeInsetsZero
            subjectTextView = subjectCell.subjectTextView
            
        } else if let dateCell = cell as? DateTableViewCell {
            dateCell.dateLabel.text = dateFormatter.stringFromDate(voice.date)
            self.dateLabel = dateCell.dateLabel
            
        } else if let audioCell = cell as? AudioTableViewCell {
            playback.playButton = audioCell.playButton
            playback.progressSlider = audioCell.progressSlider
            recordButton = audioCell.recordButton
            
            if voice.filename != nil || recordingHasUpdates {
                playback.playButton.hidden = false
                playback.progressSlider.hidden = false
                recordButton.setTitle("", forState: .Normal)
            } else {
                playback.playButton.hidden = true
                playback.progressSlider.hidden = true
                recordButton.setTitle(" Tap to record", forState: .Normal)
            }
            
            if let audioPlayer = currentAudioPlayer {
                playback.audioPlayer = audioPlayer
                audioPlayer.delegate = self
                playback.progressSlider.value = Float(audioPlayer.currentTime / audioPlayer.duration)
                if audioPlayer.playing {
                    playback.state = .Play
                } else {
                    playback.state = .Pause(deactive: true)
                }
                currentAudioPlayer = nil
            }
        }
        return cell
    }
    
}

// MARK: - UITextViewdDelegate

extension DetailViewController: UITextViewDelegate {
    
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        // Call resignFirstResponder when the user presses the Return key
        if text.rangeOfCharacterFromSet(NSCharacterSet.newlineCharacterSet()) != nil {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textViewDidChange(textView: UITextView) {
        let newHeight = textView.sizeThatFits(CGSizeMake(textView.bounds.size.width, CGFloat.max)).height
        if newHeight != textView.bounds.height {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        voice.subject = textView.text
    }
    
}

// MARK: - SubjectTableViewCell

class SubjectTableViewCell: SubheadlineTableViewCell {
    @IBOutlet weak var subjectTextView: KMPlaceholderTextView!
}

// MARK: - DateTableViewCell

class DateTableViewCell: SubheadlineTableViewCell {
    @IBOutlet weak var dateLabel: UILabel!
}

// MARK: - SubheadlineTableViewCell

class SubheadlineTableViewCell: UITableViewCell {
    
    func updateFonts()
    {
        for view in contentView.subviews{
            if let label = view as? UILabel {
                label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
            } else if let textField = view as? UITextField {
                textField.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
            } else if let textView = view as? UITextView {
                textView.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
            }
        }
    }
    
}

// MARK: - AudioTableViewCell

class AudioTableViewCell: UITableViewCell {
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
}
