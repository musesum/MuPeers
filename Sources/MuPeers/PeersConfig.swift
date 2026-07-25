// created by musesum on 11/18/25
import Foundation

public let PeersPrefix: String = "☯︎"

public struct PeersConfig {
    let service: String
    let secret: String
    let backend: PeersBackend?  // nil resolves UserDefaults override, else legacy

    public init(service: String,
                secret: String,
                backend: PeersBackend? = nil) {

        self.service = service
        self.secret = secret
        self.backend = backend
    }
}
