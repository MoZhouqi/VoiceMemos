//
//  BaseTableViewController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/23/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class BaseTableViewController: UITableViewController {
    
    // MARK: Constants
    
    struct Constants {
        struct Nib {
            static let name = "VoiceTableViewCell"
        }
        
        struct TableViewCell {
            static let identifier = "Cell"
        }
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100.0
        let nib = UINib(nibName: Constants.Nib.name, bundle: nil)
        tableView.registerNib(nib, forCellReuseIdentifier: Constants.TableViewCell.identifier)
    }
    
}
