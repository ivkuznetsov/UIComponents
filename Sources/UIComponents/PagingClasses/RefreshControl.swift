//
//  RefreshControl.swift
//

import UIKit

class RefreshControl: UIRefreshControl {
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window != nil && isRefreshing, let scrollView = superview as? UIScrollView {
            let offset = scrollView.contentOffset
            UIView.performWithoutAnimation {
                endRefreshing()
            }
            beginRefreshing()
            scrollView.contentOffset = offset
        }
    }
}
