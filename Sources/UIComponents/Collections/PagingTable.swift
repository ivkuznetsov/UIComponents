//
//  PagingTable.swift
//

import UIKit

open class PagingTable: Table {
    
    public let loader: PagingLoader
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: UITableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        loader = pagingDelegate.pagingLoader().init(scrollView: list,
                                                    delegate: pagingDelegate,
                                                    addRefreshControl: { list.refreshControl = $0 },
                                                    scrollOnRefreshing: {
            list.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.height)
            }, setFooterVisible: { visible, footerView in
                let offset = list.contentOffset
                list.tableFooterView = visible ? footerView : UIView()
                list.contentOffset = offset
        })
        super.init(list: list, delegate: pagingDelegate)
    }
    
    public convenience init(view: UIView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        self.init(list: type(of: self).createList(in: view), pagingDelegate: pagingDelegate)
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
