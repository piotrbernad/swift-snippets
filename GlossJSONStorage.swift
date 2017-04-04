//
//  JSONStorage.swift
//  Created by Piotr Bernad on 04.04.2017.
//

import Foundation
import Gloss

public enum JSONStorageType {
    case documents
    case cache
    
    var searchPathDirectory: FileManager.SearchPathDirectory {
        switch self {
        case .documents:
            return .documentDirectory
        case .cache:
            return .cachesDirectory
        }
    }
}

public enum JSONStorageError: Error {
    case wrongDocumentPath
    case couldNotCreateJSON
}

public class JSONStorage<T: Glossy> {
    
    private let document: String
    private let type: JSONStorageType
    
    private lazy var storeUrl: URL? = {
        guard let dir = FileManager.default.urls(for: self.type.searchPathDirectory, in: .userDomainMask).first else {
            assertionFailure("could not find storage path")
            return nil
        }
        
        return dir.appendingPathComponent(self.document)
    }()
    
    public init(type: JSONStorageType, document: String) {
        self.type = type
        self.document = document
    }
    
    public func read() throws -> [T] {
        guard let storeUrl = storeUrl else {
            throw JSONStorageError.wrongDocumentPath
        }
        
        let readData = try Data(contentsOf: storeUrl)
        let json = try JSONSerialization.jsonObject(with: readData, options: .allowFragments)
        
        guard let jsonArray = json as? [Gloss.JSON] else { return [] }
        
        return Array<T>.from(jsonArray: jsonArray) ?? []
    }
    
    public func write(_ itemsToWrite: [T]) throws {
        let json = itemsToWrite.map{$0.toJSON()}
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
        
        guard let storeUrl = storeUrl else {
            throw JSONStorageError.wrongDocumentPath
        }
        
        try jsonData.write(to: storeUrl)
    }
    
}
