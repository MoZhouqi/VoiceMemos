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
    func didFinishViewController(_ detailViewController: DetailViewController, didSave: Bool)
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
    var directoryURL: URL!
    var voiceHasChanges: Bool {
        if isViewLoaded && view.window != nil {
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
    
    lazy var dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
        }()
    
    let tmpStoreURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tmpVoice.caf")
    
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.keyboardWasShown(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.keyboardWillBeHidden(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.audioObjectWillStart(_:)), name: NSNotification.Name(rawValue: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.proximityStateDidChange(_:)), name: NSNotification.Name.UIDeviceProximityStateDidChange, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if playback.audioPlayer?.isPlaying == true {
            playback.state = .default(deactive: true)
        } else {
            playback.state = .default(deactive: false)
        }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceProximityStateDidChange, object: nil)
    }
    
    // MARK: Notification
    
    func keyboardWasShown(_ notification: Notification) {
        let info = notification.userInfo
        var kbRect = (info![UIKeyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue
        kbRect = view.convert(kbRect!, from: nil)
        
        var contentInsets = tableView.contentInset
        contentInsets.bottom = (kbRect?.size.height)!
        tableView.contentInset = contentInsets
        tableView.scrollIndicatorInsets = contentInsets
        
        var aRect = view.frame
        aRect.size.height -= (kbRect?.size.height)!
        if !aRect.contains(subjectTextView.frame.origin) {
            tableView.scrollRectToVisible(subjectTextView.frame, animated: true)
        }
    }
    
    func keyboardWillBeHidden(_ notification: Notification) {
        var contentInsets = tableView.contentInset
        contentInsets.bottom = 0.0
        tableView.contentInset = contentInsets
        tableView.scrollIndicatorInsets = contentInsets
    }
    
    func handleInterruption(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as! UInt
            if interruptionType == AVAudioSessionInterruptionType.began.rawValue {
                if playback.audioPlayer?.isPlaying == true {
                    playback.state = .pause(deactive: true)
                }
            }
        }
    }
    
    func audioObjectWillStart(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let audioObject: AnyObject = userInfo[AudioSessionHelper.Constants.Notification.AudioObjectWillStart.UserInfo.AudioObjectKey] as AnyObject? {
                if playback.audioPlayer != audioObject as? AVAudioPlayer && playback.audioPlayer?.isPlaying == true {
                    playback.state = .pause(deactive: false)
                }
            }
        }
    }
    
    func proximityStateDidChange(_ notification: Notification) {
        if playback.audioPlayer?.isPlaying == true {
            if UIDevice.current.proximityState {
                AudioSessionHelper.setupSessionActive(true, catagory: AVAudioSessionCategoryPlayAndRecord)
            } else {
                AudioSessionHelper.setupSessionActive(true)
            }
        }
    }
    
    // MARK: Target Action
    
    @IBAction func unwindToDetailViewController(_ segue: UIStoryboardSegue) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func hideKeyboard(_ sender: UITapGestureRecognizer) {
        tableView.endEditing(true)
    }
    
    @IBAction func datePickerValueChanged(_ datePicker: UIDatePicker) {
        voice.date = datePicker.date
        dateLabel.text = dateFormatter.string(from: datePicker.date)
    }
    
    @IBAction func progressSliderTapped(_ sender: UITapGestureRecognizer) {
        if let slider = sender.view as? UISlider {
            let point = sender.location(in: slider)
            let percentage = Float(point.x / slider.bounds.width)
            let value = slider.minimumValue + percentage * (slider.maximumValue - slider.minimumValue)
            slider.value = value
            slider.sendActions(for: .valueChanged)
        }
    }
    
    @IBAction func progressSliderValueChanged(_ sender: UISlider) {
        if let audioPlayer = playback.audioPlayer {
            audioPlayer.currentTime = TimeInterval(sender.value) * audioPlayer.duration
        }
    }
    
    @IBAction func playAudioButtonTapped(_ sender: AnyObject) {
        if let player = playback.audioPlayer {
            if player.isPlaying {
                playback.state = .pause(deactive: true)
            } else {
                playback.state = .play
            }
        } else {
            let url: URL = {
                if self.recordingHasUpdates {
                    return self.tmpStoreURL
                } else {
                    return self.directoryURL.appendingPathComponent(self.voice.filename!)
                }
                }()
            do {
                try playback.audioPlayer = AVAudioPlayer(contentsOf: url)
                playback.audioPlayer!.delegate = self
                playback.audioPlayer!.prepareToPlay()
                playback.state = .play
            } catch {
                let alertController = UIAlertController(title: nil, message: "The audio file seems to be corrupted. Do you want to retake?", preferredStyle: .alert)
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    
                }
                alertController.addAction(cancelAction)
                
                let OKAction = UIAlertAction(title: "Retake", style: .destructive) { _ in
                    self.performSegue(withIdentifier: "Record", sender: self)
                }
                alertController.addAction(OKAction)
                
                present(alertController, animated: true, completion: nil)
            }
            
        }
    }
    
    @IBAction func saveVoiceButtonTapped(_ sender: AnyObject) {
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
        var timer: Timer?
        
        var state: KMPlaybackState = .default(deactive: false) {
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
        case play
        case pause(deactive: Bool)
        case finish
        case `default`(deactive: Bool)
        
        func changePlaybackState(_ playback: KMPlayback) {
            switch self {
            case .play:
                if let player = playback.audioPlayer {
                    AudioSessionHelper.postStartAudioNotificaion(player)
                    playback.timer?.invalidate()
                    playback.timer = Timer(
                        timeInterval: 0.1,
                        target: playback,
                        selector: #selector(KMPlayback.updateprogressSliderValue),
                        userInfo: nil,
                        repeats: true)
                    RunLoop.current.add(playback.timer!, forMode: RunLoopMode.commonModes)
                    AudioSessionHelper.setupSessionActive(true)
                    if !player.isPlaying {
                        player.currentTime = TimeInterval(playback.progressSlider.value) * player.duration
                        player.play()
                    }
                    UIDevice.current.isProximityMonitoringEnabled = true
                    playback.playButton.setImage(UIImage(named: "Pause"), for: UIControlState())
                    playback.updateprogressSliderValue()
                }
            case .pause(let deactive):
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer?.pause()
                UIDevice.current.isProximityMonitoringEnabled = false
                if deactive {
                    AudioSessionHelper.setupSessionActive(false)
                }
                playback.playButton.setImage(UIImage(named: "Play"), for: UIControlState())
                playback.updateprogressSliderValue()
            case .finish:
                playback.timer?.invalidate()
                playback.timer = nil
                UIDevice.current.isProximityMonitoringEnabled = false
                AudioSessionHelper.setupSessionActive(false)
                playback.playButton.setImage(UIImage(named: "Play"), for: UIControlState())
                playback.progressSlider.value = 1.0
            case .default(let deactive):
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer = nil
                UIDevice.current.isProximityMonitoringEnabled = false
                if deactive {
                    AudioSessionHelper.setupSessionActive(false)
                }
                playback.playButton.setImage(UIImage(named: "Play"), for: UIControlState())
                playback.progressSlider.value = 0.0
            }
        }
    }
    
    lazy var playback = KMPlayback()
    
    //MARK: Other
    
    func generateVoiceFileName() -> String {
        return ProcessInfo.processInfo.globallyUniqueString + ".caf"
    }
    
    func saveReocrding() {
        let storeURL: URL = {
            if let filename = self.voice.filename {
                return self.directoryURL.appendingPathComponent(filename)
            } else {
                let filename = self.generateVoiceFileName()
                self.voice.filename = filename
                return self.directoryURL.appendingPathComponent(filename)
            }
            }()
        _ = try? FileManager.default.removeItem(at: storeURL)
        _ = try? FileManager.default.moveItem(at: tmpStoreURL, to: storeURL)
    }
    
    func updateSubject(_ textView: KMPlaceholderTextView) {
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
        animation.fromValue = NSValue(cgPoint: CGPoint(x: recordButton.center.x - 10, y: recordButton.center.y))
        animation.toValue = NSValue(cgPoint: CGPoint(x: recordButton.center.x + 10, y: recordButton.center.y))
        recordButton.layer.add(animation, forKey: "position")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Record" {
            playback.state = .default(deactive: false)
            
            let recordViewController = segue.destination as! RecordViewController
            recordViewController.configRecorderWithURL(tmpStoreURL, delegate: self)
            
            overlayTransitioningDelegate = KMOverlayTransitioningDelegate()
            transitioningDelegate = overlayTransitioningDelegate
            recordViewController.modalPresentationStyle = .custom
            recordViewController.transitioningDelegate = overlayTransitioningDelegate
        }
    }
    
}

