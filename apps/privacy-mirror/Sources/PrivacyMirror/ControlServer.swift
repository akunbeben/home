import Darwin
import Foundation

final class ControlServer: @unchecked Sendable {
    typealias InvalidateHandler = @Sendable (@escaping @Sendable (Bool) -> Void) -> Void

    private let queue = DispatchQueue(label: "com.benny.PrivacyMirror.control")
    private let socketPath = "/tmp/privacy-mirror-\(getuid()).sock"
    private var socketDescriptor: Int32 = -1
    private var source: DispatchSourceRead?

    func start(onInvalidate: @escaping InvalidateHandler) throws {
        unlink(socketPath)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw ControlServerError.systemCall("socket") }
        socketDescriptor = descriptor

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw ControlServerError.socketPathTooLong
        }
        socketPath.withCString { source in
            withUnsafeMutablePointer(to: &address.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { destination in
                    _ = strncpy(destination, source, pathBytes.count)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else { throw ControlServerError.systemCall("bind") }
        guard chmod(socketPath, S_IRUSR | S_IWUSR) == 0 else {
            throw ControlServerError.systemCall("chmod")
        }
        guard listen(descriptor, 4) == 0 else { throw ControlServerError.systemCall("listen") }

        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection(onInvalidate: onInvalidate)
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
        socketDescriptor = -1
        unlink(socketPath)
    }

    private func acceptConnection(onInvalidate: @escaping InvalidateHandler) {
        let client = Darwin.accept(socketDescriptor, nil, nil)
        guard client >= 0 else { return }

        var buffer = [UInt8](repeating: 0, count: 64)
        let count = Darwin.read(client, &buffer, buffer.count)
        guard count > 0,
              String(decoding: buffer.prefix(count), as: UTF8.self).hasPrefix("invalidate")
        else {
            close(client)
            return
        }

        onInvalidate { allowed in
            let response = allowed ? "ok\n" : "error\n"
            response.withCString { pointer in
                _ = Darwin.write(client, pointer, strlen(pointer))
            }
            close(client)
        }
    }
}

private enum ControlServerError: LocalizedError {
    case socketPathTooLong
    case systemCall(String)

    var errorDescription: String? {
        switch self {
        case .socketPathTooLong:
            "Privacy Mirror control socket path is too long"
        case .systemCall(let name):
            "Privacy Mirror control socket failed during \(name): \(String(cString: strerror(errno)))"
        }
    }
}
