import Foundation
import Testing
@testable import InspireBarCore

struct MenuBarLayoutTests {
    @Test func `a placed token moves within its line without duplication`() {
        let layout = MenuBarLayout(lines: [[.icon, .balance, .percent]])
        let source = MenuBarLayoutPosition(line: 0, index: 0)
        let target = MenuBarLayoutPosition(line: 0, index: 3)
        #expect(layout.inserting(.icon, at: target, from: source).lines == [[.balance, .percent, .icon]])
        #expect(layout.inserting(.weeklyBill, at: target, from: source) == layout)
    }

    @Test func `a token moves to the second line and can be joined again`() {
        let layout = MenuBarLayout.defaultLayout.addingLineBreak()
        #expect(layout.lines == [[.icon], [.balance]])
        let source = MenuBarLayoutPosition(line: 0, index: 0)
        let target = MenuBarLayoutPosition(line: 1, index: 1)
        #expect(layout.inserting(.icon, at: target, from: source).lines == [[.balance, .icon]])
        #expect(layout.removingLineBreak() == .defaultLayout)
    }

    @Test func `an empty second line can be filled by dropping a palette chip`() {
        let layout = MenuBarLayout.iconOnly.addingLineBreak()
        #expect(layout.lines == [[.icon], []])
        let target = MenuBarLayoutPosition(line: 1, index: 0)
        #expect(layout.inserting(.estimatedRemaining, at: target).lines == [[.icon], [.estimatedRemaining]])
    }

    @Test func `switching to two lines keeps the ticket with its balance and adds the reset countdown`() {
        let layout = MenuBarLayout.defaultLayout.withTwoLines()
        #expect(layout.lines == [[.icon, .balance], [.resetCountdown]])
        #expect(layout.removingLineBreak().lines == [[.icon, .balance, .resetCountdown]])
        #expect(layout.removingLineBreak().withTwoLines() == layout)
        #expect(MenuBarLayout.iconOnly.withTwoLines().lines == [[.icon], [.balance]])
    }

    @Test func `switching a custom layout to two lines reuses its existing values in order`() {
        let layout = MenuBarLayout(lines: [[.icon, .weeklyBill, .currentRate, .estimatedRemaining]])
        let stacked = layout.withTwoLines()
        #expect(stacked.lines == [[.icon, .weeklyBill], [.currentRate, .estimatedRemaining]])
        #expect(stacked.removingLineBreak() == layout)
        #expect(stacked.withTwoLines() == stacked)
    }

    @Test func `a layout keeps one visible value after removal`() {
        let layout = MenuBarLayout(lines: [[.icon, .separator]])
        let source = MenuBarLayoutPosition(line: 0, index: 0)
        #expect(layout.removing(at: source) == layout)
        #expect(MenuBarLayout(lines: [[.separator], []]) == .defaultLayout)
    }

    @Test func `custom layouts persist their rows and presets remain identifiable`() throws {
        let custom = MenuBarLayout(lines: [[.balance, .weeklyBill], [.currentRate, .exhaustTime]])
        let encoded = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(MenuBarLayout.self, from: encoded)
        #expect(decoded == custom)
        #expect(MenuBarLayoutPreset.matching(decoded) == .custom)
        #expect(MenuBarLayoutPreset.matching(.iconOnly) == .iconOnly)
    }
}
