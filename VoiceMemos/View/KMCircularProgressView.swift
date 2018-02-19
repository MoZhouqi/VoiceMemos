//
//  KMCircularProgressView.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/21/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

@IBDesignable
open class KMCircularProgressView: UIView {
    
    @IBInspectable open var progress: CGFloat = 0.0 {
        didSet {
            progressLayer.strokeEnd = progress
        }
    }
    
    open var iconStyle: KMIconStyle = .empty {
        didSet {
            iconLayer.path = iconStyle.path(iconLayerBounds)
        }
    }
    
    @IBInspectable open var lineWidth: CGFloat = 3.0 {
        didSet {
            backgroundLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
        }
    }
    
    @IBInspectable open var backgroundLayerStrokeColor: UIColor = UIColor(white: 0.90, alpha: 1.0) {
        didSet {
            backgroundLayer.strokeColor = backgroundLayerStrokeColor.cgColor
        }
    }
    
    @IBInspectable open var iconLayerFrameRatio: CGFloat = 0.4 {
        didSet {
            iconLayer.frame = iconLayerFrame(iconLayerBounds, ratio: iconLayerFrameRatio)
            iconLayer.path = iconStyle.path(iconLayerBounds)
        }
    }
    
    open var iconLayerBounds: CGRect {
        return iconLayer.bounds
    }
    
    open func setProgress(_ progress: CGFloat, animated: Bool = true) {
        if animated {
            self.progress = progress
        } else {
            self.progress = progress
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progress
            animation.duration = 0.0
            progressLayer.add(animation, forKey: nil)
        }
    }
    
    public enum KMIconStyle {
        case play
        case pause
        case stop
        case empty
        case custom(UIBezierPath)
        
        func path(_ layerBounds: CGRect) -> CGPath {
            switch self {
            case .play:
                let path = UIBezierPath()
                path.move(to: CGPoint(x: layerBounds.width / 5, y: 0))
                path.addLine(to: CGPoint(x: layerBounds.width, y: layerBounds.height / 2))
                path.addLine(to: CGPoint(x: layerBounds.width / 5, y: layerBounds.height))
                path.close()
                return path.cgPath
            case .pause:
                let rect = CGRect(origin: CGPoint(x: layerBounds.width * 0.1, y: 0), size: CGSize(width: layerBounds.width * 0.2, height: layerBounds.height))
                let path = UIBezierPath(rect: rect)
                rect.offsetBy(dx: layerBounds.width * 0.6, dy: 0)
                
                path.append(UIBezierPath(rect: rect))
                return path.cgPath
            case .stop:
                let insetBounds = layerBounds.insetBy(dx: layerBounds.width / 6, dy: layerBounds.width / 6)
                let path = UIBezierPath(rect: insetBounds)
                return path.cgPath
            case .empty:
                return UIBezierPath().cgPath
            case .custom(let path):
                return path.cgPath
            }
        }
    }
    
    lazy var backgroundLayer: CAShapeLayer = {
        let backgroundLayer = CAShapeLayer()
        backgroundLayer.fillColor = nil
        backgroundLayer.lineWidth = self.lineWidth
        backgroundLayer.strokeColor = self.backgroundLayerStrokeColor.cgColor
        self.layer.addSublayer(backgroundLayer)
        
        return backgroundLayer
        }()
    
    lazy var progressLayer: CAShapeLayer = {
        let progressLayer = CAShapeLayer()
        progressLayer.fillColor = nil
        progressLayer.lineWidth = self.lineWidth
        progressLayer.strokeColor = self.tintColor.cgColor
        self.layer.insertSublayer(progressLayer, above: self.backgroundLayer)
        
        return progressLayer
        }()
    
    lazy var iconLayer: CAShapeLayer = {
        let iconLayer = CAShapeLayer()
        iconLayer.fillColor = self.tintColor.cgColor
        self.layer.addSublayer(iconLayer)
        
        return iconLayer
        }()
    
    func iconLayerFrame(_ rect: CGRect, ratio: CGFloat) -> CGRect {
        let insetRatio = (1 - ratio) / 2.0
        return rect.insetBy(dx: rect.width * insetRatio, dy: rect.height * insetRatio)
    }
    
    func getSquareLayerFrame(_ rect: CGRect) -> CGRect {
        if rect.width != rect.height {
            let width = min(rect.width, rect.height)
            
            let originX = (rect.width - width) / 2
            let originY = (rect.height - width) / 2
            
            return CGRect(x: originX, y: originY, width: width, height: width)
        }
        return rect
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        let squareRect = getSquareLayerFrame(layer.bounds)
        backgroundLayer.frame = squareRect
        progressLayer.frame = squareRect
        
        let innerRect = squareRect.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0)
        iconLayer.frame = iconLayerFrame(innerRect, ratio: iconLayerFrameRatio)
        
        let center = CGPoint(x: squareRect.width / 2.0, y: squareRect.height / 2.0)
        let path = UIBezierPath(arcCenter: center, radius: innerRect.width / 2.0, startAngle: CGFloat(-M_PI_2), endAngle: CGFloat(-M_PI_2 + 2.0 * M_PI), clockwise: true)
        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        iconLayer.path = iconStyle.path(iconLayerBounds)
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        iconStyle = .play
    }
    
}
