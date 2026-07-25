import Testing
import Foundation
@testable import FoxMillWoods

/// The receipt parser turns Vision's recognized lines into merchant / date / total.
/// OCR itself needs a camera, but the heuristics are a pure function of the text
/// lines — so we exercise them directly against representative receipts.
struct ReceiptOCRTests {

    @Test("Pulls merchant, date, and grand total from a typical receipt")
    func parsesTypicalReceipt() {
        let lines = [
            "COSTCO WHOLESALE #1071",
            "1071 STERLING BLVD",
            "08/28/2026",
            "KIRKLAND WATER      12.99",
            "PAPER PLATES         8.49",
            "SUBTOTAL           131.10",
            "TAX                 11.50",
            "TOTAL              142.60",
        ]
        let r = ReceiptOCR.parse(lines: lines)
        #expect(r.merchant == "COSTCO WHOLESALE #1071")
        #expect(r.total == Decimal(string: "142.60"))
        #expect(r.fieldsFound == 3)

        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: r.date!)
        #expect(comps.year == 2026 && comps.month == 8 && comps.day == 28)
    }

    @Test("Prefers the grand total over the subtotal")
    func prefersTotalOverSubtotal() {
        let lines = ["Party City", "SUBTOTAL 80.00", "TOTAL 88.20"]
        #expect(ReceiptOCR.parse(lines: lines).total == Decimal(string: "88.20"))
    }

    @Test("Falls back to the largest amount when no total label is present")
    func fallsBackToLargestAmount() {
        let lines = ["SAFEWAY", "Milk 3.49", "Soda 6.25", "Chips 4.10"]
        #expect(ReceiptOCR.parse(lines: lines).total == Decimal(string: "6.25"))
    }

    @Test("Skips address/amount lines when choosing the merchant")
    func merchantSkipsNoise() {
        let lines = ["12.99", "Trader Joe's", "TOTAL 12.99"]
        #expect(ReceiptOCR.parse(lines: lines).merchant == "Trader Joe's")
    }

    @Test("Empty input yields an empty parse")
    func emptyInput() {
        let r = ReceiptOCR.parse(lines: [])
        #expect(r.merchant == nil && r.date == nil && r.total == nil && r.fieldsFound == 0)
    }
}
