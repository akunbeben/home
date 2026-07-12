public struct CaptureGate: Equatable, Sendable {
    public private(set) var generation = 0
    public private(set) var isOpen = false

    public init() {}

    @discardableResult
    public mutating func invalidate() -> Int {
        generation += 1
        isOpen = false
        return generation
    }

    public func isCurrent(_ candidate: Int) -> Bool {
        candidate == generation
    }

    @discardableResult
    public mutating func open(ifCurrent candidate: Int) -> Bool {
        guard isCurrent(candidate) else { return false }
        isOpen = true
        return true
    }
}
