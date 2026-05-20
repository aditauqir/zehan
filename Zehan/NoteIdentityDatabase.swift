//
//  NoteIdentityDatabase.swift
//  Zirn
//
//  Created by Codex on 5/20/26.
//

import Foundation
import SQLite3

final class NoteIdentityDatabase {
    private var database: OpaquePointer?
    private let databaseURL: URL

    init(vaultFolderURL: URL) throws {
        let supportFolder = vaultFolderURL.appendingPathComponent(".zirn", isDirectory: true)
        try FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        databaseURL = supportFolder.appendingPathComponent("note-identities.sqlite")

        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw IdentityDatabaseError.openFailed(message: lastErrorMessage)
        }

        try execute(
            """
            CREATE TABLE IF NOT EXISTS note_identities (
                note_id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                file_name TEXT NOT NULL UNIQUE,
                updated_at REAL NOT NULL
            );
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS note_identities_title_index ON note_identities(title);")
    }

    deinit {
        sqlite3_close(database)
    }

    func noteID(forFileName fileName: String) -> String? {
        scalarString(
            sql: "SELECT note_id FROM note_identities WHERE file_name = ? LIMIT 1;",
            bindings: [.text(fileName)]
        )
    }

    func fileName(forNoteID noteID: String) -> String? {
        scalarString(
            sql: "SELECT file_name FROM note_identities WHERE note_id = ? LIMIT 1;",
            bindings: [.text(noteID)]
        )
    }

    func upsert(noteID: String, title: String, fileName: String, updatedAt: Date) throws {
        try execute(
            """
            INSERT INTO note_identities (note_id, title, file_name, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(note_id) DO UPDATE SET
                title = excluded.title,
                file_name = excluded.file_name,
                updated_at = excluded.updated_at;
            """,
            bindings: [.text(noteID), .text(title), .text(fileName), .real(updatedAt.timeIntervalSince1970)]
        )
    }

    func remove(noteID: String) throws {
        try execute("DELETE FROM note_identities WHERE note_id = ?;", bindings: [.text(noteID)])
    }

    private func execute(_ sql: String, bindings: [SQLiteBinding] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw IdentityDatabaseError.statementFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw IdentityDatabaseError.statementFailed(message: lastErrorMessage)
        }
    }

    private func scalarString(sql: String, bindings: [SQLiteBinding]) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        guard (try? bind(bindings, to: statement)) != nil else {
            return nil
        }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0)
        else {
            return nil
        }

        return String(cString: value)
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer?) throws {
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch binding {
            case .text(let value):
                result = sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
            case .real(let value):
                result = sqlite3_bind_double(statement, position, value)
            }

            guard result == SQLITE_OK else {
                throw IdentityDatabaseError.statementFailed(message: lastErrorMessage)
            }
        }
    }

    private var lastErrorMessage: String {
        guard let database else { return "SQLite database is not open." }
        return String(cString: sqlite3_errmsg(database))
    }
}

private enum SQLiteBinding {
    case text(String)
    case real(Double)
}

private enum IdentityDatabaseError: LocalizedError {
    case openFailed(message: String)
    case statementFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message), .statementFailed(let message):
            return message
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
