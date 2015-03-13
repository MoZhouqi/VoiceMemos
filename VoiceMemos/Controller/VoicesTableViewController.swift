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

class VoicesTableViewController: BaseTableViewController, UISearchBarDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Property
    
    var fetchedResultsController : NSFetchedResultsController!
    var searchController: UISearchController!
    var resultsTableController: VoiceSearchResultsController!
    var coreDataStack: CoreDataStack!
    weak var selectedVoice: DetailViewController?
    
    lazy var dateFormatter: NSDateFormatter = {
        var formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        return formatter
        }()
    
    lazy var directoryURL: NSURL = {
        var error: NSError?
        let doucumentURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
        
        let _directoryURL = doucumentURL.URLByAppendingPathComponent("Voice")
        
        NSFileManager.defaultManager().createDirectoryAtURL(_directoryURL, withIntermediateDirectories: true, attributes: nil, error: &error)
        
        assert(error == nil, "Error creating directory: \(error)")
        
        return _directoryURL
        }()
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let fetchRequest = NSFetchRequest(entityName: "Voice")
        fetchRequest.fetchBatchSize = 20
        let keySort = NSSortDescriptor(key: "date", ascending: false)
        
        fetchRequest.sortDescriptors = [keySort]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: coreDataStack.context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        fetchedResultsController.delegate = self
        
        var error: NSError? = nil
        if (!fetchedResultsController.performFetch(&error)) {
            println("Error executing the fetch request: \(error?.localizedDescription)")
        }
        
        addSearchBar()
        navigationController?.interactivePopGestureRecognizer.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleInterruption:", name: AVAudioSessionInterruptionNotification, object: AVAudioSession.sharedInstance())
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "audioObjectWillStart:", name: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "proximityStateDidChange:", name: UIDeviceProximityStateDidChangeNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVAudioSessionInterruptionNotification, object: AVAudioSession.sharedInstance())
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AudioSessionHelper.Constants.Notification.AudioObjectWillStart.Name, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceProximityStateDidChangeNotification, object: nil)
    }
    
    // MARK: Notification
    
    func handleInterruption(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let interruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as UInt
            if interruptionType == AVAudioSessionInterruptionType.Began.rawValue {
                if playback.audioPlayer?.playing == true {
                    playback.state = .Pause
                }
            }
        }
    }
    
    func audioObjectWillStart(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            if let audioObject: AnyObject = userInfo[AudioSessionHelper.Constants.Notification.AudioObjectWillStart.UserInfo.AudioObjectKey] {
                if playback.audioPlayer != audioObject as? AVAudioPlayer && playback.audioPlayer?.playing == true {
                    playback.state = .Pause
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
    
    @IBAction func addVoiceButtonTapped(sender: AnyObject) {
        checkVocieHasChangesWithContinuationAction { [unowned self] in
            self.performSegueWithIdentifier("Add Voice", sender: self)
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
    
    func checkVocieHasChangesWithContinuationAction(action: () -> Void) {
        if selectedVoice != nil && selectedVoice!.voiceHasChanges {
            let alertController = UIAlertController(title: nil, message: "The voice has not been saved, are you sure to continue?", preferredStyle: .Alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { _ in
                
            }
            alertController.addAction(cancelAction)
            
            let OKAction = UIAlertAction(title: "Continue", style: .Default) { _ in
                action()
            }
            alertController.addAction(OKAction)
            
            presentViewController(alertController, animated: true, completion: nil)
        } else {
            action()
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        func currentVoice() -> Bool {
            if segue.identifier == "Change Voice" {
                let voice = sender as Voice
                if voice == playback.voice {
                    return true
                }
            }
            return false
        }
        
        if currentVoice() {
            playback.state = .Default
        } else {
            playback.state = .Pause
        }
        
        if segue.identifier == "Add Voice" || segue.identifier == "Change Voice" {
            
            let detailViewController = segue.destinationViewController.topViewController as DetailViewController
            selectedVoice = detailViewController
            
            detailViewController.delegate = self
            detailViewController.directoryURL = directoryURL
            
            if let svc = splitViewController {
                detailViewController.navigationItem.leftBarButtonItem = svc.displayModeButtonItem()
                detailViewController.navigationItem.leftItemsSupplementBackButton = true
            }
            
            let childContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            childContext.parentContext = coreDataStack.context
            detailViewController.context = childContext
            
            if segue.identifier == "Add Voice" {
                
                let voiceEntity =
                NSEntityDescription.entityForName("Voice", inManagedObjectContext: childContext)
                let voice = Voice(entity: voiceEntity!, insertIntoManagedObjectContext: childContext)
                voice.date = NSDate()
                voice.subject = ""
                detailViewController.voice = voice
                
            } else if segue.identifier == "Change Voice" {
                let voice = sender as Voice
                
                let childVoice = childContext.objectWithID(voice.objectID) as Voice
                
                detailViewController.voice = childVoice
                
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        if tableView == self.tableView {
            return fetchedResultsController.sections!.count
        } else {
            return 1
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tableView {
            let sectionInfo = fetchedResultsController.sections![section]
                as NSFetchedResultsSectionInfo
            return sectionInfo.numberOfObjects
        } else {
            return resultsTableController.filteredVoices.count
        }
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch editingStyle {
        case .Delete:
            let voice = voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
            
            if tableView == resultsTableController.tableView {
                resultsTableController.filteredVoices.removeAtIndex(indexPath.row)
                resultsTableController.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }
            
            deleteVoiceInPersistentStore(voice)
            
        default:
            break
        }
    }
    
    // MARK: - Table view delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath) as VoiceTableViewCell
        let voice = voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
        
        changePlaybackStateForVoice(voice, cell: cell)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    func configureCell(cell: VoiceTableViewCell, forVoice voice: Voice) {
        cell.updateFonts()
        
        cell.tableView = tableView
        cell.titleLabel.preferredMaxLayoutWidth = cell.maxLayoutWidth
        
        cell.titleLabel.text = voice.subject
        cell.dateLabel.text = dateFormatter.stringFromDate(voice.date)
        
        let duration = voice.duration.integerValue
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
    
    func  voiceForRowAtIndexPath(indexPath: NSIndexPath, WithTableView tableView: UITableView) -> Voice {
        if tableView == self.tableView {
            return self.fetchedResultsController.objectAtIndexPath(indexPath) as Voice
        } else {
            return self.resultsTableController.filteredVoices[indexPath.row]
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(Constants.TableViewCell.identifier) as VoiceTableViewCell
        
        let voice = voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
        
        configureCell(cell, forVoice: voice)
        return cell
    }
    
    override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        checkVocieHasChangesWithContinuationAction { [unowned self] in
            let voice = self.voiceForRowAtIndexPath(indexPath, WithTableView: tableView)
            self.performSegueWithIdentifier("Change Voice", sender: voice)
        }
        
    }
    
    // MARK: - Playback Control
    
    class KMPlayback {
        let progressView: KMCircularProgressView = KMCircularProgressView()
        var voice: Voice?
        var timer: NSTimer?
        var audioPlayer: AVAudioPlayer?
        var state: KMPlaybackState = .Default {
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
        case Play
        case Pause
        case Finish
        case Default
        
        func changePlaybackState(playback: KMPlayback) {
            switch self {
            case .Play:
                if let player = playback.audioPlayer {
                    AudioSessionHelper.postStartAudioNotificaion(player)
                    playback.timer?.invalidate()
                    playback.timer = NSTimer(
                        timeInterval: 0.1,
                        target: playback,
                        selector: "updateProgress",
                        userInfo: nil,
                        repeats: true)
                    NSRunLoop.currentRunLoop().addTimer(playback.timer!, forMode: NSRunLoopCommonModes)
                    let currentTime = player.currentTime
                    player.currentTime = currentTime
                    AudioSessionHelper.setupSessionActive(true)
                    player.play()
                    UIDevice.currentDevice().proximityMonitoringEnabled = true
                }
                playback.progressView.iconStyle = .Pause
            case .Pause:
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer?.pause()
                UIDevice.currentDevice().proximityMonitoringEnabled = false
                AudioSessionHelper.setupSessionActive(false)
                playback.progressView.iconStyle = .Play
            case .Finish:
                playback.timer?.invalidate()
                playback.timer = nil
                UIDevice.currentDevice().proximityMonitoringEnabled = false
                AudioSessionHelper.setupSessionActive(false)
                playback.progressView.progress = 1.0
                playback.progressView.iconStyle = .Play
            case .Default:
                playback.timer?.invalidate()
                playback.timer = nil
                playback.audioPlayer = nil
                playback.voice = nil
                UIDevice.currentDevice().proximityMonitoringEnabled = false
                AudioSessionHelper.setupSessionActive(false)
                playback.progressView.removeFromSuperview()
                playback.progressView.setProgress(0.0, animated: false)
            }
        }
    }
    
    lazy var playback = KMPlayback()
    
    func changePlaybackStateForVoice(voice: Voice, cell: VoiceTableViewCell) {
        if voice == playback.voice {
            if playback.state == .Play {
                playback.state = .Pause
            } else {
                playback.state = .Play
            }
        } else {
            var error: NSError?
            let url = directoryURL.URLByAppendingPathComponent(voice.filename!)
            playback.audioPlayer = AVAudioPlayer(contentsOfURL: url, error: &error)
            playback.audioPlayer?.delegate = self
            
            if let err = error {
                playback.state = .Default
                
                if err.code == 2003334207 {
                    let alertController = UIAlertController(title: nil, message: "The audio file seems to be corrupted. Do you want to delete this record?", preferredStyle: .Alert)
                    
                    let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { _ in
                        
                    }
                    alertController.addAction(cancelAction)
                    
                    let OKAction = UIAlertAction(title: "Delete", style: .Destructive) { _ in
                        self.deleteVoiceInPersistentStore(voice)
                    }
                    alertController.addAction(OKAction)
                    
                    presentViewController(alertController, animated: true, completion: nil)
                }
            } else {
                let progressView = playback.progressView
                progressView.frame = cell.playbackProgressPlaceholderView.bounds
                progressView.setProgress(0.0, animated: false)
                cell.playbackProgressPlaceholderView.addSubview(progressView)
                playback.voice = voice
                playback.state = .Play
            }
        }
    }
    
    func deleteVoiceInPersistentStore(voice: Voice) {
        playback.state = .Default
        
        let removeFileURL = directoryURL.URLByAppendingPathComponent(voice.filename!)
        NSFileManager.defaultManager().removeItemAtURL(removeFileURL, error: nil)
        
        coreDataStack.context.deleteObject(voice)
        coreDataStack.saveContext()
    }
    
}

// MARK: - DetailViewControllerDelegate

extension VoicesTableViewController: DetailViewControllerDelegate {
    
    func didFinishViewController(detailViewController: DetailViewController, didSave: Bool) {
        if didSave {
            var error: NSError? = nil
            let context = detailViewController.context
            context.performBlock {
                if context.hasChanges && !context.save(&error) {
                    println("Error saving: \(error), \(error?.userInfo)")
                    abort()
                }
                
                self.coreDataStack.saveContext()
            }
        }
        
        if let svc = splitViewController {
            if svc.collapsed {
                navigationController?.popToViewController(self, animated: true)
            } else {
                performSegueWithIdentifier("Show Detail NoViewSelected", sender: self)
            }
        }
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate

extension VoicesTableViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath!,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath!) {
            switch type {
            case .Insert:
                tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
            case .Delete:
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            case .Update:
                let cell = tableView.cellForRowAtIndexPath(indexPath) as VoiceTableViewCell
                let voice = fetchedResultsController.objectAtIndexPath(indexPath) as Voice
                configureCell(cell, forVoice: voice)
            case .Move:
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
            default:
                break
            }
            
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
        updateSearchResultsForSearchController(searchController)
    }
    
}

// MARK: - AVAudioPlayerDelegate

extension VoicesTableViewController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        if flag {
            playback.state = .Finish
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
        assert(error == nil, "Decode Error occurred! Error: \(error)")
    }
    
}

// MARK: - UISearchControllerDelegate

extension VoicesTableViewController: UISearchControllerDelegate {
    
    func willDismissSearchController(searchController: UISearchController) {
        tableView.reloadData()
    }
    
}

// MARK: - UISearchResultsUpdating

extension VoicesTableViewController: UISearchResultsUpdating {
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let searchResults = self.fetchedResultsController.fetchedObjects as [Voice]
        
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let strippedString = searchController.searchBar.text.stringByTrimmingCharactersInSet(whitespaceCharacterSet)
        let predicate = NSPredicate(format:
            "SELF.subject contains[c] %@", strippedString)
        
        let filteredResults = searchResults.filter { predicate!.evaluateWithObject($0) }
        
        let searchResultsController = searchController.searchResultsController as VoiceSearchResultsController
        searchResultsController.filteredVoices = filteredResults
        searchResultsController.tableView.reloadData()
    }
    
}
