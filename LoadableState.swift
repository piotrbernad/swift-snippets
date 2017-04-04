import Foundation
import Gloss

public protocol CollectionItemType: Glossy, SortableItemType { }

public protocol SortableItemType {
    var sortingKey: String { get }
}

public enum LoadableState<ItemType> {
    case idle
    case loading
    case loaded(items: [ItemType])
    case refreshing(items: [ItemType])
    case filtered(items: [ItemType], allItems: [ItemType])
    case filteredAllOut(allItems: [ItemType])
    case contentUnavailable
    case error(error: Error)
    
    public func items() -> [ItemType]? {
        switch self {
        case .loaded(let items):
            return items
        case .refreshing(let items):
            return items
        case .filtered(let items, _):
            return items
        default:
            return nil
        }
    }
    
    public func allItems() -> [ItemType]? {
        switch self {
        case .loaded(let items):
            return items
        case .refreshing(let items):
            return items
        case .filtered(_, let allItems):
            return allItems
        case .filteredAllOut(let allItems):
            return allItems
        default:
            return nil
        }
    }
    
    public var allItemsCount: Int {
        return self.allItems()?.count ?? 0
    }
    
    
}

public extension LoadableState where ItemType: SortableItemType {
    public func sectionatedItems() -> [String: [ItemType]]? {
        guard let items = self.items() else { return [:] }
        
        let results: [String: [ItemType]] = items.categorise { $0.sortingKey }
        
        return results
    }
    
    public var sectionatedItemsSectionCount: Int {
        return self.sectionatedItems()?.keys.count ?? 0
    }
    
    public func sectionatedItemsCountInSection(section: Int) -> Int {
        return sectionatedItemsForSection(section: section).count
    }
    
    public func sectionatedItemsForSection(section: Int) -> [ItemType] {
        guard let allItems = self.sectionatedItems() else { return [] }
        
        let sortedKeys = allItems.keys.sorted { (lhs, rhs) -> Bool in
            return lhs < rhs
        }
        
        let key = Array(sortedKeys)[section]
        
        return allItems[key] ?? []
    }
}
