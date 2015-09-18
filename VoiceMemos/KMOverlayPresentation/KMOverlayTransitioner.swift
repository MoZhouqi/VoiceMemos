//
//  KMOverlayTransitioner.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/26/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class KMOverlayTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    func presentationControllerForPresentedViewController(presented: UIViewController, presentingViewController presenting: UIViewController, sourceViewController source: UIViewController) -> UIPresentationController? {
        
        return KMOverlayPresentationController(presentedViewController: presented, presentingViewController: presenting)
        
    }
    
    func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return KMOverlayAnimatedTransitioning(isPresentation: true)
    }
    
    func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return KMOverlayAnimatedTransitioning(isPresentation: false)
    }
    
}

class KMOverlayAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    
    let isPresentation: Bool
    
    init(isPresentation: Bool) {
        self.isPresentation = isPresentation
    }
    
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return 0.4
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        
        let fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)
        let fromView = fromViewController!.view
        let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)
        let toView = toViewController!.view
        
        let containerView = transitionContext.containerView()
        
        if isPresentation {
            containerView!.addSubview(toView)
        }
        
        let animatingViewController = isPresentation ? toViewController : fromViewController
        let animatingView = animatingViewController!.view
        
        let appearedFrame = transitionContext.finalFrameForViewController(animatingViewController!)
        var dismissedFrame = appearedFrame
        dismissedFrame.origin.y += dismissedFrame.size.height
        
        let initialFrame = isPresentation ? dismissedFrame : appearedFrame
        let finalFrame = isPresentation ? appearedFrame : dismissedFrame
        
        animatingView.frame = initialFrame
        
        if isPresentation {
            UIView.animateWithDuration(transitionDuration(transitionContext),
                delay: 0.0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 1.0,
                options: [.AllowUserInteraction, .BeginFromCurrentState],
                animations: {
                    animatingView.frame = finalFrame
                },
                completion: { _ in
                    transitionContext.completeTransition(true)
            })
        } else {
            UIView.animateWithDuration(transitionDuration(transitionContext),
                delay: 0.0,
                options: [.AllowUserInteraction, .BeginFromCurrentState],
                animations: {
                    animatingView.frame = finalFrame
                    animatingView.alpha = 0.0
                },
                completion: { _ in
                    fromView.removeFromSuperview()
                    transitionContext.completeTransition(true)
            })
            
        }
    }
    
}
