import AppKit
import Foundation

public extension AXUIElement {
    var identifier: String {
        (try? copyValue(key: kAXIdentifierAttribute)) ?? ""
    }

    var value: String {
        (try? copyValue(key: kAXValueAttribute)) ?? ""
    }
    
    var document: String? {
        try? copyValue(key: kAXDocumentAttribute)
    }

    var focusedElement: AXUIElement? {
        try? copyValue(key: kAXFocusedUIElementAttribute)
    }

    var description: String {
        (try? copyValue(key: kAXDescriptionAttribute)) ?? ""
    }

    var selectedTextRange: Range<Int>? {
        guard let value: AXValue = try? copyValue(key: kAXSelectedTextRangeAttribute)
        else { return nil }
        var range: CFRange = .init(location: 0, length: 0)
        if AXValueGetValue(value, .cfRange, &range) {
            return Range(.init(location: range.location, length: range.length))
        }
        return nil
    }

    var sharedFocusElements: [AXUIElement] {
        (try? copyValue(key: kAXChildrenAttribute)) ?? []
    }

    var window: AXUIElement? {
        try? copyValue(key: kAXWindowAttribute)
    }
    
    var windows: [AXUIElement] {
        (try? copyValue(key: kAXWindowsAttribute)) ?? []
    }

    var focusedWindow: AXUIElement? {
        try? copyValue(key: kAXFocusedWindowAttribute)
    }

    var topLevelElement: AXUIElement? {
        try? copyValue(key: kAXTopLevelUIElementAttribute)
    }

    var rows: [AXUIElement] {
        (try? copyValue(key: kAXRowsAttribute)) ?? []
    }

    var parent: AXUIElement? {
        try? copyValue(key: kAXParentAttribute)
    }

    var children: [AXUIElement] {
        (try? copyValue(key: kAXChildrenAttribute)) ?? []
    }

    var visibleChildren: [AXUIElement] {
        (try? copyValue(key: kAXVisibleChildrenAttribute)) ?? []
    }

    var isFocused: Bool {
        (try? copyValue(key: kAXFocusedAttribute)) ?? false
    }

    var isEnabled: Bool {
        (try? copyValue(key: kAXEnabledAttribute)) ?? false
    }

    func child(identifier: String) -> AXUIElement? {
        for child in children {
            if child.identifier == identifier { return child }
            if let target = child.child(identifier: identifier) { return target }
        }
        return nil
    }

    func visibleChild(identifier: String) -> AXUIElement? {
        for child in visibleChildren {
            if child.identifier == identifier { return child }
            if let target = child.visibleChild(identifier: identifier) { return target }
        }
        return nil
    }
    
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
