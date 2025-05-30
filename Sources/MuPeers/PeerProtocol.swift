// created by musesum on 5/13/25

import Foundation
import Network

typealias Framer = NWProtocolFramer.Instance

// types of messages for PeerFramer
public enum FramerType: UInt32 {
    case invalid
    case handshake  // verify / manage peers
    case data       // Generic Data, usually Codable
    case midi       // midi message
    case touch      // touch / draw
    case menu       // menu selection
    case hand       // hand pose


    var description: String {
        switch self {
        case .invalid   : return "invalid"
        case .handshake : return "handshake"
        case .data      : return "data"
        case .midi      : return "midi"
        case .touch     : return "touch"
        case .menu      : return "menu"
        case .hand      : return "hand"

        }
    }
    /// this is a placeholder, no way to select
    /// serviceClass from within a framer, so
    /// special services like video, audio, etc
    /// should have their own framer
    var serviceClass: NWParameters.ServiceClass {
        switch self {
        case .invalid   : return .background
        case .handshake : return .signaling
        case .data      : return .responsiveData
        case .midi      : return .responsiveData
        case .touch     : return .responsiveData
        case .menu      : return .responsiveData
        case .hand      : return .responsiveData
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
        let header = PeerProtocolHeader(type: type.rawValue, length: UInt32(messageLength))
        
        framer.writeOutput(data: header.encodedData)

        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch let error {
            print("Hit error writing \(error)")
        }
    }

    func handleInput(framer: Framer) -> Int {
        while true {
            var tempHeader: PeerProtocolHeader? = nil
            let headerSize = PeerProtocolHeader.encodedSize
            //print("⟸ headerSize: \(headerSize)")
            let parsed = framer.parseInput(
                minimumIncompleteLength: headerSize,
                maximumLength: headerSize) { (buffer, isComplete) -> Int in
                    guard let buffer else { return 0 }
                    if buffer.count < headerSize { return 0 }
                    tempHeader = PeerProtocolHeader(buffer)
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

/// header of two UInt32 for `type`, `length`
struct PeerProtocolHeader: Codable {
    let type: UInt32
    let length: UInt32

    init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }

    // create type,length buffer of 2 UInt32s
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        let UInt32Size = MemoryLayout<UInt32>.size

        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(
                start: buffer.baseAddress!.advanced(by: 0),
                count: UInt32Size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(
                start: buffer.baseAddress!.advanced(by: UInt32Size),
                count: UInt32Size))
        }
        type = tempType
        length = tempLength
    }

    var encodedData: Data {
        var tempType = type
        var tempLength = length
        let UInt32Size = MemoryLayout<UInt32>.size
        var data = Data(bytes: &tempType, count: UInt32Size)
        data.append(Data(bytes: &tempLength, count: UInt32Size))
        return data
    }

    static var encodedSize: Int {
        let UInt32Size = MemoryLayout<UInt32>.size
        return UInt32Size * 2 // type, length
    }
}
