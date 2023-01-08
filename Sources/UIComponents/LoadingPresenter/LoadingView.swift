//
//  LoadingView.swift
//

import UIKit
import CommonUtils

open class LoadingView : UIView {
    
    @IBOutlet open var indicator: UIActivityIndicatorView!
    @IBOutlet open var progressIndicator: CircularProgressView?
    
    open var opaqueStyle: Bool = false {
        didSet { backgroundColor = backgroundColor?.withAlphaComponent(opaqueStyle ? 1.0 : 0.6) }
    }
    
    open func performLazyLoading(showBackground: Bool) {
        let color = backgroundColor
        indicator.alpha = 0
        progressIndicator?.alpha = 0
        
        if !showBackground {
            backgroundColor = .clear
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let wSelf = self else { return }
            
            if !showBackground {
                wSelf.backgroundColor = color
            }
            wSelf.addFadeTransition()
            wSelf.indicator.alpha = 1
            wSelf.progressIndicator?.alpha = 1
        }
    }
    
    open var progress: CGFloat = 0 {
        didSet {
            indicator.isHidden = progress > 0
            progressIndicator?.isHidden = progress == 0
            progressIndicator?.progress = progress
        }
    }
    
    open func present(in view: UIView, animated: Bool) {
        if superview == view { return }
        
        progress = 0
        view.attach(self)
        
        if animated {
            alpha = 0
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.alpha = 1
            })
        } else {
            alpha = 1
        }
    }
    
    open func hide(_ animated: Bool) {
        if superview == nil { return }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }, completion: { (_) in
                self.removeFromSuperview()
            })
        } else {
            removeFromSuperview()
        }
    }
}
