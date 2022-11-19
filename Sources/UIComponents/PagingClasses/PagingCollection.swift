//
//  PagingCollectionHelper.swift
//

#if os(iOS)

import UIKit

open class PagingCollection: Collection {
    
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var yConstraint: NSLayoutConstraint?
    private var xConstraint: NSLayoutConstraint?
    
    open private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    override func setup() {
        super.setup()
        
        guard let pagingDelegate = pagingDelegate else { return }
        
        let loaderType = pagingDelegate.pagingLoader()
        
        loader = loaderType.init(scrollView: collection,
                                 delegate: pagingDelegate,
                                 addRefreshControl: { collection.refreshControl = $0 },
                                 scrollOnRefreshing: { [weak self] in
                
                guard let wSelf = self else { return }
                
                if wSelf.isVertical {
                    wSelf.collection.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.width)
                } else {
                    wSelf.collection.contentOffset = CGPoint(x: -$0.bounds.size.width, y: 0)
                }
            }, setFooterVisible: { [weak self] visible, footerView in
                
                guard let wSelf = self else { return }
                
                var insets = wSelf.collection.contentInset
                
                if visible {
                    wSelf.collection.addSubview(footerView)
                    if wSelf.isVertical {
                        
                        footerView.translatesAutoresizingMaskIntoConstraints = false
                        wSelf.widthConstraint = wSelf.collection.widthAnchor.constraint(equalTo: footerView.widthAnchor)
                        wSelf.widthConstraint?.isActive = true
                        
                        if wSelf.heightConstraint == nil {
                            wSelf.heightConstraint = footerView.heightAnchor.constraint(equalToConstant: footerView.height)
                            wSelf.heightConstraint?.isActive = true
                        }
                        
                        if wSelf.yConstraint == nil {
                            wSelf.yConstraint = footerView.topAnchor.constraint(equalTo:  wSelf.collection.topAnchor)
                            wSelf.yConstraint?.isActive = true
                        }
                        
                        if wSelf.xConstraint == nil {
                            wSelf.xConstraint = wSelf.collection.leftAnchor.constraint(equalTo: footerView.leftAnchor)
                            wSelf.xConstraint?.isActive = true
                        }
                        
                        insets.bottom = footerView.frame.size.height
                    } else {
                        insets.right = footerView.frame.size.width
                    }
                } else {
                    footerView.removeFromSuperview()
                    
                    if wSelf.isVertical {
                        insets.bottom = 0
                    } else {
                        insets.right = 0
                    }
                }
                wSelf.collection.contentInset = insets
                wSelf.reloadFooterPosition()
        })
        collection.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    open var isVertical: Bool { layout!.scrollDirection == .vertical }
    
    open func reloadFooterPosition() {
        let size = collection.contentSize
        
        if isVertical {
            if let constraint = yConstraint {
                if constraint.constant != size.height {
                    constraint.constant = size.height
                    loader.footerLoadingView.superview?.layoutIfNeeded()
                }
            }
        } else {
            loader.footerLoadingView.center = CGPoint(x: size.width + loader.footerLoadingView.frame.size.width / 2.0, y: size.height / 2.0)
        }
    }
    
    public init(collection: CollectionView, pagingDelegate: CollectionDelegate & PagingLoaderDelegate) {
        super.init(collection: collection, delegate: pagingDelegate)
    }
    
    public init(view: UIView, pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        super.init(view: view, delegate: pagingDelegate)
    }
    
    public init(customAdd: (CollectionView)->(), pagingDelegate: PagingLoaderDelegate & CollectionDelegate) {
        super.init(customAdd: customAdd, delegate: pagingDelegate)
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

#endif
