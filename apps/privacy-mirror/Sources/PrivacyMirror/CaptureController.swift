import AVFoundation
import CoreGraphics
import PrivacyMirrorCore
import ScreenCaptureKit

@MainActor
final class CaptureController: NSObject {
    private let mirrorView: MirrorView
    private let aeroSpace: AeroSpaceClient
    private let onStatus: (String) -> Void
    private let captureQueue = DispatchQueue(label: "com.benny.PrivacyMirror.capture")
    private var configuration: AppConfiguration
    private var stream: SCStream?
    private var operation: Task<Void, Never>?
    private var subscription: AeroSpaceSubscription?
    private var deferredRefresh: DispatchWorkItem?
    private var gate = CaptureGate()
    private var stopped = false
    private var active = false

    init(
        mirrorView: MirrorView,
        aeroSpace: AeroSpaceClient,
        configuration: AppConfiguration,
        onStatus: @escaping (String) -> Void
    ) {
        self.mirrorView = mirrorView
        self.aeroSpace = aeroSpace
        self.configuration = configuration
        self.onStatus = onStatus
    }

    func start() {
        stopped = false
        active = true
        guard startSubscriptionIfNeeded() else { return }
        transition(shouldRefresh: true)
    }

    func apply(configuration: AppConfiguration) {
        self.configuration = configuration
        guard startSubscriptionIfNeeded() else { return }
        if active {
            transition(shouldRefresh: true)
        }
    }

    func invalidate(reason: String) {
        transition(shouldRefresh: false)
        mirrorView.showError(reason)
        onStatus(reason)
    }

    func prepareForWindowMove(completion: @escaping (Bool) -> Void) {
        guard active else {
            completion(true)
            return
        }
        guard let stopOperation = transition(shouldRefresh: false) else {
            completion(false)
            return
        }
        Task {
            await stopOperation.value
            completion(!stopped && stream == nil && !gate.isOpen)
        }
    }

    func stop() {
        active = false
        gate.invalidate()
        deferredRefresh?.cancel()
        deferredRefresh = nil
        operation?.cancel()
        operation = nil

        guard let stream else { return }
        self.stream = nil
        Task { try? await stream.stopCapture() }
    }

    func shutdown() {
        stopped = true
        stop()
        subscription?.stop()
        subscription = nil
    }

    @discardableResult
    private func transition(shouldRefresh: Bool) -> Task<Void, Never>? {
        guard !stopped else { return nil }

        deferredRefresh?.cancel()
        deferredRefresh = nil
        let requestedGeneration = gate.invalidate()
        let requestedConfiguration = configuration
        let previousOperation = operation
        let previousStream = stream
        stream = nil
        mirrorView.blank()

        operation = Task {
            await previousOperation?.value
            if let previousStream {
                try? await previousStream.stopCapture()
            }
            guard shouldRefresh, isCurrent(requestedGeneration) else { return }
            await createStream(
                configuration: requestedConfiguration,
                generation: requestedGeneration
            )
        }
        return operation
    }

    private func createStream(
        configuration: AppConfiguration,
        generation: Int
    ) async {
        do {
            let snapshot = try await makeSnapshot(configuration: configuration)
            guard isCurrent(generation) else { return }

            let stream = SCStream(
                filter: snapshot.filter,
                configuration: makeStreamConfiguration(for: snapshot),
                delegate: self
            )
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            try await stream.startCapture()

            guard isCurrent(generation) else {
                try? await stream.stopCapture()
                return
            }

            self.stream = stream
            complete(snapshot, generation: generation)
        } catch is CancellationError {
            return
        } catch {
            failClosed(error, generation: generation)
        }
    }

    private func makeSnapshot(configuration: AppConfiguration) async throws -> CaptureSnapshot {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw CaptureError.screenRecordingPermissionRequired
        }

        // Freeze the shareable catalog first. Windows created after this point are absent from the
        // allow-list until the next AeroSpace event, so they fail closed.
        let allContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
        try Task.checkCancellation()

        let workspaces = configuration.excludedWorkspaces
        let aeroSpace = self.aeroSpace
        let privateWindowIDs = try await Task.detached {
            try aeroSpace.windowIDs(in: workspaces)
        }.value
        try Task.checkCancellation()

