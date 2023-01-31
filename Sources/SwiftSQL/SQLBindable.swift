//
//  File.swift
//  
//
//  Created by Jason Jobe on 4/16/22.
//

import Foundation
import SQLite3

public protocol SQLBindable: Equatable {
    static var defaultSQLBinder: SQLBinder { get }
}

public protocol SQLiteBindable: SQLBindable {}

extension Optional: SQLBindable where Wrapped: SQLBindable {
    public static var defaultSQLBinder: SwiftSQL.SQLBinder {
        Wrapped.defaultSQLBinder
    }
}

public struct SQLBinder {
    typealias Getter = (SQLStatement, Int) throws -> Any
    typealias Setter = (SQLStatement, Int, Any) throws -> Void
    public var name: String?
    public let valueType: Any.Type
    let getf: Getter
    let setf: Setter

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