// MARK: - AVAudioRecorderDelegate

extension DetailViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            recordingHasUpdates = true
            playback.playButton.isHidden = false
            playback.progressSlider.isHidden = false
            recordButton.setTitle("", for: UIControlState())
            
            let asset = AVURLAsset(url: recorder.url, options: nil)
            let duration = asset.duration
            let durationInSeconds = Int(ceil(CMTimeGetSeconds(duration)))
            voice.duration = NSNumber(value: durationInSeconds)
        }
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        assertionFailure("Encode Error occurred! Error: \(error)")
    }
    
}

// MARK: - AVAudioPlayerDelegate

extension DetailViewController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playback.state = .finish
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        assertionFailure("Decode Error occurred! Error: \(error)")
    }
    
}

// MARK: - UITableViewDelegate

extension DetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            if cell.reuseIdentifier == Constants.TableViewCell.dateCellIdentifier {
                toggleDatePickerForSelectedIndexPath(indexPath)
            } else {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    func toggleDatePickerForSelectedIndexPath(_ indexPath: IndexPath) {
        let indexPaths = [IndexPath(row: indexPath.row + 1, section: indexPath.section)]
        tableView.beginUpdates()
        if dateToggle {
            dateToggle = false
            dateLabel.textColor = UIColor.black
            tableView.deleteRows(at: indexPaths, with: .automatic)
        } else {
            dateToggle = true
            dateLabel.textColor = view.tintColor
            tableView.insertRows(at: indexPaths, with: .automatic)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
    }
    
}

// MARK: - UITableViewDataSource

extension DetailViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: resuseIdentifier, for: indexPath)
        
        if let subheadlineTableViewCell = cell as? SubheadlineTableViewCell {
            subheadlineTableViewCell.updateFonts()
        }
        
        if let subjectCell = cell as? SubjectTableViewCell {
            subjectCell.subjectTextView.text = voice.subject
            subjectCell.subjectTextView.placeholder = dateFormatter.string(from: voice.date)
            subjectCell.subjectTextView.textContainerInset = UIEdgeInsets.zero
            subjectTextView = subjectCell.subjectTextView
            
        } else if let dateCell = cell as? DateTableViewCell {
            dateCell.dateLabel.text = dateFormatter.string(from: voice.date as Date)
            self.dateLabel = dateCell.dateLabel
            
        } else if let audioCell = cell as? AudioTableViewCell {
            playback.playButton = audioCell.playButton
            playback.progressSlider = audioCell.progressSlider
            recordButton = audioCell.recordButton
            
            if voice.filename != nil || recordingHasUpdates {
                playback.playButton.isHidden = false
                playback.progressSlider.isHidden = false
                recordButton.setTitle("", for: UIControlState())
            } else {
                playback.playButton.isHidden = true
                playback.progressSlider.isHidden = true
                recordButton.setTitle(" Tap to record", for: UIControlState())
            }
            
            if let audioPlayer = currentAudioPlayer {
                playback.audioPlayer = audioPlayer
                audioPlayer.delegate = self
                playback.progressSlider.value = Float(audioPlayer.currentTime / audioPlayer.duration)
                if audioPlayer.isPlaying {
                    playback.state = .play
                } else {
                    playback.state = .pause(deactive: true)
                }
                currentAudioPlayer = nil
            }
        }
        return cell
    }
    
}

// MARK: - UITextViewdDelegate

extension DetailViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Call resignFirstResponder when the user presses the Return key
        if text.rangeOfCharacter(from: CharacterSet.newlines) != nil {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let newHeight = textView.sizeThatFits(CGSize(width: textView.bounds.size.width, height: CGFloat.greatestFiniteMagnitude)).height
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
                label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
            } else if let textField = view as? UITextField {
                textField.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
            } else if let textView = view as? UITextView {
                textView.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.subheadline)
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
