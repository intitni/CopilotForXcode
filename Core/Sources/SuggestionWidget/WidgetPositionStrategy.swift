import AppKit
import Foundation

struct WidgetLocation {
    struct PanelLocation {
        var frame: CGRect
        var alignPanelTop: Bool
    }

    var widgetFrame: CGRect
    var tabFrame: CGRect
    var defaultPanelLocation: PanelLocation
    var suggestionPanelLocation: PanelLocation?
}

enum UpdateLocationStrategy {
    struct AlignToTextCursor {
        func framesForWindows(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement,
            preferredInsideEditorMinWidth: Double = UserDefaults.shared
                .value(for: \.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
        ) -> WidgetLocation {
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
        ) -> WidgetLocation {
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
        ) -> WidgetLocation {
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

                return .init(
                    widgetFrame: anchorFrame,
                    tabFrame: tabFrame,
                    defaultPanelLocation: .init(
                        frame: panelFrame,
                        alignPanelTop: alignPanelTopToAnchor
                    ),
                    suggestionPanelLocation: nil
                )
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
                    return .init(
                        widgetFrame: anchorFrame,
                        tabFrame: tabFrame,
                        defaultPanelLocation: .init(
                            frame: panelFrame,
                            alignPanelTop: alignPanelTopToAnchor
                        ),
                        suggestionPanelLocation: nil
                    )
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
                    return .init(
                        widgetFrame: anchorFrame,
                        tabFrame: tabFrame,
                        defaultPanelLocation: .init(
                            frame: panelFrame,
                            alignPanelTop: alignPanelTopToAnchor
                        ),
                        suggestionPanelLocation: nil
                    )
                }
            }
        }
    }

    struct NearbyTextCursor {
        func framesForSuggestionWindow(
            editorFrame: CGRect,
            mainScreen: NSScreen,
            activeScreen: NSScreen,
            editor: AXUIElement,
            completionPanel: AXUIElement?
        ) -> WidgetLocation.PanelLocation? {
            guard let selectionFrame = UpdateLocationStrategy
                .getSelectionFirstLineFrame(editor: editor) else { return nil }

            let proposedY = mainScreen.frame.height - selectionFrame.maxY
            let proposedX = selectionFrame.maxX - 40
            let maxY = max(
                proposedY,
                mainScreen.frame.height - editorFrame.maxY,
                4 + activeScreen.frame.minY
            )
            let y = min(
                maxY,
                activeScreen.frame.maxY - 4,
                mainScreen.frame.height - editorFrame.minY
            )
            print(y, activeScreen.frame.minY, activeScreen.frame.maxY)
            let alignPanelTopToAnchor = y - Style.panelHeight >= activeScreen.frame.minY

            if let completionPanel, let completionPanelRect = completionPanel.rect {
                return .init(
                    frame: completionPanelRect,
                    alignPanelTop: alignPanelTopToAnchor
                )
            } else {
                if alignPanelTopToAnchor {
                    // case: present below selection
                    return .init(
                        frame: .init(
                            x: proposedX,
                            y: y - Style.panelHeight,
                            width: Style.inlineSuggestionMinWidth,
                            height: Style.panelHeight
                        ),
                        alignPanelTop: alignPanelTopToAnchor
                    )
                } else {
                    // case: present above selection
                    return .init(
                        frame: .init(
                            x: proposedX,
                            y: y + selectionFrame.height,
                            width: Style.inlineSuggestionMinWidth,
                            height: Style.panelHeight
                        ),
                        alignPanelTop: alignPanelTopToAnchor
                    )
                }
            }
        }
    }

    /// Get the frame of the selection.
    static func getSelectionFrame(editor: AXUIElement) -> CGRect? {
        guard let selectedRange: AXValue = try? editor
            .copyValue(key: kAXSelectedTextRangeAttribute),
            let rect: AXValue = try? editor.copyParameterizedValue(
                key: kAXBoundsForRangeParameterizedAttribute,
                parameters: selectedRange
            )
        else {
            return nil
        }
        var selectionFrame: CGRect = .zero
        let found = AXValueGetValue(rect, .cgRect, &selectionFrame)
        guard found else { return nil }
        return selectionFrame
    }

    /// Get the frame of the first line of the selection.
    static func getSelectionFirstLineFrame(editor: AXUIElement) -> CGRect? {
        // Find selection range rect
        guard let selectedRange: AXValue = try? editor
            .copyValue(key: kAXSelectedTextRangeAttribute),
            let rect: AXValue = try? editor.copyParameterizedValue(
                key: kAXBoundsForRangeParameterizedAttribute,
                parameters: selectedRange
            )
        else {
            return nil
        }
        var selectionFrame: CGRect = .zero
        let found = AXValueGetValue(rect, .cgRect, &selectionFrame)
        guard found else { return nil }

        var firstLineRange: CFRange = .init()
        let foundFirstLine = AXValueGetValue(selectedRange, .cfRange, &firstLineRange)
        firstLineRange.length = 0
        if foundFirstLine,
           let firstLineSelectionRange = AXValueCreate(.cfRange, &firstLineRange),
           let firstLineRect: AXValue = try? editor.copyParameterizedValue(
               key: kAXBoundsForRangeParameterizedAttribute,
               parameters: firstLineSelectionRange
           )
        {
            var firstLineFrame: CGRect = .zero
            let foundFirstLineFrame = AXValueGetValue(firstLineRect, .cgRect, &firstLineFrame)
            if foundFirstLineFrame {
                selectionFrame = firstLineFrame
            }
        }

        return selectionFrame
    }
}

