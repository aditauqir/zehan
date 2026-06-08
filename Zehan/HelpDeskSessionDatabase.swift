//
//  HelpDeskSessionDatabase.swift
//  Zirn
//
//  Created by Codex on 6/7/26.
//

import Foundation
import SQLite3

final class HelpDeskSessionDatabase {
    private var database: OpaquePointer?
    private let vaultID: String
    private let databaseURL: URL

    init(vaultFolderURL: URL, vaultID: String) throws {
        self.vaultID = vaultID
        let folder = vaultFolderURL
            .appendingPathComponent(".zirn", isDirectory: true)
            .appendingPathComponent("HelpDesk", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        databaseURL = folder.appendingPathComponent("zirn-chat.sqlite")

        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw HelpDeskSessionDatabaseError.openFailed(message: lastErrorMessage)
        }

        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try createSchema()
        try scrubDatabase()
    }

    deinit {
        sqlite3_close(database)
    }

    func loadDatabase() throws -> HelpDeskDatabase {
        var conversations: [HelpDeskConversation] = []
        let sql = """
        SELECT id, title, created_at, updated_at
        FROM conversations
        WHERE vault_id = ?
        ORDER BY updated_at DESC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HelpDeskSessionDatabaseError.statementFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind([.text(vaultID)], to: statement)

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = columnString(statement, 0)
            conversations.append(
                HelpDeskConversation(
                    id: id,
                    title: columnString(statement, 1),
                    messages: try loadMessages(for: id),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                )
            )
        }

        return HelpDeskDatabase(vaultID: vaultID, conversations: conversations)
    }

    func replaceAll(with helpDeskDatabase: HelpDeskDatabase) throws {
        try transaction {
            try execute("DELETE FROM conversations WHERE vault_id = ?;", bindings: [.text(vaultID)])
            for conversation in helpDeskDatabase.conversations {
                try upsertConversation(conversation)
                for message in conversation.messages {
                    try insertMessage(message, conversationID: conversation.id)
                }
            }
        }
    }

    func upsertConversation(_ conversation: HelpDeskConversation) throws {
        try execute(
            """
            INSERT INTO conversations (id, vault_id, title, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(conversation.id),
                .text(vaultID),
                .text(conversation.title),
                .real(conversation.createdAt.timeIntervalSince1970),
                .real(conversation.updatedAt.timeIntervalSince1970)
            ]
        )
    }

    func deleteConversation(id: HelpDeskConversation.ID) throws {
        try execute(
            "DELETE FROM conversations WHERE id = ? AND vault_id = ?;",
            bindings: [.text(id), .text(vaultID)]
        )
    }

    func insertMessage(_ message: HelpDeskMessage, conversationID: HelpDeskConversation.ID) throws {
        try execute(
            """
            INSERT OR REPLACE INTO messages (id, conversation_id, role, content, attachment_name, created_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(message.id),
                .text(conversationID),
                .text(message.role.rawValue),
                .text(message.content),
                .nullableText(message.attachmentName),
                .real(message.createdAt.timeIntervalSince1970)
            ]
        )
    }

    func scrubDatabase() throws {
        try transaction {
            try execute("DELETE FROM messages WHERE conversation_id NOT IN (SELECT id FROM conversations);")
            try execute("DELETE FROM conversations WHERE TRIM(id) = '' OR TRIM(vault_id) = '';")
            try execute("UPDATE conversations SET title = 'New conversation' WHERE TRIM(title) = '';")
        }
    }

    private func createSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY NOT NULL,
                vault_id TEXT NOT NULL,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY NOT NULL,
                conversation_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                attachment_name TEXT,
                created_at REAL NOT NULL,
                FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS conversations_vault_updated_index ON conversations(vault_id, updated_at DESC);")
        try execute("CREATE INDEX IF NOT EXISTS messages_conversation_created_index ON messages(conversation_id, created_at ASC);")
    }

    private func loadMessages(for conversationID: HelpDeskConversation.ID) throws -> [HelpDeskMessage] {
        let sql = """
        SELECT id, role, content, attachment_name, created_at
        FROM messages
        WHERE conversation_id = ?
        ORDER BY created_at ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HelpDeskSessionDatabaseError.statementFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind([.text(conversationID)], to: statement)

        var messages: [HelpDeskMessage] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            messages.append(
                HelpDeskMessage(
                    id: columnString(statement, 0),
                    role: HelpDeskMessageRole(rawValue: columnString(statement, 1)) ?? .assistant,
                    content: columnString(statement, 2),
                    attachmentName: columnNullableString(statement, 3),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
                )
            )
        }
        return messages
    }

    private func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try work()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func execute(_ sql: String, bindings: [HelpDeskSQLiteBinding] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HelpDeskSessionDatabaseError.statementFailed(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                break
            }
            if stepResult == SQLITE_ROW {
                continue
            }
            throw HelpDeskSessionDatabaseError.statementFailed(message: lastErrorMessage)
        }
    }

    private func bind(_ bindings: [HelpDeskSQLiteBinding], to statement: OpaquePointer?) throws {
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch binding {
            case .text(let value):
                result = sqlite3_bind_text(statement, position, value, -1, HELP_DESK_SQLITE_TRANSIENT)
            case .nullableText(let value):
                if let value {
                    result = sqlite3_bind_text(statement, position, value, -1, HELP_DESK_SQLITE_TRANSIENT)
                } else {
                    result = sqlite3_bind_null(statement, position)
                }
            case .real(let value):
                result = sqlite3_bind_double(statement, position, value)
            }

            guard result == SQLITE_OK else {
                throw HelpDeskSessionDatabaseError.statementFailed(message: lastErrorMessage)
            }
        }
    }

    private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private func columnNullableString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, index)
        else { return nil }
        return String(cString: value)
    }

    private var lastErrorMessage: String {
        guard let database else { return "SQLite database is not open." }
        return String(cString: sqlite3_errmsg(database))
    }
}

private enum HelpDeskSQLiteBinding {
    case text(String)
    case nullableText(String?)
    case real(Double)
}

private enum HelpDeskSessionDatabaseError: LocalizedError {
    case openFailed(message: String)
    case statementFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message), .statementFailed(let message):
            return message
        }
    }
}

private let HELP_DESK_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
