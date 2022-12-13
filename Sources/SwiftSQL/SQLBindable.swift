//
//  File.swift
//  
//
//  Created by Jason Jobe on 4/16/22.
//

import Foundation
import SQLite3

public protocol SQLBindable {
    static var defaultSQLBinder: SQLBinder<Self> { get }
}

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

public struct SQLBinder<Value> {
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
        guard V.self == valueType else { throw "BAD" }
        return self.getf(s, ndx) as! V
    }

    public func set<V>(from s: SQLStatement, at ndx: Int32, to value: V) throws {
        guard V.self == valueType else { throw "BAD" }
        self.setf(s, ndx, value as! Value)
    }
}

extension FixedWidthInteger where Self: SQLBindable {
    public static var defaultSQLBinder: SQLBinder<Self> { .init(
        getf: { Self(sqlite3_column_int64($0.ref, $1)) },
        setf: { sqlite3_bind_int64($0.ref, $1, Int64($2)) })
    }
}

extension Int:   SQLBindable {}
extension Int32: SQLBindable {}
extension Int64: SQLBindable {}

extension BinaryFloatingPoint  where Self: SQLBindable {
    public static var defaultSQLBinder: SQLBinder<Self> { .init(
        getf: { Self(sqlite3_column_double($0.ref, $1)) },
        setf: { sqlite3_bind_double($0.ref, $1, Double($2)) })
    }
}

extension Float: SQLBindable {}
extension Float64: SQLBindable {}

public let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension String: SQLBindable {
    public static var defaultSQLBinder: SQLBinder<Self> { .init(
        getf: { String(cString: sqlite3_column_text($0.ref, $1)) },
        setf: { sqlite3_bind_text($0.ref, $1, $2, -1, SQLITE_TRANSIENT) })
    }
}

extension Data: SQLBindable {
    public static var defaultSQLBinder: SQLBinder<Self> { .init(
        getf: { $0.dataValue(at: Int($1)) },
        setf: {
            sqlite3_bind_blob($0.ref, Int32($1), Array($2), Int32($2.count), SQLITE_TRANSIENT)
        })
    }
}

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

// MARK: - Commonly used Columns
extension SQLBinder {
    func named(_ n: String) -> Self {
        var c = self
        c.name = n
        return c
    }
}

public extension AnySQLBinder {
    static var id: Self { Int64.defaultSQLBinder.named("id") as! Self }
}

func demo() {
    let b: [AnySQLBinder] = [
        Int.defaultSQLBinder,
        Int32.defaultSQLBinder,
        Float.defaultSQLBinder]
    print(b)
}

extension String: Error {}

extension SQLStatement {

    public func dataValue(at index: Int) -> Data {
        guard let pointer = sqlite3_column_blob(self.ref, Int32(index)) else {
            return Data()
        }
        let count = Int(sqlite3_column_bytes(self.ref, Int32(index)))
        return Data(bytes: pointer, count: count)
    }

    public func value(at index: Int) -> Any? {
        return self.value(at: Int32(index))
    }

    public func value(at index: Int32) -> Any? {
        let index = Int32(index)
        let type = sqlite3_column_type(ref, index)
        switch type {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(ref, index)
        case SQLITE_FLOAT:
            return sqlite3_column_double(ref, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(ref, index))
        case SQLITE_BLOB:
            if let bytes = sqlite3_column_blob(ref, index) {
                let byteCount = sqlite3_column_bytes(ref, index)
                return Data(bytes: bytes, count: Int(byteCount))
            } else {
                return Data()
            }
        case SQLITE_NULL:
            return nil
        default:
            return nil
        }
    }
}
