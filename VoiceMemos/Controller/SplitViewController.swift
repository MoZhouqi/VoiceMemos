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
        preferredDisplayMode = .allVisible
        preferredPrimaryColumnWidthFraction = 0.5
        maximumPrimaryColumnWidth = 450
        delegate = self
    }
    
}

// MARK: - Split View Controller Delegate

extension SplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        let recordViewController = (secondaryViewController as? UINavigationController)?.visibleViewController as? DetailViewController
        if recordViewController != nil {
            return false
        }
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        if (primaryViewController as? UINavigationController)?.visibleViewController as? VoicesTableViewController != nil {
            let viewController = storyboard?.instantiateViewController(withIdentifier: "NoVoiceSelected")
            return viewController
        } else {
            return nil
        }
    }
    
}
