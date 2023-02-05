//
//  File.swift
//  
//
//  Created by Jason Jobe on 2/2/23.
//

import Foundation
import KeyValueCoding
import SwiftSQL

public protocol ExpressibleByDefault {
    init(defaultContext: ())
}

public extension ExpressibleByDefault {
    static func defaultValue() -> Self {
        .init(defaultContext: ())
    }
}

public struct Schema {
    public typealias ID = Int64
    var name: String
    var valueType: Any.Type
    var md: Metadata { swift_metadata(of: valueType) }
}

public extension Schema {
    init(_ name: String? = nil, for t: Any.Type) {
        self.valueType = t
        self.name = name ?? String(describing: t)
    }
}

public extension Schema {
    func instantiate<T: ExpressibleByDefault>(
        _ type: T.Type = T.self,
        from stm: SQLStatement,
        strict: Bool = true
    ) throws -> T {
        guard valueType is T.Type else {
            throw SQLError(code: #line, message: "Cannot instantiate \(type)")
        }
        var it: T = .defaultValue()
        
        for p in md.properties {
            var v: Any?
            if strict {
                v = try stm.value(named: p.name, as: p.metadata.type)
            } else {
                v = try? stm.value(named: p.name, as: p.metadata.type)
            }
            swift_setValue(v, to: &it, key: p.name)
        }
        return it
    }
}

// MARK: - SQLite Related Extensions
public extension Schema {
    
    /*
    INSERT INTO table (column1,column2 ,..)
    VALUES( value1,    value2 ,...);
    
    INSERT OR REPLACE INTO table(column_list)
    VALUES(value_list);
    
    REPLACE INTO table(column_list)
    VALUES(value_list);
    
    UPDATE test SET (foo, bar) = ( 8, 9 )
    
    UPDATE users
    SET field1='value1',
    field2='value2',
    field3='value3'
    WHERE field1=1
    
    -- UPSERT
    CREATE TABLE phonebook2(
        name TEXT PRIMARY KEY,
        phonenumber TEXT,
        validDate DATE
    );
    INSERT INTO phonebook2(name,phonenumber,validDate)
    VALUES('Alice','704-555-1212','2018-05-08')
    ON CONFLICT(name) DO UPDATE SET
    phonenumber=excluded.phonenumber,
    validDate=excluded.validDate
    WHERE excluded.validDate>phonebook2.validDate;
    */

    /**
    CREATE TABLE phonebook2(
        name TEXT PRIMARY KEY,
        phonenumber TEXT,
        validDate DATE
    );
     */
    func sql(create table: String, pkey: String = "id") -> String {
        [String]() {
            "CREATE TABLE \(table) ("
            for p in md.properties {
                Joined(with: "") {
                    "\t" + sql_decl(for: p)
                    if p.name == pkey { " PRIMARY KEY"}
                    if p.name != md.properties.last?.name { "," }
//                        .append(",", if: { p.name != md.properties.last?.name })
                    
                }
            }
            ")"
        }
        .joined(separator: "\n")
    }
    
    func sql(select table: String) -> String {
        [String]() {
            "SELECT"
            md.properties.map(\.name).joined(separator: ", ")
            "FROM \(table)"
        }
        .joined(separator: " ")
    }
    
    func sql(insert table: String) -> String {
        [String]() {
            "INSERT INTO \(table) ("
            md.properties.map(\.name).joined(separator: ", ")
            ") VALUES ("
            String(repeating: "?, ", count: md.properties.count - 1)
            "?)"
        }
        .joined(separator: " ")
    }
}

extension Schema {
    
    func type_decl(for md: Metadata) -> String {
        switch md.type {
            case is Date.Type:
                return "DATE"
            case is Data.Type:
                return "BLOB"
            case is String.Type:
                return "TEXT"
            case is ArrayProtocol.Type:
                return "LIST"
            case is any BinaryFloatingPoint.Type:
                return "REAL"
            case is any FixedWidthInteger.Type:
                return "INT"
                
            case let it as any OptionalProtocol.Type:
                return type_decl(for: swift_metadata(of: it.honestType))
                
            default:
                return "JSON"
        }
    }
    
    func type_decl(for p: Metadata.Property) -> String {
        type_decl(for: p.metadata)
    }
    
    func sql_decl(for p: Metadata.Property, strict: Bool = true) -> String {
        if strict {
            return "\(p.name) \(type_decl(for: p))\(p.isOptional ? "" : " NOT NULL")"
        } else {
            return "\(p.name) \(type_decl(for: p))"
        }
    }
}

// MARK: - SQLStatement Extensions
public extension SQLStatement {
    
    func bind<T>(_ nob: inout T) throws -> SQLStatement {
        var params = [(any SQLBindable)?]()
        let md = swift_metadata(of: nob)
        for p in md.properties {
            let v = swift_value(of: &nob, key: p.name)
            if let v = v as? (any SQLBindable) {
                params.append(v)
            } else {
                params.append(nil)
            }
        }
        try self.bind(params)
        return self
    }
}

// MARK: - Metadata Extensions
extension Metadata.Property: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

//func Line(@ArrayBuilder<String> f: () -> [String]) -> String {
//    f().joined(separator: "")
//}

public func Joined(with sep: String = "", @ArrayBuilder<String> f: () -> [String]) -> String {
    f().joined(separator: sep)
}

// MARK: - Helper and Extensions
public extension Metadata {
    var isOptional: Bool { kind == .optional }
}

extension Metadata.Property {
    var isOptional: Bool { metadata.isOptional }
}

protocol OptionalProtocol {
    static var honestType: Any.Type { get }
}

extension Optional: OptionalProtocol {
    static var honestType: Any.Type { Wrapped.self }
}

protocol ArrayProtocol {
    static var elementType: Any.Type { get }
    static func empty() -> Self
}

extension Array: ArrayProtocol {
    static var elementType: Any.Type {
        Element.self
    }
    static func empty() -> Array<Element> {
        Self()
    }
}

public func tab(_ cnt: Int = 1) -> String {
    cnt == 1 ? "\t" : String(repeating: "\t", count: cnt)
}

public func newline(_ cnt: Int = 1) -> String {
    cnt == 1 ? "\t" : String(repeating: "\n", count: cnt)
}


public extension String {
    func append(_ s: String, if cond: () -> Bool) -> String {
        cond() ? self + s : self
    }
    
    func transform(if cond: () -> Bool, fn: (String) -> String) -> String {
        cond() ? fn(self) : self
    }
    
    func `if`(_ cond: () -> Bool, fn: (String) -> String) -> String {
        cond() ? fn(self) : self
    }
    
}

public extension Array {
    init(@ArrayBuilder<Element> makeItems: () -> [Element]) {
        self.init(makeItems())
    }
}
