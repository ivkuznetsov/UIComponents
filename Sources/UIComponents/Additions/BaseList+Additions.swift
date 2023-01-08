//
//  BaseList.swift
//  
//
//  Created by Ilya Kuznetsov on 02/01/2023.
//

import Foundation
import SharedUIComponents

public extension BaseList {
    
    convenience init(listView: View? = nil) {
        self.init(listView: listView, emptyStateView: NoObjectsView.loadFromNib(bundle: Bundle.module))
    }
}

public extension ListTracker {
    
    convenience init(hasRefreshControl: Bool = true) {
        self.init(list: .init(emptyStateView: NoObjectsView.loadFromNib(bundle: Bundle.module)),
                  paging: Paging(),
                  hasRefreshControl: hasRefreshControl)
    }
}
