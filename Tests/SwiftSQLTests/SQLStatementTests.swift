// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import SwiftSQL

final class SQLStatementTests: XCTestCase {
    var tempDir: TempDirectory!
    var db: SQLConnection!

    override func setUp() {
        super.setUp()

        tempDir = try! TempDirectory()
        db = try! SQLConnection(location: .disk(url: tempDir.file(named: "test-statements")))
    }

    override func tearDown() {
        super.tearDown()

        try! tempDir.destroy()
    }

    // MARK: Execute

    func testCreateTable() throws {
        // WHEN/THEN
        XCTAssertNoThrow(try db.execute("""
        CREATE TABLE Users
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Level INTEGER,
            Name VARCHAR
        )
        """))
    }

    // MARK: Binding Parameters

    func testBindUsingIndexes() throws {
        /// GIVEN
        try db.createTables()

        let insert = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        // WHEN
        try insert
            .bind(80, at: 0)
            .bind("Alex", at: 1)
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0), 80)
        XCTAssertEqual(select.column(at: 1), "Alex")
    }

    func testBindNilUsingIndexes() throws {
        /// GIVEN
        try db.createTables()

        let statement = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        // WHEN
        try statement
            .bind(80, at: 0)
            .bind(nil, at: 1)
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0), 80)
        XCTAssertEqual(select.column(at: 1) as String?, nil)
    }

    func testBindUsingArray() throws {
        /// GIVEN
        try db.createTables()

        let statement = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        // WHEN
        try statement
            .bind([80, "Alex"])
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0), 80)
        XCTAssertEqual(select.column(at: 1), "Alex")
    }

    func testBindUsingArrayNilValue() throws {
        /// GIVEN
        try db.createTables()

        let statement = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        // WHEN
        try statement
            .bind([80, nil])
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0), 80)
        XCTAssertEqual(select.column(at: 1) as String?, nil)
    }

    func testBindUsingVariadics() throws {
        /// GIVEN
        try db.createTables()

        let statement = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        // WHEN
        try statement
            .bind(80, "Alex")
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0), 80)
        XCTAssertEqual(select.column(at: 1), "Alex")
    }

    func testBindUsingVariadicsNilValue() throws {
        /// GIVEN
        try db.createTables()

        let statement = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        // WHEN
        try statement
            .bind(80, nil)
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0), 80)
        XCTAssertEqual(select.column(at: 1) as String?, nil)
    }

    func testBindByName() throws {
        /// GIVEN
        try db.createTables()

        try db.prepare("INSERT INTO Users (Level, Name) VALUES (?, ?)")
            .bind(80, "Alex")
            .execute()

        // WHEN
        let select = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param")
        XCTAssertNoThrow(try select.bind("Alex", for: ":param"))
        XCTAssertTrue(try select.step())

        // THEN
        XCTAssertEqual(select.column(at: 0), 80)
    }

    func testBindByNameDictionary() throws {
        /// GIVEN
        try db.createTables()

        try db.prepare("INSERT INTO Users (Level, Name) VALUES (?, ?)")
            .bind(80, "Alex")
            .execute()

        // WHEN
        let select = try db.prepare("SELECT Level, Name FROM Users WHERE Name = :param")
        XCTAssertNoThrow(try select.bind([":param": "Alex"]))
        XCTAssertTrue(try select.step())

        // THEN
        XCTAssertEqual(select.column(at: 0), 80)
    }

    func testClearBinding() throws {
        /// GIVEN
        try db.createTables()

        let statement = try db.prepare("""
        INSERT INTO Users (Level, Name)
        VALUES (?, ?)
        """)

        try statement
            .bind(80, nil)
            .execute()

        try db.execute("DELETE FROM Users")

        // WHEN
        try statement
            .reset()
            .clearBindings()
            .bind("Alex", at: 1)
            .execute()

        // THEN
        let select = try db.prepare("SELECT Level, Name FROM Users")
        XCTAssertTrue(try select.step())
        XCTAssertEqual(select.column(at: 0) as Int?, nil)
        XCTAssertEqual(select.column(at: 1), "Alex")
    }

    // MARK: Step

    func testStep() throws {
        // GIVEN
        try db.createTables()
        try db.populateStore()

        // WHEN
        let statement = try db.prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")

        var objects = [User]()
        while try statement.step() {
            let user = User(
                name: statement.column(at: 0),
                level: statement.column(at: 1)
            )
            objects.append(user)
        }

        // THEN
        XCTAssertEqual(objects, [
            User(name: "Alice", level: 80),
            User(name: "Bob", level: 90)
        ])
    }

    // MARK: Misc

    func testColumnCount() throws {
        // GIVEN
        try db.createTables()
        let statement = try db.prepare("SELECT * FROM Users")

        // THEN
        XCTAssertEqual(statement.columnCount, 3)
    }

    func testColumnNameAtIndex() throws {
        // GIVEN
        try db.createTables()
        let statement = try db.prepare("SELECT * FROM Users")

        // THEN
        XCTAssertEqual(statement.columnName(at: 1), "Name")
    }
}

extension SQLConnection {
    func createTables() throws {
        try execute("""
        CREATE TABLE Users
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Name VARCHAR,
            Level INTEGER
        )
        """)
    }

    func populateStore() throws {
        let statement = try self.prepare("""
        INSERT INTO Users (Name, Level)
        VALUES (?, ?)
        """)

        try statement
            .bind("Alice", Int64(80))
            .execute()

        try statement.reset()

        try statement
            .bind("Bob", Int64(90))
            .execute()
    }
}
