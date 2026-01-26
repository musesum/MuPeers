// created by musesum on 5/13/25

import Foundation
import Network

typealias Framer = NWProtocolFramer.Instance

/// types of messages for PeerFramer will determine
/// which delegate to dispatch the data.
/// handshake is unique in that it will determine
/// whether a peerId has been accepted from both sides.
public enum FramerType: UInt32, Codable, Sendable {
    case invalid
    case handshake    // verify / manage peers
    case dataFrame    // Generic Data, usually Codable
    case midiFrame    // midi message
    case touchFrame   // touch / draw
    case menuFrame    // menu selection
    case handFrame    // hand pose
    case tapeFrame    // tape events
    case tapeStateFrame // tape .recording, .playback, .stopped
    case archiveFrame // archive sharing

    public var description: String {
        switch self {
        case .invalid        : return "invalid"
        case .handshake      : return "handshake"
        case .dataFrame      : return "data"
        case .midiFrame      : return "midi"
        case .touchFrame     : return "touch"
        case .menuFrame      : return "menu"
        case .handFrame      : return "hand"
        case .tapeFrame      : return "tape"
        case .tapeStateFrame : return "tapeState"
        case .archiveFrame   : return "archive"
        }
    }
    /// this is a placeholder, no way to select
    /// serviceClass from within a framer, so
    /// special services like video, audio, etc
    /// should have their own framer
    var serviceClass: NWParameters.ServiceClass {
        switch self {
        case .invalid        : return .background
        case .handshake      : return .signaling
        case .dataFrame      : return .responsiveData
        case .midiFrame      : return .responsiveData
        case .touchFrame     : return .responsiveData
        case .menuFrame      : return .responsiveData
        case .handFrame      : return .responsiveData
        case .tapeFrame      : return .responsiveData
        case .tapeStateFrame : return .responsiveData
        case .archiveFrame   : return .responsiveData
        }
    }
}

// Custom NWProtocolFramer for passing peer metadata
class PeerFramer: NWProtocolFramerImplementation {

    static let definition = NWProtocolFramer.Definition(implementation: PeerFramer.self)
    static var label: String { return "PeerFramer" }

    required init(framer: Framer) {}
    func start   (framer: Framer) -> NWProtocolFramer.StartResult { return .ready }
    func wakeup  (framer: Framer) {}
    func stop    (framer: Framer) -> Bool { return true }
    func cleanup (framer: Framer) {}

    func handleOutput(framer: Framer,
                      message: NWProtocolFramer.Message,
                      messageLength: Int,
                      isComplete: Bool) {

        let type = message.framerType
        let header = PeerFramerHeader(type: type.rawValue, length: UInt32(messageLength))
        
        framer.writeOutput(data: header.encodedData)

        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch let error {
            print("Hit error writing \(error)")
        }
    }

    func handleInput(framer: Framer) -> Int {
        while true {
            var tempHeader: PeerFramerHeader? = nil
            let headerSize = PeerFramerHeader.encodedSize
            //print("⟸ headerSize: \(headerSize)")
            let parsed = framer.parseInput(
                minimumIncompleteLength: headerSize,
                maximumLength: headerSize) { (buffer, isComplete) -> Int in
                    guard let buffer else { return 0 }
                    if buffer.count < headerSize { return 0 }
                    tempHeader = PeerFramerHeader(buffer)
                    return headerSize
                }

            guard parsed, let header = tempHeader else { return headerSize }
            var messageType = FramerType.invalid
            if let parsedMessageType = FramerType(rawValue: header.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(framerType: messageType)

            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

// custom PeerFramer types for header
extension NWProtocolFramer.Message {
    convenience init(framerType: FramerType) {
        self.init(definition: PeerFramer.definition)
        self["FramerType"] = framerType
    }

    var framerType: FramerType {
        if let type = self["FramerType"] as? FramerType {
            return type
        } else {
            return .invalid
        }
    }
}

