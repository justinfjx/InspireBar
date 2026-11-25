import CoreGraphics
import Testing
@testable import InspireBarCore

struct MenuPanelPlacementTests {
    private let main = MenuPanelPlacement.Display(
        frame: CGRect(x: 0, y: 0, width: 1080, height: 1920),
        visibleFrame: CGRect(x: 0, y: 64, width: 1080, height: 1826))
    private let external = MenuPanelPlacement.Display(
        frame: CGRect(x: 1080, y: 585, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1080, y: 625, width: 1920, height: 1010))

    @Test func `the click display wins over a stale status window on a taller display`() throws {
        let panel = try #require(MenuPanelPlacement.frame(
            displays: [self.main, self.external],
            pointer: CGPoint(x: 2989, y: 1653),
            anchor: CGRect(x: 790, y: 1890, width: 89, height: 30),
            menuBarHeight: 30))
        #expect(self.external.visibleFrame.contains(panel))
        #expect(panel.maxY == self.external.visibleFrame.maxY - 6)
        #expect(panel.maxX == self.external.visibleFrame.maxX - 8)
        #expect(panel.size == MenuPanelPlacement.preferredSize)
    }

    @Test func `a short display with negative coordinates leaves room for the Dock and the whole panel`() throws {
        let small = MenuPanelPlacement.Display(
            frame: CGRect(x: -500, y: -460, width: 500, height: 460),
            visibleFrame: CGRect(x: -395, y: -435, width: 395, height: 405))
        let panel = try #require(MenuPanelPlacement.frame(
            displays: [self.main, small],
            pointer: CGPoint(x: -497, y: -12),
            anchor: CGRect(x: -89, y: 1890, width: 89, height: 30),
            menuBarHeight: 30))
        #expect(small.visibleFrame.contains(panel))
        #expect(panel.minX == small.visibleFrame.minX + 8)
        #expect(panel.minY == small.visibleFrame.minY + 8)
        #expect(panel.maxY == small.visibleFrame.maxY - 6)
        #expect(panel.width < MenuPanelPlacement.preferredSize.width)
        #expect(panel.height < MenuPanelPlacement.preferredSize.height)
    }

    @Test func `a revealed full screen menu bar still gets its own space`() throws {
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 576)
        let panel = try #require(MenuPanelPlacement.frame(
            displays: [.init(frame: bounds, visibleFrame: bounds)],
            pointer: CGPoint(x: 640, y: 569),
            anchor: nil,
            menuBarHeight: 30))
        #expect(panel.midX == 640)
        #expect(panel.maxY == 540)
        #expect(panel.minY == 8)
    }

    @Test func `keyboard showing the panel uses the status anchor instead of an unrelated mouse location`() throws {
        let panel = try #require(MenuPanelPlacement.frame(
            displays: [self.main, self.external],
            pointer: CGPoint(x: 400, y: 1000),
            anchor: CGRect(x: 1400, y: 1635, width: 80, height: 30),
            menuBarHeight: 30))
        #expect(self.external.visibleFrame.contains(panel))
        #expect(panel.midX == 1440)
    }

    @Test func `a click inside menu bar overflow opens the panel on that display`() throws {
        let panel = try #require(MenuPanelPlacement.frame(
            displays: [self.main, self.external],
            pointer: CGPoint(x: 1950, y: 1500),
            pointerIsClick: true,
            anchor: CGRect(x: 780, y: 1890, width: 100, height: 30),
            menuBarHeight: 30))
        #expect(self.external.visibleFrame.contains(panel))
        #expect(panel.midX == 1950)
    }
}
