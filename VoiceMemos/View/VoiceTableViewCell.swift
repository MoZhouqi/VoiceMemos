//
//  VoiceTableViewCell.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/21/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class VoiceTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var playbackProgressPlaceholderView: UIView!
    
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint: NSLayoutConstraint!
    
    var tableView: UIView!
    //This seems to be a bug the preferredMaxLayoutWidth property of the UILabel is not automatically calculated correctly.
    //The workaround is to manually set the preferredMaxLayoutWidth on the label based on its actual width.
    //See https://github.com/MoZhouqi/iOS8SelfSizingCells for details.
    var maxLayoutWidth: CGFloat {
        let CellTrailingToContentViewTrailingConstant: CGFloat = 48.0
        
        // Minus the left/right padding for the label
        let maxLayoutWidth = CGRectGetWidth(tableView.frame) - leadingConstraint.constant - trailingConstraint.constant - CellTrailingToContentViewTrailingConstant
        return maxLayoutWidth
    }
    
    func updateFonts()
    {
        titleLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        dateLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        durationLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if tableView != nil {
            titleLabel.preferredMaxLayoutWidth = maxLayoutWidth
        }
    }
    
}
