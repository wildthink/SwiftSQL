//
//  SQLSchemaTests.swift
//  
//
//  Created by Jason Jobe on 1/30/23.
//

import XCTest
@testable import SwiftSQL
@testable import SwiftSQLExt
import KeyValueCoding
import SnapshotTesting

protocol Entity {}

final class SQLSchemaTests: XCTestCase {
    
    var tempDir: TempDirectory!
    var storeURL: URL!
    var db: SQLConnection!
    
    override func setUpWithError() throws {
        tempDir = try! TempDirectory()
        storeURL = tempDir.file(named: "test-store-perf")
        db = try! SQLConnection(location: .disk(url: storeURL))
        // Set `isRecording` to reset Snapshots
        //                isRecording = true
    }
        
    override func tearDownWithError() throws {
        tempDir = nil
    }
    
    func sampleDatabase() throws -> SQLConnection {
//        let db = try! SQLConnection(location: .memory())
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
            assertSnapshot(matching: v, as: .dump)
        } catch {
            print(error.localizedDescription)
        }
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
    
//    func testAPI() throws {
//        let a = [23]
//        let t = type(of: a as ArrayProtocol)
//        var s: Int? = 23
//        let sr = s.storableRepresentation
//        s = nil
//        let sn = s.storableRepresentation
//        assertSnapshot(matching: (s, sr, sn), as: .dump)
//        assertSnapshot(matching: (t.elementType, t.empty()), as: .dump)
//    }
    
    // FIXME: Add JSON Column support
    func testTopicII() throws {
        let db = try! SQLConnection(location: .memory())
        let sc = Schema(table: "people", for: Person.self)
        try sc.create(in: db, table: "people")
        
        let date = Date(timeIntervalSince1970: 0)
        let p1  = Person(id: 10, name: "George", dob: date, tags: ["one"])
        let p2  = Person(id: 20, name: "Jane", dob: date, tags: ["two"])
        try sc.insert(in: db, [p1, p2])
        
        try sc.select(in: db, where: "", limit: 1) {
            print($0)
        }
        
        assertSnapshot(matching: db, as: .dbDumpTable("people"))
    }
    
    func testTopic() throws {
        let db = try! SQLConnection(location: .memory())
        let s = Schema(for: Topic.self)
        
        // CREATE
        let sql = s.sql(create: "topic")
        print(sql)
        try db.execute(sql)
        
        // INSERT
        let insert = try db.prepare(s.sql(insert: "topic"))
        
        try insert
            .bind(1, "alpha", 23)
            .execute()
        
        // SELECT
        let select = try db.prepare(s.sql(select: "topic"))
        
        while try select.step() {
            let t: Topic = try s.instantiate(from: select, strict: false)
            print (t)
        }
        
        let t1  = Topic(id: "10", name: "beta")
        try insert.rebind(t1).execute()
        
        let t2  = Topic(id: "20", name: "charlie")
        try insert.rebind(t2).execute()
        
        try select.reset()
        var results = [Any]()
        
        while try select.step() {
            let t: Topic = try s.instantiate(from: select, strict: false)
            results.append(t)
            print (t)
        }
        
        assertSnapshot(matching: results, as: .dump)
        
        let curs = try db.select(Topic.self, from: "topic")
        while let row = try curs.next() {
            print(row)
        }
    }
    
    func testPragma() throws {
        let db = try! SQLConnection(location: .memory())
        let ts = Schema(for: Topic.self)
        
        // CREATE
        let sql = ts.sql(create: "topic")
        try db.execute(sql)
        
        let info = try db.prepare("PRAGMA table_info(topic)")
        
        while try info.step() {
            do {
                let t: Table = try info.instantiate(strict: false)
                print (t)
            } catch {
                let p = info.dictionaryValue
                print (error, p)
            }
        }
    }
    
    func _testTableInfo() throws {
        let db = try! SQLConnection(location: .memory())
        let ts = Schema(for: Topic.self)
        
        // CREATE
        let sql = ts.sql(create: "topic")
        try db.execute(sql)
        
        // ERROR notnull is keyword
        let curs = try db.select(Table.self, from: "pragma_table_info('topic')")
        while let r = try curs.next() {
            print(r)
        }
    }
    
    func testSchemaSQLCreate() throws {
        let s = Schema(for: Person.self)
        assertSnapshot(matching: s.sql(create: "person"), as: .lines)
    }
    
    func testSchemaSQLSelect() throws {
        let s = Schema(for: Person.self)
        assertSnapshot(matching: s.sql(select: "person"), as: .lines)
    }
    
    func testSchemaSQLInsert() throws {
        let s = Schema(for: Person.self)
        assertSnapshot(matching: s.sql(insert: "person"), as: .lines)
    }
}

struct Table: ExpressibleByDefault {
    init(defaultContext: ()) {
        cid = 0
        name = ""
        type = ""
        notnull = false
        dflt_value = nil
        pk = false
    }
    
    var cid: Int64
    var name: String
    var type: String
    var notnull: Bool
    var dflt_value: Any?
    var pk: Bool
}

//extension UUID {
//    static func preview(_ ndx: Int) -> UUID {
//        return .init(uuidString: "\ndx")!
//    }
//}
//            let v = _swift_getKeyPath(pattern: , arguments: )

struct TopicQuery: EntityQuery {
    func entities(for identifiers: [Topic.ID]) async throws -> [Topic] {
        .init()
    }
}

/*
 func suggestedEntities() async throws -> [AlbumEntity] {
 try await MusicCatalog.shared.favoriteAlbums()
 .map { AlbumEntity(id: $0.id, albumName: $0.name) }
 }
 
 */
import AppIntents

@available(macOS 13.0, *)
struct Topic: AppEntity {
    typealias ID = String
    static var defaultQuery: TopicQuery = .init()
    
    var id: ID
    var name: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Topic"
    }
    
    var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: name))
    }
    
}

//struct Topic {
//    var id: Int64
//    var name: String
//    var value: Int?
//}

extension Topic: ExpressibleByDefault {
    init(defaultContext: ()) {
        id = .init()
        name = ""
        //        value = nil
    }
}

struct Person {
    var id: Int64
    var name: String
    var dob: Date?
    var tags: [String]
}

extension Person: ExpressibleByDefault {
    init(defaultContext: ()) {
        self = .init(id: 0, name: "", tags: [])
    }
}
