import AppKit
import Foundation

// MARK: - State

public extension AXUIElement {
    /// Set global timeout in seconds.
    static func setGlobalMessagingTimeout(_ timeout: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
    }

    /// Set timeout in seconds for this element.
    func setMessagingTimeout(_ timeout: Float) {
        AXUIElementSetMessagingTimeout(self, timeout)
    }

    func identifier() throws -> String {
        (try? copyValue(key: kAXIdentifierAttribute)) ?? ""
    }

    func value() throws -> String {
        (try? copyValue(key: kAXValueAttribute)) ?? ""
    }

    func title() throws -> String {
        (try? copyValue(key: kAXTitleAttribute)) ?? ""
    }

    func role() throws -> String {
        (try? copyValue(key: kAXRoleAttribute)) ?? ""
    }

    func doubleValue() throws -> Double {
        (try? copyValue(key: kAXValueAttribute)) ?? 0.0
    }

    func document() throws -> String? {
        try? copyValue(key: kAXDocumentAttribute)
    }

    /// Label in Accessibility Inspector.
    func description() throws -> String {
        (try? copyValue(key: kAXDescriptionAttribute)) ?? ""
    }

    /// Type in Accessibility Inspector.
    func roleDescription() throws -> String {
        (try? copyValue(key: kAXRoleDescriptionAttribute)) ?? ""
    }

    func label() throws -> String {
        (try? copyValue(key: kAXLabelValueAttribute)) ?? ""
    }

    func isSourceEditor() throws -> Bool {
        try description() == "Source Editor"
    }

    func selectedTextRange() throws -> ClosedRange<Int>? {
        guard let value: AXValue = try copyValue(key: kAXSelectedTextRangeAttribute)
        else { return nil }
        var range: CFRange = .init(location: 0, length: 0)
        if AXValueGetValue(value, .cfRange, &range) {
            return range.location...(range.location + range.length)
        }
        return nil
    }

    func isFocused() throws -> Bool {
        try copyValue(key: kAXFocusedAttribute) ?? false
    }

    func isEnabled() throws -> Bool {
        try copyValue(key: kAXEnabledAttribute) ?? false
    }

    func isHidden() throws -> Bool {
        try copyValue(key: kAXHiddenAttribute) ?? false
    }
}

// MARK: - Rect

public extension AXUIElement {
    func position() throws -> CGPoint? {
        guard let value: AXValue = try copyValue(key: kAXPositionAttribute)
        else { return nil }
        var point: CGPoint = .zero
        if AXValueGetValue(value, .cgPoint, &point) {
            return point
        }
        return nil
    }

    func size() throws -> CGSize? {
        guard let value: AXValue = try copyValue(key: kAXSizeAttribute)
        else { return nil }
        var size: CGSize = .zero
        if AXValueGetValue(value, .cgSize, &size) {
            return size
        }
        return nil
    }

    func rect() throws -> CGRect? {
        guard let position = try position(), let size = try size() else { return nil }
        return .init(origin: position, size: size)
    }
    
    func isFullScreen() throws -> Bool {
        try copyValue(key: "AXFullScreen") ?? false
    }
}

// MARK: - Relationship

public extension AXUIElement {
    func focusedElement(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXFocusedUIElementAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }

    func sharedFocusElements(messagingTimeout: Float? = nil) throws -> [AXUIElement] {
        let elements: [AXUIElement] = try copyValue(key: kAXChildrenAttribute) ?? []
        if let messagingTimeout {
            elements.forEach { $0.setMessagingTimeout(messagingTimeout) }
        }
        return elements
    }

    func window(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXWindowAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }

    func windows(messagingTimeout: Float? = nil) throws -> [AXUIElement] {
        let elements: [AXUIElement] = try copyValue(key: kAXWindowsAttribute) ?? []
        if let messagingTimeout {
            elements.forEach { $0.setMessagingTimeout(messagingTimeout) }
        }
        return elements
    }

    func focusedWindow(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXFocusedWindowAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }

    func topLevelElement(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXTopLevelUIElementAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }

    func rows(messagingTimeout: Float? = nil) throws -> [AXUIElement] {
        let elements: [AXUIElement] = try copyValue(key: kAXRowsAttribute) ?? []
        if let messagingTimeout {
            elements.forEach { $0.setMessagingTimeout(messagingTimeout) }
        }
        return elements
    }

