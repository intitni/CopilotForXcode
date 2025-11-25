import AppKit

/// AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *identifier);
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func AXUIElementGetWindow(
    _ element: AXUIElement,
    _ identifier: UnsafeMutablePointer<CGWindowID>
) -> AXError
