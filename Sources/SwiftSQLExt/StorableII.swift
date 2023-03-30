//
//  File.swift
//  
//
//  Created by Jason Jobe on 2/26/23.
//

import Foundation
import SwiftSQL
import SQLite3

public protocol SQLiteStorable {
    static var storeValueTransformer: StoreValueTransformer { get }
}

public protocol StoreValueTransformer {
    var storeValueType: Any.Type { get }
    var swiftValueType: Any.Type { get }
    
    func encode(value: Any) -> Any
    func decode(from: SQLStatement, at: Int) throws -> Any
}

public struct JSONValueTransformer: StoreValueTransformer {
    public var storeValueType: Any.Type { String.self }
    public var swiftValueType: Any.Type { Any.self }
    
    public func encode(value: Any) -> Any {
        if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let string = String(data: data, encoding: String.Encoding.utf8) {
            return string
        } else { return "" }
    }
    
    public func decode(from stm: SwiftSQL.SQLStatement, at ndx: Int) throws -> Any {
        guard let data = stm.stringValue(at: ndx).data(using: .utf8)
        else { throw SQLError(uncovertable: Any.self) }
        let json = try JSONSerialization.jsonObject(with: data)
        return json
    }
}

public struct SQLiteStoreValueTransformer<StoreValue, SwiftValue>: StoreValueTransformer {
    
    public let storeValueType: Any.Type
    public let swiftValueType: Any.Type
    let encoder: (SwiftValue) -> StoreValue
    let decoder: (SQLStatement, Int) throws -> SwiftValue
    
    public init(
        encoder: @escaping (SwiftValue) -> StoreValue,
        decoder: @escaping (SQLStatement, Int) throws -> SwiftValue)
    {
        storeValueType = StoreValue.self
        swiftValueType = SwiftValue.self
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public func encode(value: Any) -> Any {
        guard let value = value as? SwiftValue else {
            fatalError()
        }
        print(#function, value, "to", storeValueType)
        return encoder(value)
    }
    public func decode(from: SQLStatement, at ndx: Int) throws -> Any {
        return try decoder(from, ndx)
    }

//    public func decode(from value: Any) -> Any {
//        guard let value = value as? StoreValue else {
//            fatalError("\(value) is not \(StoreValue.self)")
//        }
//        print(#function, value, "to", swiftValueType)
//        return decoder(value)
//    }
}

extension SQLiteStorable where Self: FixedWidthInteger {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(encoder: { Int64($0) }, decoder: { $0.intValue(at: $1, preferredType: Self.self) })
    }
}

// MARK: - SQLiteStorable BinaryFloatingPoint
extension SQLiteStorable where Self: BinaryFloatingPoint {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(encoder: { Double($0) }, decoder: { $0.realValue(at: $1, preferredType: Self.self) })
    }
}

#if JMJ_II
extension Int:   SQLiteStorable {}
extension Int8:  SQLiteStorable {}
extension Int16: SQLiteStorable {}
extension Int32: SQLiteStorable {}
extension Int64: SQLiteStorable {}

extension CGFloat: SQLiteStorable {}
extension Float16: SQLiteStorable {}
extension Float32: SQLiteStorable {}
extension Float64: SQLiteStorable {}

// MARK: SQLiteStorable: Data, String, Bool
extension Data:   SQLiteStorable {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(encoder: { $0 as Self }, decoder: { $0.dataValue(at: $1) })
    }
}

extension String:   SQLiteStorable {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(encoder: { $0 as Self }, decoder: { $0.stringValue(at: $1) })
    }
}

extension Bool:   SQLiteStorable {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(encoder: { $0 as Self }, decoder: { $0.boolValue(at: $1) })
    }
}

extension Date: SQLiteStorable {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(encoder: {
            PreciseDateFormatter.string(from: $0)
        },
        decoder: {
            let s = $0.stringValue(at: $1)
            return PreciseDateFormatter.date(from: s) ?? .distantPast
        })
    }
}

