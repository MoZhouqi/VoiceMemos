//
//  NoVoiceSelectedViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/20/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class NoVoiceSelectedViewController: UIViewController {
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let svc = splitViewController {
            navigationItem.leftBarButtonItem = svc.displayModeButtonItem()
            navigationItem.leftItemsSupplementBackButton = true
        }
    }
    
}
