//
//  KMOverlayTransitioner.swift
//  VoiceMemos
//
//  Created by Zhouqi Mo on 2/26/15.
//  Copyright (c) 2015 Zhouqi Mo. All rights reserved.
//

import UIKit

class KMOverlayTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        
        return KMOverlayPresentationController(presentedViewController: presented, presenting: presenting)        
        
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return KMOverlayAnimatedTransitioning(isPresentation: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return KMOverlayAnimatedTransitioning(isPresentation: false)
    }
    
}

class KMOverlayAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    
    let isPresentation: Bool
    
    init(isPresentation: Bool) {
        self.isPresentation = isPresentation
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
        let fromView = fromViewController!.view
        let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
        let toView = toViewController!.view
        
        let containerView = transitionContext.containerView
        
        if isPresentation {
            containerView.addSubview(toView!)
        }
        
        let animatingViewController = isPresentation ? toViewController : fromViewController
        let animatingView = animatingViewController!.view
        
        let appearedFrame = transitionContext.finalFrame(for: animatingViewController!)
        var dismissedFrame = appearedFrame
        dismissedFrame.origin.y += dismissedFrame.size.height
        
        let initialFrame = isPresentation ? dismissedFrame : appearedFrame
        let finalFrame = isPresentation ? appearedFrame : dismissedFrame
        
        animatingView?.frame = initialFrame
        
        if isPresentation {
            UIView.animate(withDuration: transitionDuration(using: transitionContext),
                delay: 0.0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 1.0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: {
                    animatingView?.frame = finalFrame
                },
                completion: { _ in
                    transitionContext.completeTransition(true)
            })
        } else {
            UIView.animate(withDuration: transitionDuration(using: transitionContext),
                delay: 0.0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: {
                    animatingView?.frame = finalFrame
                    animatingView?.alpha = 0.0
                },
                completion: { _ in
                    fromView?.removeFromSuperview()
                    transitionContext.completeTransition(true)
            })
            
        }
    }
    
}
