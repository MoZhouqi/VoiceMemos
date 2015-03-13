//
//  SplitViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/20/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class SplitViewController: UISplitViewController {
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredDisplayMode = .AllVisible
        preferredPrimaryColumnWidthFraction = 0.5
        maximumPrimaryColumnWidth = 450
        delegate = self
    }
    
}

// MARK: - Split View Controller Delegate

extension SplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController!, ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool {
        if let recordViewController = (secondaryViewController as? UINavigationController)?.visibleViewController as? DetailViewController {
            return false
        }
        return true
    }
    
    func splitViewController(splitViewController: UISplitViewController, separateSecondaryViewControllerFromPrimaryViewController primaryViewController: UIViewController!) -> UIViewController? {
        if let vc = (primaryViewController as? UINavigationController)?.visibleViewController as? VoicesTableViewController {
            let viewController = storyboard?.instantiateViewControllerWithIdentifier("NoVoiceSelected") as UIViewController
            return viewController
        } else {
            return nil
        }
    }
    
}
