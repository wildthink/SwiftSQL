//
//  Schema.swift
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

public struct Schema<E: ExpressibleByDefault> {
    public typealias ID = Int64
    public private(set) var table: String
    public private(set) var valueType: E.Type
    var md: Metadata { swift_metadata(of: valueType) }
}

public extension Schema {
    init(table: String? = nil, for t: E.Type) {
        self.valueType = t
        self.table = table ?? String(describing: t)
    }
}

extension Optional: SQLiteStorable where Wrapped: SQLiteStorable {
    public static var storeValueTransformer: StoreValueTransformer {
        Wrapped.storeValueTransformer
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
            let ptype = p.metadata.type
            guard let ndx = stm.columnIndex(forName: p.name)
            else {
                if strict {
                    throw SQLError(code: #line, message: "Cannot instantiate \(type)")
                } else {
                    continue
                }
            }
            if let  ptype = ptype as? SQLiteStorable.Type {
//               let ndx = stm.columnIndex(forName: p.name) {
                v = try ptype.storeValueTransformer.decode(from: stm, at: ndx)
            } else if ptype is Decodable.Type {
                v = try JSONValueTransformer().decode(from: stm, at: ndx)
            }
            else {
                throw SQLError(code: #line, message: "Cannot instantiate \(type)")
            }
//            guard let ptype = ptype as? SQLiteStorable.Type
//            else { throw SQLError(uncovertable: ptype) }
//            if strict {
//                v = try stm.value(named: p.name, as: ptype)
//            } else {
//                v = try? stm.value(named: p.name, as: ptype)
//            }
            swift_setValue(v, to: &it, key: p.name)
        }
        return it
    }
}

// MARK: - SQLite Related Extensions
public extension Schema {
    func create(in db: SQLConnection, table: String) throws {
        let sql = sql(create: table)
        try db.execute(sql)
    }
    
    func insert(in db: SQLConnection, _ rows: [E]) throws {
        let sql = sql(insert: table)
        let insert = try db.prepare(sql)
        try db.execute("BEGIN TRANSACTION;")
        for row in rows {
            try insert.reset()
            try insert.bind(object: row).execute()
        }
        try db.execute("COMMIT;")
    }
    
    func select(
        in db: SQLConnection,
        where cond: String? = nil,
        limit: Int = 0,
        fn: (E) -> Void)
    throws {
        let select = try db.prepare(sql(select: table, where: cond, limit: limit))
        while try select.step() {
            let t: E = try instantiate(from: select, strict: false)
            fn(t)
        }
    }
}

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
    
    func sql(select table: String, where cond: String? = nil, limit: Int = 0) -> String {
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
            case is Bool.Type:
                return "BOOL"
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
    
    func sql_decl(for p: Metadata.Property, strict: Bool = false) -> String {
        if strict {
            return "\(p.name) \(type_decl(for: p))\(p.isOptional ? "" : " NOT NULL")"
        } else {
            return "\(p.name) \(type_decl(for: p))"
        }
    }
}

// MARK: - SQLConnection Extensions
public struct SQLCursor<T: ExpressibleByDefault> {
    var stmt: SQLStatement
    public func next() throws -> T? {
        guard try stmt.step() else { return nil }
        return try stmt.instantiate(T.self)
    }
}

public extension SQLConnection {
    func select<T: ExpressibleByDefault>(
        _ type: T.Type = T.self,
        from table: String
    ) throws -> SQLCursor<T> {
        let sc = Schema(for: T.self)
        let sql = sc.sql(select: table)
        print(#function, sql)
        let select = try prepare(sql)
        return SQLCursor(stmt: select)
    }
}


// MARK: - SQLStatement Extensions
public extension SQLStatement {
    
    func bind<T>(object: T) throws -> SQLStatement {
        var copy = object
//        defer { _ = try? reset() }
        return try bind(&copy)
    }
    

    #if !JMJ_II
    func bind<T>(object: inout T) throws -> SQLStatement {
        var params = [Storable?]()
        let md = swift_metadata(of: object)
        for p in md.properties {
            let v = swift_value(of: &object, key: p.name)
            if let v = v as? BuiltinStorable {
                params.append((v.builtinRepresentation as! Storable))
            } else if let v = v as? Storable {
                params.append(v.storableRepresentation)
            } else {
                params.append(nil)
            }
        }
        try self.bind(params)
        return self
    }
    #else
    func bind<T>(_ nob: inout T) throws -> SQLStatement {
        var params = [SQLiteStorable?]()
        let md = swift_metadata(of: nob)
        var sv: SQLiteStorable?
        
        for p in md.properties {
            let v = swift_value(of: &nob, key: p.name)
            if let v = v as? SQLiteStorable,
               let nob = type(of: v).storeValueTransformer.encode(value: v) as? SQLiteStorable {
                sv = nob
//                params.append(sv)
//                try self.bind(sv, for: p.name)
//                params.append(type(of: v).storeValueTransformer.encode(value: v))
            } else if let v = v as? Encodable,
                      let jv = JSONValueTransformer().encode(value: v) as? SQLiteStorable {
                sv = jv
//                params.append(sv)
//                try self.bind(sv, for: p.name)
            } else {
//                params.append(nil)
                sv = nil
//                try self.bind(nil, for: p.name)
            }
            if let nob = sv {
                if let bob = sv as? OptionalProtocol {
                    params.append(bob.honestValue as? SQLiteStorable)
                } else {
                    params.append(nob)
                }
            } else {
                params.append(nil)
            }
        }
        try self.bind(params)
//        try self.bind(SQLiteStorable?, for: <#T##String#>)
        return self
    }
    #endif
    
    func instantiate<T: ExpressibleByDefault>(
        _ type: T.Type = T.self,
        strict: Bool = false
    ) throws -> T? {
        
        var it: T = .defaultValue()
        let md = swift_metadata(of: T.self)
        
        for p in md.properties {
            var v: Any?
            let ptype = p.metadata.type
            guard let ptype = ptype as? SQLiteStorable.Type
            else { throw SQLError(uncovertable: ptype)}
            if strict {
                v = try self.value(named: p.name, as: ptype)
            } else {
                v = try? self.value(named: p.name, as: ptype)
            }
            swift_setValue(v, to: &it, key: p.name)
        }
        return it
    }
    
    func instantiate<T: ExpressibleByDefault>(
        _ type: T.Type = T.self,
        strict: Bool = false
    ) throws -> T {
        
        var it: T = .defaultValue()
        let md = swift_metadata(of: T.self)
        
        for p in md.properties {
            var v: Any?
            let ptype = p.metadata.type
            guard let ptype = ptype as? SQLiteStorable.Type
            else { throw SQLError(uncovertable: ptype)}
            if strict {
                v = try self.value(named: p.name, as: ptype)
            } else {
                v = try? self.value(named: p.name, as: ptype)
            }
            swift_setValue(v, to: &it, key: p.name)
        }
        return it
    }
}

extension SQLError {
    init(uncovertable type: Any.Type, line: Int32 = #line) {
        self.init(code: line, message: "\(type) cannot be converted to SQLiteStorable")
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
