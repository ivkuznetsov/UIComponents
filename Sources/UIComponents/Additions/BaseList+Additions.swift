//
//  BaseList.swift
//  
//
//  Created by Ilya Kuznetsov on 02/01/2023.
//

import Foundation
import CommonUtils

public extension BaseList {
    
    convenience init(listView: View? = nil) {
        self.init(listView: listView, emptyStateView: NoObjectsView.loadFromNib(bundle: Bundle.module))
    }
}

public extension PagingCollection {
    
    convenience init(hasRefreshControl: Bool = true) {
        self.init(Collection(), hasRefreshControl: hasRefreshControl)
    }
}

public extension PagingTable {
    
    convenience init(hasRefreshControl: Bool = true) {
        self.init(Table(), hasRefreshControl: hasRefreshControl)
    }
}
