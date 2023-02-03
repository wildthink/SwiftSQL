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

    func sampleDatabase() throws -> SQLConnection {
        let db = try! SQLConnection(location: .memory())
        try db.execute("CREATE TABLE Test (name TEXT, ndx INT)")
        
        // WHEN/THEN binds the value
        try db.prepare("INSERT INTO Test (name, ndx) VALUES (?, ?)")
            .bind("alpha", 1)
            .execute()
        return db
    }
    
    func testInstantiateStrict() throws {
        // We delibertly do NOT select all columns
        // So it should raise an exception
        let db = try sampleDatabase()
        let statement = try db.prepare("SELECT name FROM Test")
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
        do {
            let v: S = try s.instantiate(from: statement, strict: true)
            print (v)
        } catch {
            print(error.localizedDescription)
        }
//        assertSnapshot(matching: v, as: .dump)
    }

    func testInstantiateLoose() throws {
        // We delibertly do NOT select all columns
        // So some default values should remain
        let db = try sampleDatabase()
        let statement = try db.prepare("SELECT name FROM Test")
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
        let v: S = try s.instantiate(from: statement, strict: false)
        assertSnapshot(matching: v, as: .dump)
    }
    
    func testInstantiate() throws {
        let db = try sampleDatabase()
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
        assertSnapshot(matching: v, as: .dump)
    }

//    func testMD() throws {
//        let md = swift_metadata(of: Schema.self)
//        print(md)
//        let t = md.type == Int.self
//        print(t)
//        for p in md.properties {
//            print(p.name, p.metadata.kind == .optional)
//        }
//     }
    
    func testSchema() throws {
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
