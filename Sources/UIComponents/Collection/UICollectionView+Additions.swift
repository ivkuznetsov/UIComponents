//
//  UICollectionView+Additions.swift
//

#if os(iOS)

import UIKit

extension UICollectionView {
    
    private func printDuplicates(_ array: [AnyHashable]) {
        var allSet = Set<AnyHashable>()
        
        array.forEach {
            if allSet.contains($0) {
                print("found duplicate object %@", $0.description)
            } else {
                allSet.insert($0)
            }
        }
    }
    
    func reload(animated: Bool, oldData: [AnyHashable], newData: [AnyHashable], diffable: Bool, completion: (()->())?, updateObjects: (()->())?) -> [IndexPath] {
        
        var applicationPresented = true
        var application: UIApplication?
        
        if Bundle.main.bundleURL.pathExtension != "appex" {
            application = (UIApplication.value(forKey: "sharedApplication") as! UIApplication)
            applicationPresented = application!.applicationState == .active
        }
        
        if (!animated && !diffable) || oldData.isEmpty || window == nil || !applicationPresented {
            updateObjects?()
            reloadData()
            layoutIfNeeded()
            completion?()
            return []
        }
        
        var toAdd: [IndexPath] = []
        var toDelete: [IndexPath] = []
        var toReload: [IndexPath] = []
        
        let oldDataSet = Set(oldData)
        let newDataSet = Set(newData)
        
        if oldDataSet.count != oldData.count { printDuplicates(oldData) }
        if newDataSet.count != newData.count { printDuplicates(newData) }
        
        let currentSet = NSMutableOrderedSet(array: oldData)
        for (index, object) in oldData.enumerated() {
            if !newDataSet.contains(object) {
                toDelete.append(IndexPath(item: index, section: 0))
                currentSet.remove(object)
            }
        }
        for (index, object) in newData.enumerated() {
            if !oldDataSet.contains(object) {
                toAdd.append(IndexPath(item: index, section: 0))
                currentSet.insert(object, at: index)
            } else {
                toReload.append(IndexPath(item: index, section: 0))
            }
        }
        
        var itemsToMove: [(from: IndexPath, to: IndexPath)] = []
        for (index, object) in newData.enumerated() {
            let oldDataIndex = currentSet.index(of: object)
            if index != oldDataIndex {
                itemsToMove.append((from: IndexPath(item: oldData.firstIndex(of: object)!, section: 0), to: IndexPath(item: index, section: 0)))
            }
        }
        
        if toDelete.count > 0 || toAdd.count > 0 || itemsToMove.count > 0 || toReload.count > 0 {
            
            application?.value(forKey: "beginIgnoringInteractionEvents")
            
            let performChanges = {
                self.performBatchUpdates {
                    updateObjects?()
                    
                    self.deleteItems(at: toDelete)
                    self.insertItems(at: toAdd)
                    
                    itemsToMove.forEach { self.moveItem(at: $0, to: $1) }
                    
                    let visibleItems = self.indexPathsForVisibleItems
                    
                    if visibleItems.count > 0 {
                        let toAddSet = Set(toAdd)
                        
                        visibleItems.forEach {
                            if let cell = self.cellForItem(at: $0) {
                                if toAddSet.contains($0) {
                                    cell.superview?.sendSubviewToBack(cell)
                                } else {
                                    cell.superview?.bringSubviewToFront(cell)
                                }
                            }
                        }
                    }
                    
                } completion: { _ in
                    application?.value(forKey: "endIgnoringInteractionEvents")
                    completion?()
                }
            }
            
            if animated {
                performChanges()
            } else {
                UIView.performWithoutAnimation(performChanges)
            }

            if collectionViewLayout.collectionViewContentSize.height < bounds.size.height && newData.count > 0 {
                UIView.animate(withDuration: animated ? 0.3 : 0) { [weak self] in
                    self?.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
                }
            }
        } else {
            updateObjects?()
            completion?()
        }
        return toReload
    }
}

#endif
