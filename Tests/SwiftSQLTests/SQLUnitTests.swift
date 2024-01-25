//
//  SQLUnitTests.swift
//  
//
//  Created by Jason Jobe on 1/29/23.
//

import SnapshotTesting
import XCTest
@testable import SwiftSQL
@testable import SwiftSQLTesting

import SQLite3

final class SQLUnitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Snapshot Testing reset
//        isRecording = true
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDBSnapshot() throws {
        let db = try SQLConnection(location: .memory())
        try populate(db: db)
        assertSnapshot(matching: db, as: .dbDumpTable("test"))
    }
    
    func testSelect() throws {

        let db = try SQLConnection(location: .memory())
        try populate(db: db)
        
        // THEN
        let last = db.lastInsertRowID
        XCTAssert(last == 80)

        let count = db.lastChangeCount
//        let count = insert.bindParameterCount
        XCTAssert(count == 1)
        
        let select = try db.prepare("SELECT * FROM test")
        XCTAssertTrue(try select.step())
        let row = select.dictionaryValue
        assertSnapshot(matching: row, as: .dump)

        let str: String = try select.value(at: 1)
        let int: Int = try select.value(at: 0)
        let real: Double = try select.value(at: 3)
        let data: Data = try select.value(at: 4)
        assertSnapshot(matching: (data, str, real, int), as: .dump)
    }

    func testDatabasePublisher() throws {
        let db = try SQLConnection(location: .memory())
        var log: [String] = []
        let can = db.publisher().sink {
            print($0)
            log.append("\($0)")
        }
        
        try db.execute("CREATE TABLE Test (Field VARCHAR)")
        try db.execute("INSERT INTO Test VALUES ('Howdy')")
        //        try db.execute("COMMIT")
        try db.execute("""
            BEGIN;
            INSERT INTO Test VALUES ('Howdy');
            ROLLBACK;
        """)
        XCTAssertNotNil(can)
        assertSnapshot(matching: log, as: .dump)
        print ("Pass", #function)
    }
    
    func testDatabaseHooks() throws {
        let db = try SQLConnection(location: .memory())
        var didCommit = false
        var didRollback = false

        db.createCommitHandler {
            print("commit")
            didCommit = true
        }
        db.createRollbackHandler {
            print("rollback")
            didRollback = true
        }
        db.createUpdateHandler { info in
            print(info,
                  info.isDelete,
                  info.isInsert,
                  info.isUpdate)
            assertSnapshot(matching: info, as: .dump)
        }

        try db.execute("CREATE TABLE Test (Field VARCHAR)")
        try db.execute("INSERT INTO Test VALUES ('Howdy')")
//        try db.execute("COMMIT")
        try db.execute("""
            BEGIN;
            INSERT INTO Test VALUES ('Howdy');
            ROLLBACK;
        """)

        db.removeCommitHandler()
        db.removeUpdateHandler()
        db.removeRollbackHandler()

        XCTAssertTrue(didCommit)
        XCTAssertTrue(didRollback)
        
        db.interrupt()
        print ("Pass", #function)
    }

    func testSQLErrors() throws {
        let db = try SQLConnection(location: .memory())
        try db.execute("CREATE TABLE Test (Field VARCHAR)")

        let e1 = SQLError(code: 0, message: "E1 Error")
        assertSnapshot(matching: e1, as: .dump)

        let e2 = SQLError(code: SQLITE_ROW, db: db.ref)
        assertSnapshot(matching: e2, as: .dump)

        let e3 = SQLError(code: 666, db: db.ref)
        assertSnapshot(matching: e3, as: .dump)

    }
    
    func populate(db: SQLConnection) throws {
        /// GIVEN
        try db.execute("""
         CREATE TABLE test
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Level INTEGER,
            number REAL,
            thunk BLOB
        )
        
        """)
        
        let insert = try db.prepare("""
        INSERT INTO test (id, level, name, number, thunk)
        VALUES (?, ?, ?, ?, ?)
        """)
        
        // WHEN
        let d = "foo".data(using: .ascii)!

        try insert
            .bind(80, at: 0)
            .bind("Alex", at: 1)
            .bind(66, at: 2)
            .bind(43.5, at: 3)
            .bind(d, at: 4)
            .execute()
    }
}