/*
extension Array: SQLiteStorable where Element: SQLiteStorable {
    public static var storeValueTransformer: StoreValueTransformer {
        SQLiteStoreValueTransformer(
        encoder: {
            // json -> String
            do {
                let data = try JSONSerialization
                    .data(withJSONObject: self, options: [])
                return String(data: data, encoding: String.Encoding.utf8)
                ?? "[]"
            } catch {
                return "[]"
            }
        },
        decoder: {
            do {
                let s = $0.stringValue(at: $1)
                let data = s.data(using: .utf8)!
                let json = try JSONSerialization.jsonObject(with: data)
//                return (json as? Self) ?? .empty()
            } catch {
                print(error)
//                return .empty()
            }
//            return Self.empty()
//            print(s)
//            fatalError()
//            return Self.empty()
//            let s = $0.stringValue(at: $1)
//            let jsd = JSONSerialization()
//            let result = JSONSerialization.dat
//            return PreciseDateFormatter.date(from: s) ?? .distantPast
        })
    }
}
*/

func stringify(json: Any, prettyPrinted: Bool = false) -> String {
    var options: JSONSerialization.WritingOptions = []
    if prettyPrinted {
        options = JSONSerialization.WritingOptions.prettyPrinted
    }
    
    do {
        let data = try JSONSerialization.data(withJSONObject: json, options: options)
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            return string
        }
    } catch {
        print(error)
    }
    
    return ""
}
#endif

public extension SQLStatement {
    func sql(expanded: Bool = false) -> String? {
        if expanded {
            guard let cstr = sqlite3_expanded_sql(ref) else { return nil }
            return String(cString: cstr)
        } else {
            guard let cstr = sqlite3_sql(ref) else { return nil }
            return String(cString: cstr)
        }
    }
}

/*
 ```
 sqlite3_bind_text(stmt, 7, strtok (NULL, "\t"), -1, SQLITE_TRANSIENT);    // Get Column value
 
 sqlite3_step(stmt);        // Execute the SQL Statement
 sqlite3_clear_bindings(stmt);    // Clear bindings
 sqlite3_reset(stmt);        // Reset VDBE
```
 */

extension SQLStatement {
    /// The leftmost column of the result set has the index 0
    public func value<T: SQLiteStorable>(named: String, as t: T.Type = T.self)
    throws -> T {
        guard let ndx = columnIndex(forName: named)
        else { throw SQLError(code: #line, message: "No column \(named) found") }
        return try value(at: ndx, as: t)

//        guard let ndx = columnIndex(forName: named),
//              let svalue = try T.storeValueTransformer.decode(from: self, at: ndx) as? T
//        else { throw SQLError(uncovertable: t) }
//        return svalue
    }
    
    /// The leftmost column of the result set has the index 0
    public func value<T: SQLiteStorable>(at ndx: Int, as t: T.Type = T.self)
    throws -> T {
        if let svalue =
        try T.storeValueTransformer.decode(from: self, at: ndx) as? T {
            return svalue
        }
        else if let cv =
        try JSONValueTransformer().decode(from: self, at: ndx) as? T {
            return cv
        }
        // else
        throw SQLError(uncovertable: t)
//        guard
//              let svalue = try T.storeValueTransformer.decode(from: self, at: ndx) as? T
//        else { throw SQLError(uncovertable: t) }
//        return svalue
    }
    
    // MARK: - Public SQL Statement Binding functions
    @discardableResult
    public func bind(_ parameters: SQLiteStorable?...) throws -> Self {
        try bind(parameters)
        return self
    }

    @discardableResult
    public func bind(_ parameters: [SQLiteStorable?]) throws -> Self {
        for (index, value) in zip(parameters.indices, parameters) {
            try bind(value: value, at: Int(index + 1))
        }
        return self
    }

    @discardableResult
    public func bind(_ parameters: [String: SQLiteStorable?]) throws -> Self {
        for (key, value) in parameters {
            try bind(value, for: key)
        }
        return self
    }

    // MARK: - Private SQL Statement Binding functions
    @discardableResult
    public func bind(_ value: Any?, for name: String) throws -> Self {
        let ndx = sqlite3_bind_parameter_index(ref, name)
        return try bind(value, at: Int(ndx-1))
    }

    @discardableResult
    public func bind(_ value: Any?, at index: Int) throws -> Self {
        let index = index + 1 // SQLite starts a 1 NOT 0
        guard let value else {
            sqlite3_bind_null(ref, Int32(index))
            return self
        }
        if let value = value as? SQLiteStorable {
            let bv = type(of: value).storeValueTransformer.encode(value: value)
            try bind(value: bv, at: index)
            return self
        }
        if let value = value as? Encodable {
            let bv = JSONValueTransformer().encode(value: value)
            try bind(value: bv, at: index)
            return self
        }
        // else
        throw SQLError(code: #line, message: "Unsupport type \(type(of: value))")
    }
}
