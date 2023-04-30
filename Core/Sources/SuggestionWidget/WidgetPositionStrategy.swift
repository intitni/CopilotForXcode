import AppKit
import Foundation

enum UpdateLocationStrategy {
    struct AlignToTextCursor {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement,
            preferredInsideEditorMinWidth: Double = UserDefaults.shared
                .value(for: \.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
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
                y: mainScreen.frame.height - frame.maxY,
                alignPanelTopToAnchor: nil,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen,
                preferredInsideEditorMinWidth: preferredInsideEditorMinWidth
            )
        }
    }

    struct FixedToBottom {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            preferredInsideEditorMinWidth: Double = UserDefaults.shared
                .value(for: \.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
        ) -> (
            widgetFrame: CGRect,
            panelFrame: CGRect,
            tabFrame: CGRect,
            alignPanelTopToAnchor: Bool
        ) {
            return HorizontalMovable().framesForWindows(
                y: mainScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                alignPanelTopToAnchor: false,
                editorFrame: editorFrame,
                mainScreen: mainScreen,
                activeScreen: activeScreen,
                preferredInsideEditorMinWidth: preferredInsideEditorMinWidth
            )
        }
    }

    struct HorizontalMovable {
        func framesForWindows(
            y: CGFloat,
            alignPanelTopToAnchor fixedAlignment: Bool?,
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            preferredInsideEditorMinWidth: Double
        ) -> (
            widgetFrame: CGRect,
            panelFrame: CGRect,
            tabFrame: CGRect,
            alignPanelTopToAnchor: Bool
        ) {
            let maxY = max(
                y,
                mainScreen.frame.height - editorFrame.maxY + Style.widgetPadding,
                4 + activeScreen.frame.minY
            )
            let y = min(
                maxY,
                activeScreen.frame.maxY - 4,
                mainScreen.frame.height - editorFrame.minY - Style.widgetHeight - Style
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
            let putPanelToTheRight = {
                if editorFrame.size.width >= preferredInsideEditorMinWidth { return false }
                return activeScreen.frame.maxX > proposedPanelX + Style.panelWidth
            }()
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
                let putAnchorToTheLeft = {
                    if editorFrame.size.width >= preferredInsideEditorMinWidth {
                        if editorFrame.maxX <= activeScreen.frame.maxX {
                            return false
                        }
                    }
                    return proposedPanelX > activeScreen.frame.minX
                }()

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
                        x: anchorFrame.minX - Style.widgetPadding - Style.widgetWidth,
                        y: anchorFrame.origin.y,
                        width: Style.widgetWidth,
                        height: Style.widgetHeight
                    )
                    return (anchorFrame, panelFrame, tabFrame, alignPanelTopToAnchor)
                }
            }
        }
    }
}
