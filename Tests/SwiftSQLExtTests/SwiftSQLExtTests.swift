// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import SwiftSQL
import SwiftSQLExt

final class SwiftSQLExtTests: XCTestCase {
    var tempDir: TempDirectory!
    var db: SQLConnection!

    override func setUp() {
        super.setUp()

        tempDir = try! TempDirectory()
        db = try! SQLConnection(location: .disk(url: tempDir.file(named: "test-statements")))
        
        try! db.populateCreateTables()
    }

    override func tearDown() {
        super.tearDown()

        try! tempDir.destroy()
    }

    // MARK: Rows

    // jmj
    func testRawRow() throws {
        // GIVEN
        db.createUpdateHandler { info in
            print(info)
        }
        
        try db.populateStore()
        
        // WHEN
        let row = try db
            .prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")
            .row()
        print (row!.description)

        // THEN
//        XCTAssertEqual(user, User(name: "Alice", level: 80))
    }

    func testRow() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let user = try db
            .prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")
            .row(User.self)

        // THEN
        XCTAssertEqual(user, User(name: "Alice", level: 80))
    }

    func testRows() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let users = try db
            .prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")
            .rows(User.self)

        // THEN
        XCTAssertEqual(users, [
            User(name: "Alice", level: 80),
            User(name: "Bob", level: 90)
        ])
    }

    func testFirstNRows() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let users = try db
            .prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")
            .rows(User.self, count: 1)

        // THEN
        XCTAssertEqual(users, [
            User(name: "Alice", level: 80)
        ])
    }
    
    func testIndependentSQLRows() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let names: [String] = try db
            .prepare("SELECT Name FROM Persons ORDER BY Level ASC")
            .rows()
            .map({ $0["Name"] })

        // THEN
        XCTAssertEqual(names, [
            "Alice",
            "Bob"
        ])
    }
    
    func testIndependentSingleSQLRowNonNil() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let row = try db
            .prepare("SELECT Name FROM Persons ORDER BY Level ASC")
            .row()

        // THEN
        XCTAssertEqual(try XCTUnwrap(row)["Name"] as String, "Alice")
    }
    
    func testIndependentSingleSQLRowNil() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let row = try db
            .prepare("SELECT Name FROM Persons ORDER BY Level ASC")
            .row()

        // THEN
        XCTAssertNil(try XCTUnwrap(row)["Level"] as Int?)
    }
    
    func testInitializableBySQLColumnValueConveniencesIn64Source() throws {
        // GIVEN
        let sqlColumnValue = SQLColumnValue.int64(1)
        
        // WHEN
        let int32 = Int32(sqlColumnValue: sqlColumnValue)
        let int64 = Int64(sqlColumnValue: sqlColumnValue)
        let double = Double(sqlColumnValue: sqlColumnValue)
        let string = String(sqlColumnValue: sqlColumnValue)
        
        //THEN
        XCTAssertEqual(try XCTUnwrap(int32), 1)
        XCTAssertEqual(try XCTUnwrap(int64), 1)
        XCTAssertEqual(try XCTUnwrap(double), 1)
        XCTAssertEqual(try XCTUnwrap(string), "1")
    }
    
    func testInitializableBySQLColumnValueConveniencesDoubleSource() throws {
        // GIVEN
        let sqlColumnValue = SQLColumnValue.double(1)
        
        // WHEN
        let int = Int(sqlColumnValue: sqlColumnValue)
        let int32 = Int32(sqlColumnValue: sqlColumnValue)
        let int64 = Int64(sqlColumnValue: sqlColumnValue)
        let string = String(sqlColumnValue: sqlColumnValue)
        
        //THEN
        XCTAssertEqual(try XCTUnwrap(int), 1)
        XCTAssertEqual(try XCTUnwrap(int32), 1)
        XCTAssertEqual(try XCTUnwrap(int64), 1)
        XCTAssertEqual(try XCTUnwrap(string), "1.0")
    }
    
    func testInitializableBySQLColumnValueConveniencesStringSource() throws {
        // GIVEN
        let sqlColumnValue = SQLColumnValue.string("1")
        
        // WHEN
        let int = Int(sqlColumnValue: sqlColumnValue)
        let int32 = Int32(sqlColumnValue: sqlColumnValue)
        let int64 = Int64(sqlColumnValue: sqlColumnValue)
        let double = Double(sqlColumnValue: sqlColumnValue)
        
        //THEN
        XCTAssertEqual(try XCTUnwrap(int), 1)
        XCTAssertEqual(try XCTUnwrap(int32), 1)
        XCTAssertEqual(try XCTUnwrap(int64), 1)
        XCTAssertEqual(try XCTUnwrap(double), 1)
    }
    
    func testCaseInsensitiveColumnNameSubscripts() throws {
        // GIVEN
        try db.populateStore()

        // WHEN
        let row = try db
            .prepare("SELECT Name FROM Persons ORDER BY Level ASC")
            .row()

        // THEN
        XCTAssertEqual(try XCTUnwrap(row)["name"] as String, "Alice")
    }
}

private extension SQLConnection {
    func populateCreateTables() throws {
        try execute("""
        CREATE TABLE Users
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Level INTEGER
        )
        """)
        try execute("""
        CREATE TABLE Persons
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Level INTEGER
        )
        """)
    }
    
    func populateStore() throws {
        
        let insertUsersStatement = try self.prepare("""
        INSERT INTO Users (Name, Level)
        VALUES (?, ?)
        """)

        try insertUsersStatement
            .bind("Alice", 80)
            .execute()

        try insertUsersStatement.reset()

        try insertUsersStatement
            .bind("Bob", 90)
            .execute()
        
        let insertPersonsStatement = try self.prepare("""
        INSERT INTO Persons (Name, Level)
        VALUES (?, ?)
        """)

        try insertPersonsStatement
            .bind("Alice", Int64(80))
            .execute()

        try insertPersonsStatement.reset()

        try insertPersonsStatement
            .bind("Bob", Int64(90))
            .execute()
    }
}


private struct User: Hashable, SQLRowDecodable {
    let name: String
    let level: Int

    init(name: String, level: Int) {
        self.name = name
        self.level = level
    }

    init(row: SQLRow) throws {
        self.name = row[0]
        self.level = row[1]
    }
}
private struct Person: Hashable, SQLRowDecodable {
    let name: String
    let level: Int64?

    init(name: String, level: Int64?) {
        self.name = name
        self.level = level
    }

    init(row: SQLRow) throws {
        self.name = row["Name"]
        self.level = row["Level"]
    }
}
