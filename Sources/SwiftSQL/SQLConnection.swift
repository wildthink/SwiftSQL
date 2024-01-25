// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import SQLite3

/// A database connection.
///
/// When deallocated, the connection gets closed automatically.
///
/// # Concurrency
///
/// For more details about using multiple database connections to improve concurrency, please refer to the
/// [documentation](https://www.sqlite.org/isolation.html).
public final class SQLConnection {
    public private(set) var ref: OpaquePointer!
    let _hook: Hook // = .init() jmj

    /// Returns the last [INSERT row id](https://www.sqlite.org/c3ref/last_insert_rowid.html)
    /// of the database connection. Returns `0` if no successfull INSERT into rowid
    /// tables have ever occured on the connection.
    ///
    /// # Threading
    ///
    /// If a separate thread performs a new INSERT on the same database connection
    /// while the `lastInsertRowID` property is running and thus changes the last
    /// insert rowid, then the value returned by `lastInsertRowID` is unpredictable
    /// and might not equal either the old or the new last insert rowid.
    ///
    /// - note: As well as being set automatically as rows are inserted into database tables,
    /// the value returned by this function may be set explicitly.
    public var lastInsertRowID: Int64 {
        get { sqlite3_last_insert_rowid(ref) }
        set { sqlite3_set_last_insert_rowid(ref, newValue) }
    }

    /// [Opens](https://www.sqlite.org/c3ref/open.html) a new database connection
    /// with the given parameters. Throws an `SQLError` if it fails open a connection.
    ///
    /// - parameter url: Database URL.
    public convenience init(url: URL) throws {
        try self.init(location: .disk(url: url))
    }

    /// [Opens](https://www.sqlite.org/c3ref/open.html) a new database connection
    /// with the given parameters. Throws an `SQLError` if it fails open a connection.
    ///
    /// - parameter mode: Specifies whether open the database for reading, writing
    /// or both, and whether to create it on write. `.writable(create: true)` by default.
    /// - parameter options: See `SQLConnectionOptions` for more information.
    ///
    /// - note: See [SQLite: Result and Error Codes](https://www.sqlite.org/rescode.html)
    /// for more information.
    public init(
        location: Location,
        mode: Mode = .writable(create: true),
        options: Options = Options(),
        hook: Hook = .default
    ) throws {
        let path: String
        var flags: Int32 = 0

        _hook = hook

        switch mode {
        case .readonly:
            flags |= SQLITE_OPEN_READONLY
        case let .writable(create):
            flags |= SQLITE_OPEN_READWRITE
            if create {
                 flags |= SQLITE_OPEN_CREATE
            }
        }
        switch location {
        case let .disk(url):
            path = url.absoluteString
        case let .memory(name):
            path = name
            if name != ":memory:" {
                flags |= SQLITE_OPEN_MEMORY
            }
        case .temporary:
            path = ""
        }

        flags |= options.isSharedCacheEnabled ?
            SQLITE_OPEN_SHAREDCACHE :
            SQLITE_OPEN_PRIVATECACHE

        switch options.threadingMode {
        case .default:
            break // Do nothing
        case .multithreaded:
            flags |= SQLITE_OPEN_NOMUTEX
        case .serialized:
            flags |= SQLITE_OPEN_FULLMUTEX
        }

        try isOK(sqlite3_open_v2(path, &ref, flags, nil))
        
        _hook.registerHandlers(self)
    }

    deinit {
         try? close()
     }

