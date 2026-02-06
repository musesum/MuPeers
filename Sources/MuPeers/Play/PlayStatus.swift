// created by musesum on 2/6/26
import Foundation
import Network

public struct PlayStatus: Codable, Sendable {
    public let deckId    : Int
    public let trackId   : Int
    public var playState : PlayState

    public init(_ deckId: Int) {
        self.deckId    = deckId
        self.trackId   = UUID().uuidString.hashValue
        self.playState = PlayState([.loop,.stop])
    }
    public var script: String {
        "deckId: \(deckId.script5) trackId: \(trackId.script5) state: \(playState.description))"
    }
    public var Script: String {
        "TrackStatus " + script
    }
    public mutating func setState(_ newState: PlayState) {
        playState = newState
    }
    public mutating func updateState(_ state: PlayState, on: Bool) {
        playState.updateState(state, on: on)
    }

}
