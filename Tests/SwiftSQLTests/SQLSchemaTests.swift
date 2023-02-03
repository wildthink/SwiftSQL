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
        let s = Schema(for: Person.self)
        print(s.sql(create: "person"))
        print(s.sql(insert: "person"))
        
//        assertSnapshot(matching: s.sql(create: "person"), as: .dump)
//        assertSnapshot(matching: s.sql(insert: "person"), as: .dump)
    }

}

struct Person {
    var name: String
    var date: Date
    var dob: Date?
    var tags: [String]
    var friends: [Person]
}
