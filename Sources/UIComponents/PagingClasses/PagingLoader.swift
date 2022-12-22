//
//  PagingLoader.swift
//

import UIKit
import CommonUtils

public protocol PagingLoaderDelegate: AnyObject {
    
    func hasRefreshControl() -> Bool
    
    func shouldLoadMore() -> Bool
    
    func pagingLoader() -> PagingLoader.Type
    
    func performOnRefresh()
    
    func reloadView(_ animated: Bool)
    
    func load(offset: Any?, completion: @escaping ([AnyHashable], Error?, _ offset: Any?)->())
}

public extension PagingLoaderDelegate {
    
    func hasRefreshControl() -> Bool { true }
    
    func shouldLoadMore() -> Bool { true }
    
    func pagingLoader() -> PagingLoader.Type { PagingLoader.self }
    
    func performOnRefresh() { }
}

public protocol PagingCachable: AnyObject {
 
    func saveFirstPageInCache(objects: [AnyHashable])
    
    func loadFirstPageFromCache() -> [AnyHashable]
}

open class PagingLoader: StaticSetupObject {
    
    open var processPullToRefreshError: (PagingLoader, Error)->()
    
    open private(set) var refreshControl: UIRefreshControl?
    open var footerLoadingInset = CGSize(width: 0, height: 0)
    
    open private(set) var footerLoadingView = FooterLoadingView.loadFromNib()
    open private(set) var loading = false
    open private(set) weak var scrollView: UIScrollView?
    
    open var fetchedItems: [AnyHashable] = []
    open var offset: Any?
    
    private var currentOperationId: String?
    public private(set) weak var delegate: PagingLoaderDelegate?
    private var performedLoading = false
    private var shouldEndRefreshing = false
    private var shouldBeginRefreshing = false
    private var scrollOnRefreshing: (UIRefreshControl)->()
    private var setFooterVisible: (Bool, UIView)->()
    
