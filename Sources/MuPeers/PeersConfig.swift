// created by musesum on 11/18/25
import Foundation

public let PeersPrefix: String = "☯︎"

public struct PeersConfig {
    let service: String
    let secret: String
    
    public init(service: String,
                secret: String) {
        
        self.service = service
        self.secret = secret
    }
}
