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

extension String: Error {}

//struct BinderKey: CodingKey {
//extension CodingKey: ExpressibleByStringLiteral {
//    init?(literalString: String) {
//        Self(stringValue: literalString)
//    }
//}

extension SQLBindable {
    static var anySQLBinder: AnySQLBinder { Self.defaultSQLBinder }
}

public protocol AnySQLBinder {
    var name: String? { get }
    var valueType: Any.Type { get }
    func get<V>(from: SQLStatement, at: Int32) throws -> V
    func set<V>(from: SQLStatement, at: Int32, to: V) throws
}

public struct SQLBinder {
//    typealias Value = Value
    typealias Getter = (SQLStatement,Int32,Any) -> Void
    public var name: String?
    public let valueType: Any.Type
    let getf: (SQLStatement,Int32) -> Any
    let setf: Getter

    public init<Value>(_ name: String? = nil,
                valueType: Value.Type = Value.self,
                getf: @escaping (SQLStatement, Int32) -> Value,
                setf: @escaping (SQLStatement, Int32, Value) -> Void)
    {
        self.name = name
        self.valueType = valueType
        self.getf = getf
        self.setf = {
            setf($0, $1, $2 as! Value)
        }
    }
}

public struct _SQLBinder<Value> {
    typealias Value = Value
    public var name: String?
    public let valueType: Any.Type
    let getf: (SQLStatement,Int32) -> Value
    let setf: (SQLStatement,Int32,Value) -> Void

    public init(_ name: String? = nil,
         valueType: Value.Type = Value.self,
         getf: @escaping (SQLStatement, Int32) -> Value,
         setf: @escaping (SQLStatement, Int32, Value) -> Void)
    {
        self.name = name
        self.valueType = valueType
        self.getf = getf
        self.setf = setf
    }
}

extension SQLBinder: AnySQLBinder {

    public func get<V>(from s: SQLStatement, at ndx: Int32) throws -> V {
        let value = self.getf(s, ndx)
        guard type(of: value) == valueType else { throw "BAD" }
        return value as! V
    }

    public func set<V>(from s: SQLStatement, at ndx: Int32, to value: V) throws {
        guard type(of: value) == valueType else { throw "BAD" }
        self.setf(s, ndx, value)
    }
}

extension FixedWidthInteger where Self: SQLBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { Self(sqlite3_column_int64($0.ref, $1)) },
        setf: { sqlite3_bind_int64($0.ref, $1, Int64($2)) })
    }
}

extension Int:   SQLBindable {}
extension Int32: SQLBindable {}
extension Int64: SQLBindable {}

extension BinaryFloatingPoint  where Self: SQLBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { Self(sqlite3_column_double($0.ref, $1)) },
        setf: { sqlite3_bind_double($0.ref, $1, Double($2)) })
    }
}

extension Float: SQLBindable {}
extension Float64: SQLBindable {}

public let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension String: SQLBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: { String(cString: sqlite3_column_text($0.ref, $1)) },
        setf: { sqlite3_bind_text($0.ref, $1, $2, -1, SQLITE_TRANSIENT) })
    }
}

extension Data: SQLBindable {
    public static var defaultSQLBinder: SQLBinder { .init(
        getf: {
            let data: Data = $0.column(at: Int($1))
            return data
        },
        setf: {(s, ndx, data: Data) in
            sqlite3_bind_blob(s.ref, Int32(ndx),
                Array(data), Int32(data.count), SQLITE_TRANSIENT)
        })
    }
}

/*
extension Optional: SQLBindable where Wrapped: AnySQLBinder {
    public static var defaultSQLBinder: SQLBinder<Optional<Wrapped>> { .init(
        getf: { (s,i) in
            if let v = s.value(at: i) {
                return v as? Wrapped
            } else {
                return .none
            }
        },
        setf: {
            if let v = $2 {
                try? v.set(from: $0, at: $1, to: v)
            } else {
                sqlite3_bind_null($0.ref, Int32($1))
            }
        })
    }
}
*/

// MARK: - Commonly used Columns
extension SQLBinder {
    func named(_ n: String) -> Self {
        var c = self
        c.name = n
        return c
    }
}

//public extension AnySQLBinder {
//    static var id: Self { Int64.defaultSQLBinder.named("id") as! Self }
//}
//
//func demo() {
//    let b: [AnySQLBinder] = [
//        Int.defaultSQLBinder,
//        Int32.defaultSQLBinder,
//        Float.defaultSQLBinder]
//    print(b)
//}

//extension String: Error {}
