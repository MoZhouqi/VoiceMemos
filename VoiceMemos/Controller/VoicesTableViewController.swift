//
//  VoicesTableViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/20/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation
import CoreData
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
fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


class VoicesTableViewController: BaseTableViewController, UISearchBarDelegate {
    
    // MARK: Property
    
    var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>!
    var searchController: UISearchController!
    var resultsTableController: VoiceSearchResultsController!
    var coreDataStack: CoreDataStack!
    weak var selectedVoice: DetailViewController?
    
    lazy var dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
        }()
    
    lazy var directoryURL: URL = {
        let doucumentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let _directoryURL = doucumentURL.appendingPathComponent("Voice")
        do {
            try FileManager.default.createDirectory(at: _directoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            assertionFailure("Error creating directory: \(error)")
        }
        return _directoryURL
        }()
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Voice")
        fetchRequest.fetchBatchSize = 20
        let keySort = NSSortDescriptor(key: "date", ascending: false)
        
        fetchRequest.sortDescriptors = [keySort]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: coreDataStack.context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            debugPrint("Error executing the fetch request: \(error)")
        }
        
        addSearchBar()
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(VoicesTableViewController.handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(VoicesTableViewController.audioObjectWillStart(_:)), name: NSNotification.Name(rawValue: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(VoicesTableViewController.proximityStateDidChange(_:)), name: NSNotification.Name.UIDeviceProximityStateDidChange, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceProximityStateDidChange, object: nil)
    }
    
    // MARK: Notification
    
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
    
    @IBAction func addVoiceButtonTapped(_ sender: AnyObject) {
        checkVocieHasChangesWithContinuationAction { [unowned self] in
            self.performSegue(withIdentifier: "Add Voice", sender: self)
        }
        
    }
    
    // MARK: Other
    
    func addSearchBar() {
        resultsTableController = VoiceSearchResultsController()
        
        resultsTableController.tableView.delegate = self
        resultsTableController.tableView.dataSource = self
        searchController = UISearchController(searchResultsController:
            resultsTableController)
        
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.sizeToFit()
        tableView.tableHeaderView = searchController.searchBar
        
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        
        definesPresentationContext = true
        
    }
    
    func checkVocieHasChangesWithContinuationAction(_ action: @escaping () -> Void) {
        if selectedVoice != nil && selectedVoice!.voiceHasChanges {
            let alertController = UIAlertController(title: nil, message: "The voice has not been saved, are you sure to continue?", preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                
            }
            alertController.addAction(cancelAction)
            
            let OKAction = UIAlertAction(title: "Continue", style: .default) { _ in
                action()
            }
            alertController.addAction(OKAction)
            
            present(alertController, animated: true, completion: nil)
        } else {
            action()
        }
    }
    
    func  voiceForRowAtIndexPath(_ indexPath: IndexPath, WithTableView tableView: UITableView) -> Voice {
        if tableView == self.tableView {
            return self.fetchedResultsController.object(at: indexPath) as! Voice
        } else {
            return self.resultsTableController.filteredVoices[indexPath.row]
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        setEditing(false, animated: true)
        
        if segue.identifier == "Add Voice" || segue.identifier == "Change Voice" {
            
            let detailViewController = (segue.destination as! UINavigationController).topViewController as! DetailViewController
            selectedVoice = detailViewController
            
            detailViewController.delegate = self
            detailViewController.directoryURL = directoryURL
            
            if let svc = splitViewController {
                detailViewController.navigationItem.leftBarButtonItem = svc.displayModeButtonItem
                detailViewController.navigationItem.leftItemsSupplementBackButton = true
            }
            
            let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            childContext.parent = coreDataStack.context
            detailViewController.context = childContext
            
            if segue.identifier == "Add Voice" {
                
                let voiceEntity = NSEntityDescription.entity(forEntityName: "Voice", in: childContext)
                let voice = Voice(entity: voiceEntity!, insertInto: childContext)
                voice.date = Date()
                voice.subject = ""
                detailViewController.voice = voice
                
                playback.state = .pause(deactive: true)
                
            } else if segue.identifier == "Change Voice" {
                
                let voice = sender as! Voice
                let childVoice = childContext.object(with: voice.objectID) as! Voice
                detailViewController.voice = childVoice
                
                if voice == playback.voice {
                    playback.audioPlayer?.delegate = nil
                    detailViewController.currentAudioPlayer = playback.audioPlayer
                    playback.state = .default(deactive: false)
                } else {
                    playback.state = .pause(deactive: true)
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if tableView == self.tableView {
            return fetchedResultsController.sections!.count
        } else {
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tableView {
            let sectionInfo = fetchedResultsController.sections![section]
            return sectionInfo.numberOfObjects
        } else {
            return resultsTableController.filteredVoices.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.TableViewCell.identifier) as! VoiceTableViewCell
        
        let voice = voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
        
        configureCell(cell, forVoice: voice)
        return cell
    }
    
    func configureCell(_ cell: VoiceTableViewCell, forVoice voice: Voice) {
        cell.updateFonts()
        
        cell.tableView = tableView
        cell.titleLabel.preferredMaxLayoutWidth = cell.maxLayoutWidth
        
        cell.titleLabel.text = voice.subject
        cell.dateLabel.text = dateFormatter.string(from: voice.date as Date)
        
        let duration = voice.duration.intValue
        let minutes = duration / 60
        let seconds = duration % 60
        cell.durationLabel.text = "\(minutes):" + String(format: "%02d", seconds)
        
        let playbackVocie = playback.voice
        if voice == playbackVocie {
            if playback.progressView.superview != cell.playbackProgressPlaceholderView {
                cell.playbackProgressPlaceholderView.addSubview(playback.progressView)
            }
        } else {
            if playback.progressView.superview == cell.playbackProgressPlaceholderView {
                playback.progressView.removeFromSuperview()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! VoiceTableViewCell
        let voice = voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
        
        changePlaybackStateForVoice(voice, cell: cell)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        checkVocieHasChangesWithContinuationAction { [unowned self] in
            let voice = self.voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
            self.performSegue(withIdentifier: "Change Voice", sender: voice)
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let voice = self.voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
        
        let deleteAction = UITableViewRowAction(style: .normal, title: "Delete") { action, index in
            if tableView == self.resultsTableController.tableView {
                self.resultsTableController.filteredVoices.remove(at: indexPath.row)
                self.resultsTableController.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            self.deleteVoiceInPersistentStore(voice)
        }
        
        let shareAction = UITableViewRowAction(style: .normal, title: "Share") { action, index in
            let audioPath = self.directoryURL.appendingPathComponent(voice.filename!)
            let activityViewController = UIActivityViewController(activityItems: [audioPath], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = tableView
            activityViewController.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
            self.present(activityViewController, animated: true, completion: nil)
        }
        
        deleteAction.backgroundColor = UIColor.red
        shareAction.backgroundColor = UIColor.blue
        
        return [deleteAction, shareAction]
    }
    
    // MARK: - Playback Control
    
    class KMPlayback {
        let progressView: KMCircularProgressView = KMCircularProgressView()
        var voice: Voice?
        var timer: Timer?
        var audioPlayer: AVAudioPlayer?
        var state: KMPlaybackState = .default(deactive: false) {
            didSet {
                state.changePlaybackState(self)
            }
        }
        
        @objc func updateProgress() {
            if let audioPlayer = audioPlayer {
                let progress = CGFloat(audioPlayer.currentTime / audioPlayer.duration)
                if progress < progressView.progress {
                    progressView.setProgress(progress, animated: false)
                } else {
                    progressView.progress = progress
                }
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
                        selector: #selector(KMPlayback.updateProgress),
                        userInfo: nil,
                        repeats: true)
                    RunLoop.current.add(playback.timer!, forMode: RunLoopMode.commonModes)
                    let currentTime = player.currentTime
                    player.currentTime = currentTime
                    AudioSessionHelper.setupSessionActive(true)
                    player.play()
                    UIDevice.current.isProximityMonitoringEnabled = true
                }
                playback.progressView.iconStyle = .pause
            case .pause(let deactive):
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer?.pause()
                UIDevice.current.isProximityMonitoringEnabled = false
                if deactive {
                    AudioSessionHelper.setupSessionActive(false)
                }
                playback.progressView.iconStyle = .play
            case .finish:
                playback.timer?.invalidate()
                playback.timer = nil
                UIDevice.current.isProximityMonitoringEnabled = false
                AudioSessionHelper.setupSessionActive(false)
                playback.progressView.progress = 1.0
                playback.progressView.iconStyle = .play
            case .default(let deactive):
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer = nil
                playback.voice = nil
                UIDevice.current.isProximityMonitoringEnabled = false
                if deactive {
                    AudioSessionHelper.setupSessionActive(false)
                }
                playback.progressView.removeFromSuperview()
                playback.progressView.setProgress(0.0, animated: false)
            }
        }
    }
    
    lazy var playback = KMPlayback()
    
    func changePlaybackStateForVoice(_ voice: Voice, cell: VoiceTableViewCell) {
        if voice == playback.voice {
            switch playback.state {
            case .play:
                playback.state = .pause(deactive: true)
            default:
                playback.state = .play
            }
        } else {
            let url = directoryURL.appendingPathComponent(voice.filename!)
            
            do {
                try playback.audioPlayer = AVAudioPlayer(contentsOf: url)
                playback.audioPlayer?.delegate = self
                let progressView = playback.progressView
                progressView.frame = cell.playbackProgressPlaceholderView.bounds
                progressView.setProgress(0.0, animated: false)
                cell.playbackProgressPlaceholderView.addSubview(progressView)
                playback.voice = voice
                playback.state = .play
            }
            catch let error as NSError {
                playback.state = .default(deactive: true)
                if error.code == 2003334207 {
                    let alertController = UIAlertController(title: nil, message: "The audio file seems to be corrupted. Do you want to delete this record?", preferredStyle: .alert)
                    
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        
                    }
                    alertController.addAction(cancelAction)
                    
                    let OKAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
                        self.deleteVoiceInPersistentStore(voice)
                    }
                    alertController.addAction(OKAction)
                    
                    present(alertController, animated: true, completion: nil)
                }
                
            }
        }
    }
    
    func deleteVoiceInPersistentStore(_ voice: Voice) {
        if voice == playback.voice {
            playback.state = .default(deactive: true)
        }
        
        let removeFileURL = directoryURL.appendingPathComponent(voice.filename!)
        _ = try? FileManager.default.removeItem(at: removeFileURL)
        coreDataStack.context.delete(voice)
        coreDataStack.saveContext()
    }
    
}

// MARK: Gesture Recognizer Delegate

extension VoicesTableViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        // Ignore interactive pop gesture when there is only one view controller on the navigation stack
        if navigationController?.viewControllers.count <= 1 {
            return false
        }
        return true
    }
    
}

// MARK: - DetailViewControllerDelegate

extension VoicesTableViewController: DetailViewControllerDelegate {
    
    func didFinishViewController(_ detailViewController: DetailViewController, didSave: Bool) {
        if didSave {
            let context = detailViewController.context
            context?.perform {
                if (context?.hasChanges)! {
                    do {
                        try context?.save()
                    }
                    catch {
                        debugPrint("Error saving: \(error)")
                        abort()
                    }
                }
                self.coreDataStack.saveContext()
            }
        }
        
        if let svc = splitViewController {
            if svc.isCollapsed {
                _ = navigationController?.popToViewController(self, animated: true)
            } else {
                performSegue(withIdentifier: "Show Detail NoViewSelected", sender: self)
            }
        }
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate

extension VoicesTableViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {
            switch type {
            case .insert:
                tableView.insertRows(at: [newIndexPath!], with: .automatic)
            case .delete:
                tableView.deleteRows(at: [indexPath!], with: .automatic)
            case .update:
                let cell = tableView.cellForRow(at: indexPath!) as! VoiceTableViewCell
                let voice = fetchedResultsController.object(at: indexPath!) as! Voice
                configureCell(cell, forVoice: voice)
            case .move:
                tableView.deleteRows(at: [indexPath!], with: .automatic)
                tableView.insertRows(at: [newIndexPath!], with: .automatic)
            }
            
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        updateSearchResults(for: searchController)
    }
    
}

// MARK: - AVAudioPlayerDelegate

extension VoicesTableViewController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playback.state = .finish
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        assertionFailure("Decode Error occurred! Error: \(error)")
    }
    
}

// MARK: - UISearchControllerDelegate

extension VoicesTableViewController: UISearchControllerDelegate {
    
    func willDismissSearchController(_ searchController: UISearchController) {
        tableView.reloadData()
    }
    
}

// MARK: - UISearchResultsUpdating

extension VoicesTableViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchResults = self.fetchedResultsController.fetchedObjects as! [Voice]
        
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let strippedString = searchController.searchBar.text?.trimmingCharacters(in: whitespaceCharacterSet) ?? ""
        let predicate = NSPredicate(format:
            "SELF.subject contains[c] %@", strippedString)
        
        let filteredResults = searchResults.filter { predicate.evaluate(with: $0) }
        
        let searchResultsController = searchController.searchResultsController as! VoiceSearchResultsController
        searchResultsController.filteredVoices = filteredResults
        searchResultsController.tableView.reloadData()
    }
    
}
