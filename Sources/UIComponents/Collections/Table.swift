//
//  Table.swift
//

import UIKit
import CommonUtils

public protocol TableDelegate: UITableViewDelegate {
    
    //fade by default
    func animationForAdding(table: Table) -> UITableView.RowAnimation
    
    //by default it becomes visible when objects array is empty
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool
    
    func action(object: AnyHashable, table: Table) -> Table.Result
    
    func createCell(object: AnyHashable, table: Table) -> UITableView.Cell?
    
    func cellHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat
    
    func cellEstimatedHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat
    
    func cellEditor(object: AnyHashable, table: Table) -> Table.Editor?
}

public extension TableDelegate {
    
    func animationForAdding(table: Table) -> UITableView.RowAnimation { .fade }
    
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool { objects.isEmpty }
    
    func action(object: AnyHashable, table: Table) -> Table.Result { .deselect }
    
    func createCell(object: AnyHashable, table: Table) -> UITableView.Cell? { nil }
    
    func cellHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat { UITableView.automaticDimension }
    
    func cellEstimatedHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat { 150 }
    
    func cellEditor(object: AnyHashable, table: Table) -> Table.Editor? { nil }
}

public protocol TablePrefetch {
    
    func prefetch(object: AnyHashable) -> Table.Cancel?
}

open class Table: BaseList<UITableView, TableDelegate, CGFloat, ContainerTableCell> {
    
    public typealias Result = SelectionResult
    
    public enum Editor {
        case delete(()->())
        case insert(()->())
        case actions(()->[UIContextualAction])
        
        fileprivate var style: UITableViewCell.EditingStyle {
            switch self {
                case .delete(_): return .delete
                case .insert(_): return .insert
                case .actions(_): return .none
            }
        }
    }
    
    public struct Cancel {
        let cancel: ()->()
        
        public init(_ cancel: @escaping ()->()) {
            self.cancel = cancel
        }
    }
    
    private var prefetchTokens: [IndexPath:Cancel] = [:]
    
    //options
    public var useEstimatedCellHeights = true {
        didSet { list.estimatedRowHeight = useEstimatedCellHeights ? 150 : 0 }
    }
    
    public override init(list: UITableView, delegate: TableDelegate) {
        super.init(list: list, delegate: delegate)
        
        noObjectsView = NoObjectsView.loadFromNib(bundle: Bundle.module)
        list.delegate = self
        list.dataSource = self
        list.prefetchDataSource = delegate is TablePrefetch ? self : nil
        list.tableFooterView = UIView()
    }
    
    open override class func createList(in view: PlatformView) -> UITableView {
        let table = UITableView(frame: CGRect.zero, style: .plain)
        table.backgroundColor = .clear
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 150
        
        table.subviews.forEach {
            if let view = $0 as? UIScrollView {
                view.delaysContentTouches = false
            }
        }
        view.attach(table)
        return table
    }
    
    public func scrollTo(object: AnyHashable, animated: Bool) {
        if let index = objects.firstIndex(of: object) {
            list.scrollToRow(at: IndexPath(row: index, section:0), at: .none, animated: animated)
        }
    }
    
    public override func reloadVisibleCells(excepting: Set<Int> = Set()) {
        list.visibleCells.forEach {
            if let indexPath = list.indexPath(for: $0), !excepting.contains(indexPath.item) {
                let object = objects[indexPath.row]
                
                if object as? UIView == nil {
                    delegate?.createCell(object: object, table: self)?.fill($0)
                }
                $0.separatorHidden = indexPath.row == objects.count - 1 && list.tableFooterView != nil
            }
        }
    }
    
    open override func shouldShowNoData(_ objects: [AnyHashable]) -> Bool {
        delegate?.shouldShowNoData(objects: objects, table: self) == true
    }
    
    open override func updateList(_ objects: [AnyHashable], animated: Bool, updateObjects: (Set<Int>) -> (), completion: @escaping () -> ()) {
        list.reload(oldData: self.objects,
                    newData: objects,
                    updateObjects: updateObjects,
                    addAnimation: delegate?.animationForAdding(table: self) ?? .fade,
                    deleteAnimation: .fade,
                    animated: animated)
    }
    
    deinit {
        prefetchTokens.values.forEach { $0.cancel() }
        list.delegate = nil
        list.dataSource = nil
    }
}

extension Table: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { objects.count }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = objects[indexPath.row]
        let cell: UITableViewCell
        
        if let object = object as? UITableViewCell {
            cell = object
        } else if let object = object as? UIView {
            let tableCell = list.createCell(for: ContainerTableCell.self, identifier: "\(object.hash)", source: .code)
            tableCell.attach(viewToAttach: object, type: .constraints)
            setupViewContainer?(tableCell)
            cell = tableCell
        } else {
            guard let createCell = delegate?.createCell(object: object, table: self) else {
                fatalError("Please specify cell for \(object)")
            }
            cell = list.createCell(for: createCell.type)
            createCell.fill(cell)
        }
        cell.width = tableView.width
        cell.layoutIfNeeded()
        cell.separatorHidden = (indexPath.row == objects.count - 1) && list.tableFooterView != nil
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let object = objects[indexPath.row]
        
        var height = cachedSize(for: object)
        
        if height == nil {
            height = delegate?.cellHeight(object: object, original: UITableView.automaticDimension, table: self)
            if height != UITableView.automaticDimension {
                cache(size: height, for: object)
            }
        }
        return height ?? UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if !useEstimatedCellHeights {
            return self.tableView(tableView, heightForRowAt: indexPath)
        }
        
        let object = objects[indexPath.row]
        if let cell = object as? UITableViewCell {
            return cell.bounds.height
        } else if let cell = object as? UIView {
            return cell.systemLayoutSizeFitting(CGSize(width: tableView.width,
                                                       height: CGFloat.greatestFiniteMagnitude)).height
        } else if let value = cachedSize(for: object) {
            return value
        } else if let value = delegate?.cellEstimatedHeight(object: object,
                                                            original: tableView.estimatedRowHeight,
                                                            table: self) {
            return value
        }
        return 150
    }
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let editor = delegate?.cellEditor(object: objects[indexPath.row], table: self) {
            return editor.style != .none
        }
        return false
    }
}

extension Table: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if delegate?.action(object: objects[indexPath.row], table: self) == .deselect {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if useEstimatedCellHeights, let indexPath = tableView.indexPath(for: cell) {
            cache(size: cell.bounds.height, for: objects[indexPath.row])
        }
        delegate?.tableView?(tableView, willDisplay: cell, forRowAt: indexPath)
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if let editor = delegate?.cellEditor(object: objects[indexPath.row], table: self) {
            switch editor {
            case .delete(let action): action()
            case .insert(let action): action()
            default: break
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        if let editor = delegate?.cellEditor(object: objects[indexPath.row], table: self),
           case .actions(let actions) = editor {
            
            let configuration = UISwipeActionsConfiguration(actions: actions())
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        delegate?.cellEditor(object: objects[indexPath.row], table: self)?.style ?? .none
    }
}

extension Table: UITableViewDataSourcePrefetching {
    
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if let delegate = delegate as? TablePrefetch {
            indexPaths.forEach {
                if let cancel = delegate.prefetch(object: objects[$0.row]) {
                    prefetchTokens[$0] = cancel
                }
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchTokens[$0]?.cancel()
            prefetchTokens[$0] = nil
        }
    }
}
