//
//  SQLSchemaTests.swift
//  
//
//  Created by Jason Jobe on 1/30/23.
//

import XCTest
import SwiftSQL
import SwiftSQLExt
import KeyValueCoding
import SnapshotTesting


protocol Entity {}

final class SQLSchemaTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInstantiate() throws {
        let db = try! SQLConnection(location: .memory())
        try db.execute("CREATE TABLE Test (name TEXT, ndx INT)")
        
        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (name, ndx) VALUES (?, ?)")
            .bind("alpha", 1)
            .execute()
        
        // WHEN/THEN reads the value
        let statement = try db.prepare("SELECT name, ndx FROM Test")
        XCTAssertTrue(try statement.step())
        struct S: ExpressibleByDefault {
            var name: String
            var ndx: Int
            
            init(defaultContext: ()) {
                name = ""
                ndx = 0
            }
        }
        let s = Schema(for: S.self)
        let v: S = try s.instantiate(from: statement)
        print(v)
    }

    func testMD() throws {
        let md = swift_metadata(of: Schema.self)
        print(md)
        let t = md.type == Int.self
        print(t)
        for p in md.properties {
            print(p.name, p.metadata.kind == .optional)
        }
     }
    
    func testSchema() throws {
//        let p: Person = .defaultValue()
//        print(p)
        
        let s = Schema(for: Person.self)
        assertSnapshot(matching: s.sql(create: "person"), as: .lines)
        assertSnapshot(matching: s.sql(insert: "person"), as: .lines)
    }

}

struct Person {
    var name: String
    var date: Date
    var dob: Date?
    var tags: [String]
    var friends: [Person]
}

extension Person: ExpressibleByDefault {
    init(defaultContext: ()) {
        self = .init(name: "", date: .distantPast, tags: [], friends: [])
    }
}
