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

open class Table: StaticSetupObject {
    
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
    public var containerCellAttachType: UIView.AttachType = .constraints
    public var useEstimatedCellHeights = true {
        didSet { table.estimatedRowHeight = useEstimatedCellHeights ? 150 : 0 }
    }
    
    public var cacheCellHeights = false
    fileprivate var cachedHeights: [NSValue:CGFloat] = [:]
    public func clearHeightCache(_ object: AnyHashable) {
        cachedHeights[object.cachedHeightKey] = nil
    }
    
    private var deferredReload: Bool = false
    open var visible: Bool = true { // defer reload when view is not visible
        didSet {
            if visible && (visible != oldValue) && deferredReload {
                reloadVisibleCells()
            }
        }
    }
    
    public let table: UITableView
    public private(set) var objects: [AnyHashable] = []
    
    open lazy var noObjectsView = NoObjectsView.loadFromNib()
    
    weak var delegate: TableDelegate?
    
    public init(table: UITableView, delegate: TableDelegate) {
        self.table = table
        self.delegate = delegate
        super.init()
        
        table.delegate = self
        table.dataSource = self
        table.prefetchDataSource = delegate is TablePrefetch ? self : nil
        table.tableFooterView = UIView()
    }
    
    public convenience init(view: UIView, delegate: TableDelegate) {
        self.init(table: type(of: self).createTable(view: view), delegate: delegate)
    }
    
    static func createTable(view: UIView) -> UITableView {
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
    
    open func set(objects: [AnyHashable], animated: Bool) {
        guard let delegate = delegate else { return }
        
        // remove missed estimated heights
        var set = Set(cachedHeights.keys)
        objects.forEach { set.remove($0.cachedHeightKey) }
        set.forEach { cachedHeights[$0] = nil }
        
        table.reload(oldData: self.objects,
                     newData: objects,
                     deferred: { reloadVisibleCells() },
                     updateObjects: { self.objects = objects },
                     addAnimation: delegate.animationForAdding(table: self),
                     deleteAnimation: .fade,
                     animated: animated)
        
        if delegate.shouldShowNoData(objects: objects, table: self) {
            table.attach(noObjectsView, type: .safeArea)
        } else {
            noObjectsView.removeFromSuperview()
        }
    }
    
    public func scrollTo(object: AnyHashable, animated: Bool) {
        if let index = objects.firstIndex(of: object) {
            table.scrollToRow(at: IndexPath(row: index, section:0), at: .none, animated: animated)
        }
    }
    
    public func reloadVisibleCells() {
        if visible {
            deferredReload = false
            table.visibleCells.forEach {
                if let indexPath = table.indexPath(for: $0) {
                    let object = objects[indexPath.row]
                    
                    if object as? UIView == nil {
                        delegate?.createCell(object: object, table: self)?.fill($0)
                    }
                    $0.separatorHidden = indexPath.row == objects.count - 1 && table.tableFooterView != nil
                }
            }
        } else {
            deferredReload = true
        }
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) ? true : (delegate?.responds(to: aSelector) ?? false)
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        super.responds(to: aSelector) ? self : delegate
    }
    
    deinit {
        prefetchTokens.values.forEach { $0.cancel() }
        table.delegate = nil
        table.dataSource = nil
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
            let tableCell = table.createCell(for: ContainerTableCell.self, identifier: "\(object.hash)", source: .code)
            tableCell.attach(viewToAttach: object, type: containerCellAttachType)
            cell = tableCell
        } else {
            guard let createCell = delegate?.createCell(object: object, table: self) else {
                fatalError("Please specify cell for \(object)")
            }
            cell = table.createCell(for: createCell.type)
            createCell.fill(cell)
        }
        cell.width = tableView.width
        cell.layoutIfNeeded()
        cell.separatorHidden = (indexPath.row == objects.count - 1) && table.tableFooterView != nil
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var resultHeight = UITableView.automaticDimension
        let object = objects[indexPath.row]
        
        var height: CGFloat?
        
        if cacheCellHeights {
            height = cachedHeights[object.cachedHeightKey]
        }
        if height == nil {
            height = delegate?.cellHeight(object: object, original: resultHeight, table: self)
        }
        if let height = height, height > 0 {
            resultHeight = height
        }
        if cacheCellHeights {
            cachedHeights[object.cachedHeightKey] = resultHeight
        }
        return resultHeight
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
        } else if let value = cachedHeights[object.cachedHeightKey] {
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
            cachedHeights[objects[indexPath.row].cachedHeightKey] = cell.bounds.height
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
