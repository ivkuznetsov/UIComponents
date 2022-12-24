//
//  PagingCollectionHelper.swift
//

import UIKit

open class PagingCollection: Collection {
    
    private weak var yConstraint: NSLayoutConstraint?
    
    open private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(collection: CollectionView, pagingDelegate: CollectionDelegate & PagingLoaderDelegate) {
        super.init(collection: collection, delegate: pagingDelegate)
        
        let loaderType = pagingDelegate.pagingLoader()
        
        loader = loaderType.init(scrollView: collection,
                                 delegate: pagingDelegate,
                                 addRefreshControl: { collection.refreshControl = $0 },
                                 scrollOnRefreshing: { collection.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.width) },
                                 setFooterVisible: { [weak self] visible, footerView in
                
                guard let wSelf = self else { return }
                
                var insets = wSelf.collection.contentInset
                
                if visible {
                    if wSelf.yConstraint == nil {
                        wSelf.collection.addSubview(footerView)
                            
                        footerView.translatesAutoresizingMaskIntoConstraints = false
                        wSelf.collection.widthAnchor.constraint(equalTo: footerView.widthAnchor).isActive = true
                        footerView.heightAnchor.constraint(equalToConstant: footerView.height).isActive = true
                        wSelf.collection.leftAnchor.constraint(equalTo: footerView.leftAnchor).isActive = true
                        wSelf.yConstraint = footerView.topAnchor.constraint(equalTo:  wSelf.collection.topAnchor)
                        wSelf.yConstraint?.isActive = true
                    }
                    insets.bottom = footerView.frame.size.height
                } else {
                    footerView.removeFromSuperview()
                    insets.bottom = 0
                }
                wSelf.collection.contentInset = insets
                wSelf.reloadFooterPosition()
        })
        collection.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    public convenience init(view: UIView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        self.init(collection: type(of: self).createCollectionView(view: view), pagingDelegate: pagingDelegate)
    }
    
    open func reloadFooterPosition() {
        let size = collection.contentSize
        
        if let constraint = yConstraint {
            if constraint.constant != size.height {
                constraint.constant = size.height
                loader.footerLoadingView.superview?.layoutIfNeeded()
            }
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset", collection.superview != nil {
            reloadFooterPosition()
        }
    }
    
    deinit {
        collection.removeObserver(self, forKeyPath: "contentOffset")
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
