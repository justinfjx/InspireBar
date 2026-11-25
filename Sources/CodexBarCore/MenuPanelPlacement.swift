import CoreGraphics

package enum MenuPanelPlacement {
    package struct Display {
        package let frame: CGRect
        package let visibleFrame: CGRect

        package init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame.intersection(frame)
        }

        fileprivate func menuBarBottom(height: CGFloat) -> CGFloat {
            min(self.visibleFrame.maxY, self.frame.maxY - height)
        }

        fileprivate func containsMenuBarPoint(_ point: CGPoint, height: CGFloat) -> Bool {
            point.x >= self.frame.minX && point.x < self.frame.maxX
                && point.y >= self.menuBarBottom(height: height) - 1 && point.y <= self.frame.maxY
        }
    }

    package static let preferredSize = CGSize(width: 396, height: 541)
    private static let screenInset: CGFloat = 8
    private static let menuGap: CGFloat = 6

    /// Displays are ordered with the preferred fallback first. A menu-bar click takes precedence
    /// over the status button's proxy frame, which may belong to a different display or be offscreen.
    package static func frame(
        displays: [Display],
        pointer: CGPoint?,
        pointerIsClick: Bool = false,
        anchor: CGRect?,
        menuBarHeight: CGFloat)
        -> CGRect?
    {
        let displays = displays.filter { !$0.visibleFrame.isEmpty }
        let anchorCenter = anchor.flatMap { $0.isEmpty ? nil : CGPoint(x: $0.midX, y: $0.midY) }
        let pointerDisplay = pointer.flatMap { point in
            displays.first {
                $0.containsMenuBarPoint(point, height: menuBarHeight) || (pointerIsClick && $0.frame.contains(point))
            }
        }
        let anchorDisplay = anchorCenter.flatMap { point in
            displays.first { $0.containsMenuBarPoint(point, height: menuBarHeight) }
        }

        guard let display = pointerDisplay ?? anchorDisplay ?? displays.first else { return nil }
        let visible = display.visibleFrame
        let top = display.menuBarBottom(height: menuBarHeight) - self.menuGap
        let width = min(self.preferredSize.width, visible.width - 2 * self.screenInset)
        let height = min(self.preferredSize.height, top - visible.minY - self.screenInset)
        guard width > 0, height > 0 else { return nil }

        let anchorOnDisplay = anchorDisplay?.frame == display.frame
        let anchorContainsPointer = pointer.map { anchor?.insetBy(dx: -2, dy: -2).contains($0) == true } ?? false
        let centerX = if anchorOnDisplay, pointerDisplay == nil || anchorContainsPointer, let anchorCenter {
            anchorCenter.x
        } else if pointerDisplay != nil, let pointer {
            pointer.x
        } else {
            visible.maxX - self.screenInset - width / 2
        }

        let left = visible.minX + self.screenInset
        let right = visible.maxX - self.screenInset - width
        let x = min(max(left, centerX - width / 2), right)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}
