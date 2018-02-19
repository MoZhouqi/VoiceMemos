//
//  KMOverlayPresentationController.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/26/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class KMOverlayPresentationController: UIPresentationController,
UIViewControllerTransitioningDelegate {
    
    let dimmingView: UIView = UIView()
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        dimmingView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        dimmingView.alpha = 0.0
    }
    
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        
        dimmingView.frame = containerView!.bounds
        dimmingView.alpha = 0.0
        
        containerView!.insertSubview(dimmingView, at: 0)
        
        presentingViewController.view.tintAdjustmentMode = .dimmed
        
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 1.0
                }, completion: nil)
        } else {
            self.dimmingView.alpha = 1.0
        }
    }
    
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        if let transitionCoordinator = presentedViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 0.0
                }, completion: { _ in
                    self.presentingViewController.view.tintAdjustmentMode = .automatic
            })
        } else {
            self.dimmingView.alpha = 0.0
            self.presentingViewController.view.tintAdjustmentMode = .automatic
        }
    }
    
    override var adaptivePresentationStyle : UIModalPresentationStyle {
        return .overFullScreen
    }
    
    override func containerViewWillLayoutSubviews() {
        dimmingView.frame = containerView!.bounds
        presentedView!.frame = frameOfPresentedViewInContainerView
    }
    
    override var shouldPresentInFullscreen : Bool {
        return false
    }
    
    override var frameOfPresentedViewInContainerView : CGRect {
        let containerBounds = containerView!.bounds
        var presentedViewFrame = CGRect.zero
        presentedViewFrame.size = CGSize(width: 200, height: 250)
        presentedViewFrame.origin = CGPoint(x: containerBounds.size.width / 2.0, y: containerBounds.size.height / 2.0)
        presentedViewFrame.origin.x -= presentedViewFrame.size.width / 2.0
        presentedViewFrame.origin.y -= presentedViewFrame.size.height / 2.0
        
        return presentedViewFrame
    }
    
}
