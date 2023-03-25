import AppKit
import Foundation

enum UpdateLocationStrategy {
    struct AlignToTextCursor {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement
        ) -> (
            widgetFrame: CGRect,
            panelFrame: CGRect,
            tabFrame: CGRect,
            alignPanelTopToAnchor: Bool
        ) {
            guard let selectedRange: AXValue = try? editor
                .copyValue(key: kAXSelectedTextRangeAttribute),
                let rect: AXValue = try? editor.copyParameterizedValue(
                    key: kAXBoundsForRangeParameterizedAttribute,
                    parameters: selectedRange
                )
            else {
                return FixedToBottom().framesForWindows(
                    editorFrame: editorFrame,
                    mainScreen: mainScreen,
                    activeScreen: activeScreen
                )
            }
            var frame: CGRect = .zero
            let found = AXValueGetValue(rect, .cgRect, &frame)
            guard found else {
                return FixedToBottom().framesForWindows(
                    editorFrame: editorFrame,
                    mainScreen: mainScreen,
                    activeScreen: activeScreen
                )
            }
            return HorizontalMovable().framesForWindows(
                y: activeScreen.frame.height - frame.maxY,
                alignPanelTopToAnchor: nil,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen
            )
        }
    }

    struct FixedToBottom {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen
        ) -> (
            widgetFrame: CGRect,
            panelFrame: CGRect,
            tabFrame: CGRect,
            alignPanelTopToAnchor: Bool
        ) {
            return HorizontalMovable().framesForWindows(
                y: activeScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                alignPanelTopToAnchor: false,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen
            )
        }
    }

    struct HorizontalMovable {
        func framesForWindows(
            y: CGFloat,
            alignPanelTopToAnchor fixedAlignment: Bool?,
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen
        ) -> (
            widgetFrame: CGRect,
            panelFrame: CGRect,
            tabFrame: CGRect,
            alignPanelTopToAnchor: Bool
        ) {
            let maxY = max(
                y,
                activeScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                4 + mainScreen.frame.minY
            )
            let y = min(
                maxY,
                mainScreen.frame.maxY - 4,
                activeScreen.frame.height - editorFrame.minY - Style.widgetHeight - Style
                    .widgetPadding
            )

            let proposedAnchorFrameOnTheRightSide = CGRect(
                x: editorFrame.maxX - Style.widgetPadding - Style.widgetWidth,
                y: y,
                width: Style.widgetWidth,
                height: Style.widgetHeight
            )

            let proposedPanelX = proposedAnchorFrameOnTheRightSide.maxX + Style
                .widgetPadding * 2
            let putPanelToTheRight = mainScreen.frame.maxX > proposedPanelX + Style.panelWidth
            let alignPanelTopToAnchor = fixedAlignment ?? (y > activeScreen.frame.midY)

            if putPanelToTheRight {
                let anchorFrame = proposedAnchorFrameOnTheRightSide
                let panelFrame = CGRect(
                    x: proposedPanelX,
                    y: alignPanelTopToAnchor ? anchorFrame.maxY - Style.panelHeight : anchorFrame
                        .minY,
                    width: Style.panelWidth,
                    height: Style.panelHeight
                )
                let tabFrame = CGRect(
                    x: anchorFrame.origin.x,
                    y: alignPanelTopToAnchor
                        ? anchorFrame.minY - Style.widgetHeight - Style.widgetPadding
                        : anchorFrame.maxY + Style.widgetPadding,
                    width: Style.widgetWidth,
                    height: Style.widgetHeight
                )

                return (anchorFrame, panelFrame, tabFrame, alignPanelTopToAnchor)
            } else {
                let proposedAnchorFrameOnTheLeftSide = CGRect(
                    x: editorFrame.minX + Style.widgetPadding,
                    y: proposedAnchorFrameOnTheRightSide.origin.y,
                    width: Style.widgetWidth,
                    height: Style.widgetHeight
                )
                let proposedPanelX = proposedAnchorFrameOnTheLeftSide.minX - Style
                    .widgetPadding * 2 - Style.panelWidth
                let putAnchorToTheLeft = proposedPanelX > mainScreen.frame.minX

                if putAnchorToTheLeft {
                    let anchorFrame = proposedAnchorFrameOnTheLeftSide
                    let panelFrame = CGRect(
                        x: proposedPanelX,
                        y: alignPanelTopToAnchor ? anchorFrame.maxY - Style
                            .panelHeight : anchorFrame
                            .minY,
                        width: Style.panelWidth,
                        height: Style.panelHeight
                    )
                    let tabFrame = CGRect(
                        x: anchorFrame.origin.x,
                        y: alignPanelTopToAnchor
                            ? anchorFrame.minY - Style.widgetHeight - Style.widgetPadding
                            : anchorFrame.maxY + Style.widgetPadding,
                        width: Style.widgetWidth,
                        height: Style.widgetHeight
                    )
                    return (anchorFrame, panelFrame, tabFrame, alignPanelTopToAnchor)
                } else {
                    let anchorFrame = proposedAnchorFrameOnTheRightSide
                    let panelFrame = CGRect(
                        x: anchorFrame.maxX - Style.panelWidth,
                        y: alignPanelTopToAnchor ? anchorFrame.maxY - Style.panelHeight - Style
                            .widgetHeight - Style.widgetPadding : anchorFrame.maxY + Style
                            .widgetPadding,
                        width: Style.panelWidth,
                        height: Style.panelHeight
                    )
                    let tabFrame = CGRect(
                        x: anchorFrame.origin.x,
                        y: alignPanelTopToAnchor
                            ? anchorFrame.minY - Style.widgetHeight - Style.widgetPadding
                            : anchorFrame.maxY + Style.widgetPadding,
                        width: Style.widgetWidth,
                        height: Style.widgetHeight
                    )
                    return (anchorFrame, panelFrame, tabFrame, alignPanelTopToAnchor)
                }
            }
        }
    }
}
