//
//  PagingCollectionHelper.swift
//

import UIKit
import CommonUtils

open class PagingCollection: Collection {
    
    private weak var yConstraint: NSLayoutConstraint?
    
    open private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: CollectionView, pagingDelegate: CollectionDelegate & PagingLoaderDelegate) {
        super.init(list: list, delegate: pagingDelegate)
        
        loader = pagingDelegate.pagingLoader().init(scrollView: list,
                                                    delegate: pagingDelegate,
                                                    setFooterVisible: { [weak self] visible, footer in
            guard let wSelf = self else { return }
            
            var insets = list.contentInset
            
            if visible {
                if wSelf.yConstraint == nil {
                    list.addSubview(footer)
                        
                    footer.translatesAutoresizingMaskIntoConstraints = false
                    list.widthAnchor.constraint(equalTo: footer.widthAnchor).isActive = true
                    footer.heightAnchor.constraint(equalToConstant: footer.height).isActive = true
                    list.leftAnchor.constraint(equalTo: footer.leftAnchor).isActive = true
                    wSelf.yConstraint = footer.topAnchor.constraint(equalTo:  list.topAnchor)
                    wSelf.yConstraint?.isActive = true
                }
                insets.bottom = footer.height
            } else {
                footer.removeFromSuperview()
                insets.bottom = 0
            }
            list.contentInset = insets
            wSelf.reloadFooterPosition()
        })
        loader.footerLoadingView = FooterLoadingView.loadFromNib(bundle: Bundle.module)
        loader.scrollOnRefreshing = { list.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.height) }
        loader.processPullToRefreshError = { _, error in
            if let vc = UIViewController.topViewController {
                Alert.present(message: error.localizedDescription, on: vc)
            }
        }
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
