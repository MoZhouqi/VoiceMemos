//
//  KMVoiceRecordHUD.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/24/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

@IBDesignable
class KMVoiceRecordHUD: UIView {
    @IBInspectable var rate: CGFloat = 0.0
    
    @IBInspectable var fillColor: UIColor = UIColor.greenColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    var image: UIImage! {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        image = UIImage(named: "Mic")
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        image = UIImage(named: "Mic")
    }
    
    func update(rate: CGFloat) {
        self.rate = rate
        setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        CGContextTranslateCTM(context, 0, bounds.size.height)
        CGContextScaleCTM(context, 1, -1)
        
        CGContextDrawImage(context, bounds, image.CGImage)
        CGContextClipToMask(context, bounds, image.CGImage)
        
        CGContextSetFillColor(context, CGColorGetComponents(fillColor.CGColor))
        CGContextFillRect(context, CGRectMake(0, 0, bounds.width, bounds.height * rate))
    }
    
    override func prepareForInterfaceBuilder() {
        let bundle = NSBundle(forClass: self.dynamicType)
        image = UIImage(named: "Mic", inBundle: bundle, compatibleWithTraitCollection: self.traitCollection)
    }
}
