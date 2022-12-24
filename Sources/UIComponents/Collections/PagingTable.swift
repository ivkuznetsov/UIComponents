//
//  PagingTable.swift
//

import UIKit

open class PagingTable: Table {
    
    public let loader: PagingLoader
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(table: UITableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        loader = pagingDelegate.pagingLoader().init(scrollView: table,
                                                    delegate: pagingDelegate,
                                                    addRefreshControl: { table.refreshControl = $0 },
                                                    scrollOnRefreshing: {
                table.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.height)
            }, setFooterVisible: { visible, footerView in
                let offset = table.contentOffset
                table.tableFooterView = visible ? footerView : UIView()
                table.contentOffset = offset
        })
        super.init(table: table, delegate: pagingDelegate)
    }
    
    public convenience init(view: UIView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.init(table: type(of: self).createTable(view: view), pagingDelegate: pagingDelegate)
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