    func parent(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXParentAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }

    func children(messagingTimeout: Float? = nil) throws -> [AXUIElement] {
        let elements: [AXUIElement] = try copyValue(key: kAXChildrenAttribute) ?? []
        if let messagingTimeout {
            elements.forEach { $0.setMessagingTimeout(messagingTimeout) }
        }
        return elements
    }

    func menuBar(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXMenuBarAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }

    func visibleChildren(messagingTimeout: Float? = nil) throws -> [AXUIElement] {
        let elements: [AXUIElement] = try copyValue(key: kAXVisibleChildrenAttribute) ?? []
        if let messagingTimeout {
            elements.forEach { $0.setMessagingTimeout(messagingTimeout) }
        }
        return elements
    }

    func child(
        identifier: String? = nil,
        title: String? = nil,
        role: String? = nil,
        messagingTimeout: Float? = nil
    ) throws -> AXUIElement? {
        for child in try children() {
            let match = try {
                if let identifier, try child.identifier() != identifier { return false }
                if let title, try child.title() != title { return false }
                if let role, try child.role() != role { return false }
                return true
            }()
            if match {
                if let messagingTimeout {
                    child.setMessagingTimeout(messagingTimeout)
                }
                return child
            }
        }

        for child in try children() {
            if let target = try child.child(
                identifier: identifier,
                title: title,
                role: role
            ) {
                if let messagingTimeout {
                    target.setMessagingTimeout(messagingTimeout)
                }
                return target
            }
        }

        return nil
    }

    func children(
        messagingTimeout: Float? = nil,
        where match: (AXUIElement) -> Bool
    ) throws -> [AXUIElement] {
        var all = [AXUIElement]()
        for child in try children() {
            if match(child) { all.append(child) }
        }
        for child in try children() {
            try all.append(contentsOf: child.children(where: match))
        }
        if let messagingTimeout {
            all.forEach { $0.setMessagingTimeout(messagingTimeout) }
        }
        return all
    }

    func firstParent(
        messagingTimeout: Float? = nil,
        where match: (AXUIElement) -> Bool
    ) throws -> AXUIElement? {
        guard let parent = try parent() else { return nil }
        if match(parent) {
            if let messagingTimeout {
                parent.setMessagingTimeout(messagingTimeout)
            }
            return parent
        }
        return try parent.firstParent(messagingTimeout: messagingTimeout, where: match)
    }

    func firstChild(
        messagingTimeout: Float? = nil,
        where match: (AXUIElement) -> Bool
    ) throws -> AXUIElement? {
        for child in try children() {
            if match(child) {
                if let messagingTimeout {
                    child.setMessagingTimeout(messagingTimeout)
                }
                return child
            }
        }
        for child in try children() {
            if let target = try child.firstChild(where: match) {
                if let messagingTimeout {
                    target.setMessagingTimeout(messagingTimeout)
                }
                return target
            }
        }
        return nil
    }

    func visibleChild(identifier: String, messagingTimeout: Float? = nil) -> AXUIElement? {
        do {
            for child in try visibleChildren() {
                if try child.identifier() == identifier {
                    if let messagingTimeout {
                        child.setMessagingTimeout(messagingTimeout)
                    }
                    return child
                }
                if let target = child.visibleChild(identifier: identifier) {
                    if let messagingTimeout {
                        target.setMessagingTimeout(messagingTimeout)
                    }
                    return target
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    func verticalScrollBar(messagingTimeout: Float? = nil) throws -> AXUIElement? {
        let element: AXUIElement? = try copyValue(key: kAXVerticalScrollBarAttribute)
        if let messagingTimeout {
            element?.setMessagingTimeout(messagingTimeout)
        }
        return element
    }
}

// MARK: - Helper

public extension AXUIElement {
    func copyValue<T>(key: String, ofType _: T.Type = T.self) throws -> T {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, key as CFString, &value)
        if error == .success, let value = value as? T {
            return value
        }
        throw error
    }

    func copyParameterizedValue<T>(
        key: String,
        parameters: AnyObject,
        ofType _: T.Type = T.self
    ) throws -> T {
        var value: AnyObject?
        let error = AXUIElementCopyParameterizedAttributeValue(
            self,
            key as CFString,
            parameters as CFTypeRef,
            &value
        )
        if error == .success, let value = value as? T {
            return value
        }
        throw error
    }
}

extension AXError: Error {}

