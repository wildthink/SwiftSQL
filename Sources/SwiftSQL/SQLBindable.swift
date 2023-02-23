//
//  File.swift
//  
//
//  Created by Jason Jobe on 4/16/22.
//

import Foundation
import SQLite3

#if SQLBindable_FEATURE
public protocol SQLBindable: Equatable {
    static var defaultSQLBinder: SQLBinder { get }
}

public protocol SQLiteBindable: SQLBindable {}

extension Optional: SQLBindable where Wrapped: SQLBindable {
    public static var defaultSQLBinder: SwiftSQL.SQLBinder {
        Wrapped.defaultSQLBinder
    }
}

//extension Array: SQLBindable where Element: Codable & Equatable {
//    public static var defaultSQLBinder: SQLBinder {
//        fatalError()
//    }
//}

public struct SQLBinder {
    public typealias Getter = (SQLStatement, Int) throws -> Any
    public typealias Setter = (SQLStatement, Int, Any) throws -> Void
    public var name: String?
    public let valueType: Any.Type
    public let getf: Getter
    public let setf: Setter

    public init<Value>(_ name: String? = nil,
                valueType: Value.Type = Value.self,
                getf: @escaping (SQLStatement, Int) throws -> Value,
                setf: @escaping (SQLStatement, Int, Value) throws -> Void)
    {
        self.name = name
        self.valueType = valueType
        self.getf = {
            try getf($0, $1)
        }
        self.setf = {
            guard let v = $2 as? Value
            else { throw SQLError(
                code: #line,
                message: "Value '\(String(describing: $2))' is not a \(Value.self)")
            }
            try setf($0, $1, v)
        }
    }
}

extension FixedWidthInteger where Self: SQLiteBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { Self($0.column(at: Int($1)) as Int64) },
        setf: { try $0.bind(value: $2, at: $1) })
    }
}

extension Int:   SQLiteBindable {}
extension Int32: SQLiteBindable {}
extension Int64: SQLiteBindable {}

extension BinaryFloatingPoint  where Self: SQLiteBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { Self($0.column(at: Int($1)) as Double) },
        setf: { try $0.bind(value: Double($2), at: $1) })
    }
}

extension Float: SQLiteBindable {}
extension Float64: SQLiteBindable {}

extension String: SQLiteBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { $0.column(at: Int($1)) as String },
        setf: { try $0.bind(value: $2, at: $1) })
    }
}

extension Data: SQLiteBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { $0.column(at: Int($1)) as Data },
        setf: { try $0.bind(value: $2, at: $1) })
    }
}

// MARK: - Commonly used Columns
public extension SQLBinder {
    func named(_ n: String) -> Self {
        var c = self
        c.name = n
        return c
    }
}

public extension SQLBinder {
    static var id: Self { Int64.defaultSQLBinder.named("id") }
}

// MARK: SQLStatement Integration
extension SQLStatement {
    // MARK: SQLBindable Parameters
    
    /// Binds values to the statement parameters.
    ///
    ///     try db.prepare("INSERT INTO Users (Level, Name) VALUES (?, ?)")
    ///        .bind(80, "John")
    ///        .execute()
    ///
    @discardableResult
    public func bind(_ parameters: (any SQLBindable)?...) throws -> Self {
        try bind(parameters)
        return self
    }
    
    /// Binds values to the statement parameters.
    ///
    ///     try db.prepare("INSERT INTO Users (Level, Name) VALUES (?, ?)")
    ///        .bind([80, "John"])
    ///        .execute()
    ///
    @discardableResult
    public func bind(_ parameters: [(any SQLBindable)?]) throws -> Self {
        for (index, value) in zip(parameters.indices, parameters) {
            try bind(value: value, at: Int(index + 1))
        }
        return self
    }
    
    /// Binds values to the named statement parameters.
    ///
    ///     let row = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param LIMIT 1")
    ///         .bind([":param": "John""])
    ///         .next()
    ///
    /// - parameter name: The name of the parameter. If the name is missing, throws
    /// an error.
    @discardableResult
    public func bind(_ parameters: [String: (any SQLBindable)?]) throws -> Self {
        for (key, value) in parameters {
            try _bind(value, for: key)
        }
        return self
    }
    
    /// Binds values to the parameter with the given name.
    ///
    ///     let row = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param LIMIT 1")
    ///         .bind("John", for: ":param")
    ///         .next()
    ///
    /// - parameter name: The name of the parameter. If the name is missing, throws
    /// an error.
    @discardableResult
    public func bind<B: SQLiteBindable>(_ value: B?, for name: String) throws -> Self {
        try _bind(value, for: name)
        return self
    }
    
    /// Binds value to the given index.
    ///
    /// - parameter index: The index starts at 0.
    @discardableResult
    public func bind<B: SQLBindable>(_ value: B?, at index: Int) throws -> Self {
        try bind(value: value, at: (index + 1))
        return self
    }
    
    private func _bind(_ value: (any SQLBindable)?, for name: String) throws {
        let index = sqlite3_bind_parameter_index(ref, name)
        guard index > 0 else {
            throw SQLError(code: SQLITE_MISUSE, message: "Failed to find parameter named \(name)")
        }
        try bind(value: value, at: Int(index))
    }
    
    //    private func _bind<B: SQLBindable>(_ value: B?, for name: String) throws {
    //        let index = sqlite3_bind_parameter_index(ref, name)
    //        guard index > 0 else {
    //            throw SQLError(code: SQLITE_MISUSE, message: "Failed to find parameter named \(name)")
    //        }
    //        try _bind(value, at: Int(index))
    //    }
}
#endif

