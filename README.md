# SwiftSQL

<p align="left">
<img src="https://img.shields.io/badge/platforms-iOS%2C%20macOS%2C%20watchOS%2C%20tvOS-lightgrey.svg">
<img src="https://github.com/kean/SwiftSQL/workflows/CI/badge.svg">
</p>

**SwiftSQL** is a micro Swift [SQLite](https://www.sqlite.org/index.html) wrapper, solid and meticulously documented. It maps directly to the SQLite concepts and doesn't introduce anything beyond them. The entire library fits just under 300 lines of code, but gets you 80% there.

**SwiftSQLExt** introduces some basic conveniences on top of it.

<br/>

# Usage

### `SQLConnection`

To start reading or writing to a database, you need to open a connection.

```swift
let db = try SQLConnection(url: storeURL)
```

By default, the database is opened in readwrite mode and is created if it doesn't exist. `SQLConnection` has multiple options for opening the database.

### `SQLStatement`

An instance of `SQLStatement` represents a single SQL statement that has been compiled into binary form and is ready to be evaluated.

Think of each SQL statement as a separate computer program. The original SQL text is source code. A prepared statement object is the compiled object code. All SQL must be converted into a prepared statement before it can be run.

#### Lifecycle

The life-cycle of a prepared statement object usually goes like this:

1. Create the prepared statement object using a connection:

```swift
let statement = try db.prepare("""
INSERT INTO Users (Name, Surname)
VALUES (?, ?)
""")
```

> Once you compiled the statement, use `statement.info` to get additional information about it.

2. Bind values to parameters using one of the `bind()` methods. The provided values must be one of the data types supported by SQLite (see `SQLDataType` for more info)

```swift
try statement.bind("John", "Appleseed")
```

3. Execute the statement.

```swift
// Use `execute()` to execute a statement
try statement.execute()

// If the statement returns multiple SQL rows, you can step in a loop
// and use `column()` family of methods to retrieve values for the current row. 
while try statement.step() {
    let name: String = statement.column(at: 0)
}
```

4. (Optional) To reuse the compiled statementt, reset it and go back to step 2,
do this zero or more times.

```swift
try statement.reset()
```

The compiled statement is going to be automatically destroyed when the
`SQLStatement` object gets deallocated.

#### Chaining

All of the methods outlined in the previous section are chainable:

```swift
try db.prepare("INSERT INTO Users (Name) VALUES (?)")
    .bind("Alex")
    .execute()
```

### `SQLDataType`

`SQLDataType` makes it possible to use native `Swift` types to work with SQLite. Supported types:

- `Int`
- `Int32`
- `Int64`
- `String`
- `Data`

> To add support for custom data types, like `Bool` or `Date`, see [Advanced Usage Guide](https://github.com/kean/SwiftSQL/blob/0.1.0/Docs/advanced-usage-guide.md)

# Extensions

**SwiftSQLExt** introduces some basic conveniences on top the core framework.

### Mapping Rows

Add conformance to `SQLRowDecodable` to use convenience APIs for converting rows into your model entities.

```swift
// Fetch all of the rows
let users = try db
    .prepare("SELECT Name, Level FROM Users ORDER BY Level ASC")
    .rows(User.self)
    
// Or only the next row
statement.row(User.self)

// Or the next N rows
statement.rows(User.self, count: 50)
```

# Minimum Requirements

| SwiftSQL          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| SwiftSQL 0.1      | Swift 5.2       | Xcode 11.3      | iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0  |

# License

SwiftSQL is available under the MIT license. See the LICENSE file for more info.

