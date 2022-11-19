//
//  PagingTable.swift
//

#if os(iOS)

import UIKit

open class PagingTable: Table {
    
    open private(set) var loader: PagingLoader!
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    override func setup() {
        super.setup()
        
        guard let pagingDelegate = pagingDelegate else { return }
        
        let loaderType = pagingDelegate.pagingLoader()
        
        self.loader = loaderType.init(scrollView: table,
                                      delegate: pagingDelegate,
                                      addRefreshControl: { table.refreshControl = $0 },
                                      scrollOnRefreshing: { [weak self] in
                
                self?.table.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.height)
                
            }, setFooterVisible: { [weak self] (visible, footerView) in
                
                guard let wSelf = self else { return }
                
                let offset = wSelf.table.contentOffset
                wSelf.table.tableFooterView = visible ? footerView : UIView()
                wSelf.table.contentOffset = offset
        })
    }
    
    public init(table: UITableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        super.init(table: table, delegate: pagingDelegate)
    }
    
    public init(view: UIView, style: UITableView.Style = .plain, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        super.init(view: view, style: style, delegate: pagingDelegate)
    }
    
    public init(customAdd: (UITableView)->(), style: UITableView.Style = .plain, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        super.init(customAdd: customAdd, style: style, delegate: pagingDelegate)
    }
}

extension PagingTable {
    
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
