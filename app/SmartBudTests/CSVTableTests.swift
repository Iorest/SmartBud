//
//  CSVTableTests.swift
//  SmartBudTests
//
//  Parser coverage for the import flow. Ragged or quoted CSV used to crash
//  the importer, so every shape it can receive is pinned here.
//

import Testing
import Foundation

@Suite("CSVTable")
struct CSVTableTests {

    @Test("Plain rows")
    func plainRows() throws {
        let table = try CSVTable(text: "date,amount,note\n2026-10-01,12.30,Lunch")
        #expect(table.rows == [["date", "amount", "note"], ["2026-10-01", "12.30", "Lunch"]])
    }

    @Test("Quoted commas stay in one field")
    func quotedComma() throws {
        let table = try CSVTable(text: "a,\"b,c\",d\n1,2,3")
        #expect(table.rows[0] == ["a", "b,c", "d"])
    }

    @Test("Escaped quotes")
    func escapedQuotes() throws {
        let table = try CSVTable(text: "\"say \"\"hi\"\"\",x")
        #expect(table.rows == [["say \"hi\"", "x"]])
    }

    @Test("CRLF and trailing newline")
    func crlf() throws {
        let table = try CSVTable(text: "a,b\r\n1,2\r\n")
        #expect(table.rows == [["a", "b"], ["1", "2"]])
    }

    @Test("Quoted newline stays in the field")
    func quotedNewline() throws {
        let table = try CSVTable(text: "\"line1\nline2\",x")
        #expect(table.rows == [["line1\nline2", "x"]])
    }

    @Test("Ragged rows are visible to callers")
    func raggedRows() throws {
        let table = try CSVTable(text: "a,b,c\n1,2\n3,4,5")
        #expect(table.columnCounts == [2, 3])
    }

    @Test("Unclosed quote throws")
    func unclosedQuote() {
        #expect(throws: CSVError.self) {
            _ = try CSVTable(text: "\"a,b")
        }
    }

    @Test("Empty input throws")
    func empty() {
        #expect(throws: CSVError.self) {
            _ = try CSVTable(text: "")
        }
    }
}
