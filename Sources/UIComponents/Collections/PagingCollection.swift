//
//  PagingCollectionHelper.swift
//

import UIKit

open class PagingCollection: Collection {
    
    private weak var yConstraint: NSLayoutConstraint?
    
    open private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: CollectionView, pagingDelegate: CollectionDelegate & PagingLoaderDelegate) {
        super.init(list: list, delegate: pagingDelegate)
        
        let loaderType = pagingDelegate.pagingLoader()
        
        loader = loaderType.init(scrollView: list,
                                 delegate: pagingDelegate,
                                 addRefreshControl: { list.refreshControl = $0 },
                                 scrollOnRefreshing: { list.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.width) },
                                 setFooterVisible: { [weak self] visible, footerView in
                
                guard let wSelf = self else { return }
                
                var insets = wSelf.list.contentInset
                
                if visible {
                    if wSelf.yConstraint == nil {
                        wSelf.list.addSubview(footerView)
                            
                        footerView.translatesAutoresizingMaskIntoConstraints = false
                        wSelf.list.widthAnchor.constraint(equalTo: footerView.widthAnchor).isActive = true
                        footerView.heightAnchor.constraint(equalToConstant: footerView.height).isActive = true
                        wSelf.list.leftAnchor.constraint(equalTo: footerView.leftAnchor).isActive = true
                        wSelf.yConstraint = footerView.topAnchor.constraint(equalTo:  wSelf.list.topAnchor)
                        wSelf.yConstraint?.isActive = true
                    }
                    insets.bottom = footerView.frame.size.height
                } else {
                    footerView.removeFromSuperview()
                    insets.bottom = 0
                }
                wSelf.list.contentInset = insets
                wSelf.reloadFooterPosition()
        })
        list.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    public convenience init(view: UIView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.init(list: type(of: self).createList(in: view), pagingDelegate: pagingDelegate)
    }
    
    open func reloadFooterPosition() {
        let size = list.contentSize
        
        if let constraint = yConstraint {
            if constraint.constant != size.height {
                constraint.constant = size.height
                loader.footerLoadingView.superview?.layoutIfNeeded()
            }
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset", list.superview != nil {
            reloadFooterPosition()
        }
    }
    
    deinit {
        list.removeObserver(self, forKeyPath: "contentOffset")
    }
}

extension PagingCollection {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loader.endDecelerating()
        delegate?.scrollViewDidEndDecelerating?(scrollView)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loader.endDecelerating()
        }
        delegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
}
