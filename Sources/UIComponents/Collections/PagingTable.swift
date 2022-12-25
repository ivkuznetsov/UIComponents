//
//  PagingTable.swift
//

import UIKit
import CommonUtils

open class PagingTable: Table {
    
    public let loader: PagingLoader
    private weak var pagingDelegate: PagingLoaderDelegate? { delegate as? PagingLoaderDelegate }
    
    public init(list: UITableView, pagingDelegate: PagingLoaderDelegate & TableDelegate) {
        loader = pagingDelegate.pagingLoader().init(scrollView: list,
                                                    delegate: pagingDelegate,
                                                    setFooterVisible: { visible, footer in
                let offset = list.contentOffset
                list.tableFooterView = visible ? footer : UIView()
                list.contentOffset = offset
        })
        loader.footerLoadingView = FooterLoadingView.loadFromNib(bundle: Bundle.module)
        loader.scrollOnRefreshing = { list.contentOffset = CGPoint(x: 0, y: -$0.bounds.size.height) }
        loader.processPullToRefreshError = { _, error in
            if let vc = UIViewController.topViewController {
                Alert.present(message: error.localizedDescription, on: vc)
            }
        }
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