    public required init(scrollView: UIScrollView,
                         delegate: PagingLoaderDelegate,
                         addRefreshControl: (UIRefreshControl)->(),
                         scrollOnRefreshing: @escaping (UIRefreshControl)->(),
                         setFooterVisible: @escaping (_ visible: Bool, _ footer: UIView)->()) {
        self.scrollView = scrollView
        self.delegate = delegate
        self.scrollOnRefreshing = scrollOnRefreshing
        self.setFooterVisible = setFooterVisible
        
        processPullToRefreshError = { (_, error) in
            if let vc = UIViewController.topViewController {
                Alert.present(message: error.localizedDescription, on: vc)
            }
        }
        super.init()
        
        footerLoadingView.retry = { [weak self] in
            self?.loadMore()
        }
        
        if delegate.hasRefreshControl() {
            let refreshControl = RefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
            addRefreshControl(refreshControl)
            self.refreshControl = refreshControl
        }
        fetchedItems = (delegate as? PagingCachable)?.loadFirstPageFromCache() ?? []
        
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    public func set(fetchedItems: [AnyHashable], offset: Any?) {
        self.fetchedItems = fetchedItems
        self.offset = offset
        setFooterVisible(offset == nil ? false : true, footerLoadingView)
    }
    
    @objc private func refreshAction() {
        shouldBeginRefreshing = true
    }
    
    // manually reload starts from the first page, usualy you should run this method in viewDidLoad or viewWillAppear
    open func refreshFromBeginning(showRefresh: Bool) {
        if let refreshControl = refreshControl, showRefresh {
            DispatchQueue.main.async { [weak self] in
                self?.refresh(with: refreshControl)
            }
            scrollOnRefreshing(refreshControl)
        } else {
            refresh(with: nil)
        }
    }
    
    // load new page manually
    open func loadMore() {
        performedLoading = true
        footerLoadingView.state = .loading
        loading = true
        
        let operationId = UUID().uuidString
        currentOperationId = operationId
        
        delegate?.load(offset: offset, completion: { [weak self] (objects, error, newOffset) in
            guard let wSelf = self, wSelf.delegate != nil, wSelf.currentOperationId == operationId else { return }
            
            wSelf.loading = false
            if let error = error {
                wSelf.footerLoadingView.state = (error as? RunError) == .cancelled ? .stop : .failed
            } else {
                if objects.count > 0 && newOffset != nil {
                    wSelf.performedLoading = false
                }
                
                wSelf.offset = newOffset
                wSelf.append(items: objects, animated: false)
                
                if newOffset == nil {
                    UIView.animate(withDuration: objects.count > 0 ? 0 : 0.25, animations: {
                        wSelf.setFooterVisible(false, wSelf.footerLoadingView)
                    })
                }
                wSelf.footerLoadingView.state = .stop
                
                if wSelf.offset != nil {
                    DispatchQueue.main.async {
                        self?.loadModeIfNeeded()
                    }
                }
            }
        })
    }
    
    // append items to the end. customize adding items behaviour in subclass if needed
    open func append(items: [AnyHashable], animated: Bool) {
        var array = fetchedItems
        
        var set = Set(array)
        for object in items {
            if !set.contains(object) {
                set.insert(object)
                array.append(object)
            }
        }
        
        fetchedItems = array
        delegate?.reloadView(animated)
    }
    
    private func refresh(with refreshControl: UIRefreshControl?) {
        guard let delegate = delegate else { return }
        
        delegate.performOnRefresh()
        
        loading = true
        setFooterVisible(true, footerLoadingView)
        footerLoadingView.state = .stop
        
        if let refreshControl = refreshControl {
            if !refreshControl.isRefreshing {
                refreshControl.beginRefreshing()
                scrollOnRefreshing(refreshControl)
            }
        } else {
            if fetchedItems.isEmpty {
                footerLoadingView.state = .loading
            }
        }
        let operationId = UUID().uuidString
        currentOperationId = operationId
        
        delegate.load(offset: nil, completion: { [weak self] (objects, error, newOffset) in
            guard let wSelf = self, let delegate = wSelf.delegate, wSelf.currentOperationId == operationId else { return }
            
            wSelf.loading = false
            if let error = error {
                if error as? RunError == .cancelled {
                    wSelf.footerLoadingView.state = .stop
                } else {
                    wSelf.footerLoadingView.state = .failed
                    if refreshControl != nil {
                        wSelf.processPullToRefreshError(wSelf, error)
                    }
                    wSelf.delegate?.reloadView(false)
                }
            } else {
                wSelf.offset = newOffset
                if wSelf.offset == nil {
                    wSelf.setFooterVisible(false, wSelf.footerLoadingView)
                }
                let oldObjects = wSelf.fetchedItems
                wSelf.fetchedItems = []
                wSelf.append(items: objects, animated: oldObjects.count > 0)
                (delegate as? PagingCachable)?.saveFirstPageInCache(objects: objects)
                wSelf.footerLoadingView.state = .stop
                if wSelf.offset != nil {
                    DispatchQueue.main.async {
                        self?.loadModeIfNeeded()
                    }
                }
            }
            wSelf.endRefreshing()
        })
    }
    
    private func endRefreshing() {
        guard let refreshControl = refreshControl, let scrollView = scrollView else { return }
        
        if scrollView.isDecelerating || scrollView.isDragging {
            shouldEndRefreshing = true
        } else if scrollView.window != nil && refreshControl.isRefreshing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                refreshControl.endRefreshing()
            })
        } else {
            refreshControl.endRefreshing()
        }
    }
    
    open func validateFetchedItems(_ closure: (AnyHashable)->(Bool)) {
        fetchedItems = fetchedItems.compactMap { closure($0) ? $0 : nil }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if delegate != nil && keyPath == "contentOffset" {
            loadModeIfNeeded()
        }
    }
    
    private func loadModeIfNeeded() {
        guard delegate?.shouldLoadMore() == true else { return }

        if footerLoadingView.state == .failed && !isFooterVisible {
            footerLoadingView.state = .stop
        }
        
        if footerLoadingView.state != .failed &&
            footerLoadingView.state != .loading &&
            !performedLoading &&
            !loading &&
            isFooterVisible &&
            (refreshControl == nil || fetchedItems.count != 0) {
            
            loadMore()
        }
    }
    
    private var isFooterVisible: Bool {
        guard let scrollView = scrollView else { return false }
        
        scrollView.delegate?.scrollViewDidScroll?(scrollView)
        
        var frame = scrollView.convert(footerLoadingView.bounds, from: footerLoadingView)
        frame.origin.x -= footerLoadingInset.width
        frame.size.width += footerLoadingInset.width
        frame.origin.y -= footerLoadingInset.height
        frame.size.height += footerLoadingInset.height
        
        return footerLoadingView.isDescendant(of: scrollView) &&
            (scrollView.contentSize.height > scrollView.height ||
            scrollView.contentSize.width > scrollView.width ||
            scrollView.contentSize.height > 0) && scrollView.bounds.intersects(frame)
    }
    
    func endDecelerating() {
        performedLoading = false
        if shouldEndRefreshing && scrollView?.isDecelerating == false && scrollView?.isDragging == false {
            shouldEndRefreshing = false
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
        }
        if shouldBeginRefreshing {
            shouldBeginRefreshing = false
            refresh(with: refreshControl)
        }
    }
    
    deinit {
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
    }
}