        guard let display = allContent.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
            throw CaptureError.mainDisplayNotFound
        }

        let visibleWindows = allContent.windows.filter(\.isOnScreen)
        let ownBundleID = Bundle.main.bundleIdentifier
        let managedPrivateWindows = allContent.windows.filter { privateWindowIDs.contains($0.windowID) }
        let privateProcessIDs = Set(
            managedPrivateWindows.compactMap { $0.owningApplication?.processID }
        )
        let privateWindows = visibleWindows.filter { window in
            privateWindowIDs.contains(window.windowID)
                || window.owningApplication.map { privateProcessIDs.contains($0.processID) } == true
        }
        let expandedPrivateWindowIDs = Set(privateWindows.map(\.windowID))
        let includedWindows = visibleWindows.filter { window in
            !expandedPrivateWindowIDs.contains(window.windowID)
                && window.owningApplication?.bundleIdentifier != ownBundleID
        }

        return CaptureSnapshot(
            display: display,
            filter: SCContentFilter(display: display, including: includedWindows),
            privateRegions: privateWindows.map(\.frame),
            placeholderStyle: configuration.placeholderStyle,
            showsCursor: configuration.showsCursor,
            captureFrameRate: configuration.captureFrameRate,
            captureMaxWidth: configuration.captureMaxWidth
        )
    }

    private func makeStreamConfiguration(for snapshot: CaptureSnapshot) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let displayWidth = Int(CGDisplayPixelsWide(snapshot.display.displayID))
        let displayHeight = Int(CGDisplayPixelsHigh(snapshot.display.displayID))
        let scale = min(1, Double(snapshot.captureMaxWidth) / Double(displayWidth))
        configuration.width = max(1, Int(Double(displayWidth) * scale))
        configuration.height = max(1, Int(Double(displayHeight) * scale))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(snapshot.captureFrameRate))
        configuration.queueDepth = 2
        configuration.showsCursor = snapshot.showsCursor
        configuration.capturesAudio = false
        return configuration
    }

    private func complete(_ snapshot: CaptureSnapshot, generation: Int) {
        mirrorView.updatePlaceholders(
            regions: snapshot.privateRegions,
            displayFrame: snapshot.display.frame,
            style: snapshot.placeholderStyle
        )
        guard gate.open(ifCurrent: generation) else { return }
        onStatus("Running — share the Privacy Mirror Output window")
    }

    private func startSubscriptionIfNeeded() -> Bool {
        guard subscription == nil else { return true }
        let subscription = aeroSpace.makeSubscription()
        do {
            try subscription.start(
                onEvent: { [weak self] event in
                    DispatchQueue.main.async { self?.handle(event) }
                },
                onFailure: { [weak self] in
                    DispatchQueue.main.async {
                        self?.subscription = nil
                        self?.failClosed(CaptureError.aeroSpaceSubscriptionStopped)
                    }
                }
            )
            self.subscription = subscription
            return true
        } catch {
            failClosed(error)
            return false
        }
    }

    private func isCurrent(_ requestedGeneration: Int) -> Bool {
        !stopped && gate.isCurrent(requestedGeneration) && !Task.isCancelled
    }

    private func handle(_ event: AeroSpaceEvent) {
        guard active else { return }
        switch event {
        case .windowMoveBinding:
            // binding-triggered is emitted before AeroSpace runs the move. Keep output blank until
            // the resulting state change provides the post-move state. Some moves do not emit a
            // second event, so schedule a short fallback refresh to avoid staying blank forever.
            transition(shouldRefresh: false)
            scheduleDeferredRefresh()
        case .stateChanged:
            transition(shouldRefresh: true)
        }
    }

    private func scheduleDeferredRefresh() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.transition(shouldRefresh: true)
        }
        deferredRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(350), execute: workItem)
    }

    private func failClosed(_ error: Error, generation requestedGeneration: Int? = nil) {
        if let requestedGeneration, !isCurrent(requestedGeneration) { return }
        transition(shouldRefresh: false)
        mirrorView.showError(error.localizedDescription)
        onStatus(error.localizedDescription)
    }
}

extension CaptureController: SCStreamOutput {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen, sampleBuffer.isValid else { return }
        let frame = CapturedFrame(sampleBuffer: sampleBuffer)
        let streamID = ObjectIdentifier(stream)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.stream.map(ObjectIdentifier.init) == streamID,
                  self.gate.isOpen
            else { return }
            self.mirrorView.enqueue(frame.sampleBuffer)
        }
    }
}

extension CaptureController: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let streamID = ObjectIdentifier(stream)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream.map(ObjectIdentifier.init) == streamID else { return }
            self.failClosed(error)
        }
    }
}

private struct CapturedFrame: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
}

private struct CaptureSnapshot {
    let display: SCDisplay
    let filter: SCContentFilter
    let privateRegions: [CGRect]
    let placeholderStyle: PlaceholderStyle
    let showsCursor: Bool
    let captureFrameRate: Int
    let captureMaxWidth: Int
}

private enum CaptureError: LocalizedError {
    case screenRecordingPermissionRequired
    case mainDisplayNotFound
    case aeroSpaceSubscriptionStopped

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionRequired:
            "Allow Privacy Mirror in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch"
        case .mainDisplayNotFound:
            "Main display not found"
        case .aeroSpaceSubscriptionStopped:
            "AeroSpace event subscription stopped; output is blank until configuration is reloaded"
        }
    }
}
