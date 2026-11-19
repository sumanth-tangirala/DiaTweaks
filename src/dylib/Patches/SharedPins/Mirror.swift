import Foundation

private func DPUnwrap(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .optional else { return value }
    return mirror.children.first?.value
}

private func DPChild(_ value: Any, _ label: String) -> Any? {
    guard let value = DPUnwrap(value) else { return nil }
    var mirror: Mirror? = Mirror(reflecting: value)
    while let current = mirror {
        if let child = current.children.first(where: { $0.label == label }) { return child.value }
        mirror = current.superclassMirror
    }
    return nil
}

// Follows Dia's stored Swift properties by name, as in "viewModel.delegate.spaceID.rawValue", and gives the text of
// what's at the end, or nil when any step is missing.
@_cdecl("DPMirrorText")
public func DPMirrorText(_ object: AnyObject?, _ path: NSString) -> NSString? {
    guard var value: Any = object else { return nil }
    for label in (path as String).split(separator: ".") {
        guard let child = DPChild(value, String(label)) else { return nil }
        value = child
    }
    guard let leaf = DPUnwrap(value) else { return nil }
    return String(describing: leaf) as NSString
}