    // MARK:
    /// [Executes](https://www.sqlite.org/c3ref/changes.html) to return the number of rows changed by the most recent statement.
    public var lastChangeCount: Int64 {
        if #available(macOS 12.3, *) {
            sqlite3_changes64(ref)
        } else {
            Int64(sqlite3_changes(ref))
        }
    }

    // MARK: Execute

    /// [Executes](https://www.sqlite.org/c3ref/exec.html) the given one-shot SQL statement.
    public func execute(_ sql: String) throws {
        try isOK(sqlite3_exec(ref, sql, nil, nil, nil))
    }

    // MARK: Prepare (Compile) Statements

    /// To execute an SQL statement, it must first be [compiled](https://www.sqlite.org/c3ref/prepare.html)
    /// into a byte-code program using one of these routines.
    ///
    /// If the database schema changes, instead of returning do, `step()` will
    /// automatically recompile the SQL statement and try to run it again.
    /// The nubmer of reties is limited.
    ///
    public func prepare(_ sql: String) throws -> SQLStatement {
        var ref: OpaquePointer!
        try isOK(sqlite3_prepare_v2(self.ref, sql, -1, &ref, nil))
        return SQLStatement(db: self, ref: ref)
    }

    // MARK: Closing

    /// [Closes](https://www.sqlite.org/c3ref/close.html) the connection.
    ///
    /// If `close()` is called with unfinalized prepared statements and/or
    /// unfinished backups, then the database connection becomes an unusable
    /// "zombie" which will automatically be destroyed when the last prepared
    /// statement is finalized or the last backup is finished.
    ///
    /// Applications should finalize all prepared statements, close all BLOB handles,
    /// and finish all backup objects associated with the connection object prior
    /// to attempting to close it. If close() is called on a database connection
    /// that still has outstanding prepared statements, BLOB handles, backup objects
    /// then it completes successfully and the deallocation of resources is deferred
    /// until all prepared statements, BLOB handles, and backup objects are also destroyed.
    ///
    /// If a connection is destroyed while a transaction is open, the transaction is
    /// automatically rolled back.
    public func close() throws {
        try isOK(sqlite3_close_v2(ref))
    }

    /// This function causes any pending database operation to [abort](https://www.sqlite.org/c3ref/interrupt.html)
    /// and return at its earliest opportunity.
    ///
    /// This routine is typically called in response to a user cancelling an
    /// operation where the user wants a long query operation to halt immediately.
    ///
    /// It is safe to call this routine from a thread different from the thread
    /// that is currently running the database operation. But it is not safe to
    /// call this routine with a database connection that is closed or might
    /// close before `interrupt()` returns.
    ///
    /// If an SQL operation is very nearly finished at the time when `interrupt()`
    /// is called, then it might not have an opportunity to be interrupted and
    /// might continue to completion.
    ///
    /// An SQL operation that is interrupted will fail with `.interrupted` error.
    /// If the interrupted SQL operation is an INSERT, UPDATE, or DELETE that is
    /// inside an explicit transaction, then the entire transaction will be rolled
    /// back automatically.
    public func interrupt() {
        sqlite3_interrupt(ref)
    }

    // MARK: Private

    @discardableResult
    func isOK(_ code: Int32) throws -> Int32 {
        guard let error = SQLError(code: code, db: ref) else { return code }
        throw error
    }
}

// MARK: - SQLConnection (Options)

public extension SQLConnection {
    /// Specifies the [location](https://www.sqlite.org/c3ref/open.html) where
    /// the database is stored.
    enum Location {
        /// Database stored on disk.
        case disk(url: URL)
        /// The database will be opened as an in-memory database. The database
        /// is named by the "filename" argument for the purposes of cache-sharing,
        /// if shared cache mode is enabled, but the "filename" is otherwise ignored.
        ///
        /// The default name is `:memory:` which creates a private, temporary
        /// in-memory database for the connection. This in-memory database will
        /// vanish when the database connection is closed.
        case memory(name: String = ":memory:")

        /// A private, temporary on-disk database will be created. This private
        /// database will be automatically deleted as soon as the database
        /// connection is closed.
        case temporary
    }

    /// The [mode](https://www.sqlite.org/c3ref/open.html) with which to open
    /// the database connection.
    enum Mode {
        /// The database is opened in read-only mode. If the database does not
        /// already exist, an error is returned.
        case readonly
        /// The database is opened for reading and writing if possible, or reading only
        /// if the file is write protected by the operating system. In either case the
        /// database must already exist, otherwise an error is returned.
        ///
        /// - parameter create: The database is created if it does not already exist.
        /// `true` by default.
        case writable(create: Bool = true)
    }

    /// The [options](https://www.sqlite.org/c3ref/open.html) with which to open
    /// the connection.
    struct Options {
        /// SQLite includes a special "shared-cache" mode (disabled by default)
        /// intended for use in embedded servers. If shared-cache mode is enabled
        /// and a process establishes multiple connections to the same database,
        /// the connections share a single data and schema cache. This can
        /// significantly reduce the quantity of memory and IO required by the system.
        ///
        /// [sharedcache.html](https://www.sqlite.org/sharedcache.html)
        public var isSharedCacheEnabled: Bool

        /// By default, uses `serialized` threading mode.
        public var threadingMode: ThreadingMode

        public init(isSharedCacheEnabled: Bool = false, threadingMode: ThreadingMode = .default) {
            self.isSharedCacheEnabled = isSharedCacheEnabled
            self.threadingMode = threadingMode
        }
    }

    /// Specifies a [threading mode](https://www.sqlite.org/threadsafe.html) for the connection
    enum ThreadingMode {
        /// Use the default theading mode configured when SQL was started.
        case `default`
        /// In this mode, SQLite can be safely used by multiple threads provided
        /// that no single database connection is used simultaneously in two or
        /// more threads.
        case multithreaded
        /// In serialized mode, SQLite can be safely used by multiple threads
        /// with no restriction.
        case serialized
    }
}
