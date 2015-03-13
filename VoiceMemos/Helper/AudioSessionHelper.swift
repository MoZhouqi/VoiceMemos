//
//  AudioSessionHelper.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/24/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import AVFoundation

class AudioSessionHelper {
    
    struct Constants {
        struct Notification {
            struct AudioObjectWillStart {
                static let Name = "KMAudioObjectWillStartNotification"
                struct UserInfo {
                    static let AudioObjectKey = "KMAudioObjectWillStartNotificationAudioObjectKey"
                }
            }
        }
    }
    
    class func postStartAudioNotificaion(AudioObject: NSObject) {
        let userInfo = [Constants.Notification.AudioObjectWillStart.UserInfo.AudioObjectKey: AudioObject]
        NSNotificationCenter.defaultCenter().postNotificationName(Constants.Notification.AudioObjectWillStart.Name,
            object: nil,
            userInfo: userInfo)
    }
    
    class func setupSessionActive(active: Bool, catagory: String = AVAudioSessionCategoryPlayback) {
        let session = AVAudioSession.sharedInstance()
        var error: NSError?
        if active {
            if !session.setCategory(catagory, error: &error) {
                println("Could not set session category: \(error)")
            }
            if !session.setActive(true, error: &error) {
                println("Could not activate session: \(error)")
            }
        } else {
            if !session.setActive(false, withOptions: .OptionNotifyOthersOnDeactivation, error: &error) {
                println("Could not deactivate session: \(error)")
            }
        }
    }
}

