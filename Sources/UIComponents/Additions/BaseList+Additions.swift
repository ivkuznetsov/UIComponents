//
//  BaseList.swift
//  
//
//  Created by Ilya Kuznetsov on 02/01/2023.
//

import Foundation
import SharedUIComponents

public extension ListContainer {
    
    static func make(emptyView: ((NoObjectsView)->())? = nil) -> Self {
        let list = self.init()
        let view = NoObjectsView.loadFromNib(bundle: Bundle.module)
        emptyView?(view)
        list.emptyState.attach(view)
        return list
    }
}

public extension ListTracker {
    
    static func make(refreshControl: Bool = true, emptyView: ((NoObjectsView)->())? = nil) -> Self {
        self.init(list: List.make(emptyView: emptyView), hasRefreshControl: refreshControl)
    }
}
