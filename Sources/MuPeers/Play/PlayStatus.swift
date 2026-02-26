// created by musesum on 2/6/26
import Foundation
import Network

public struct PlayStatus: Codable, Sendable {
    public let deckId    : Int
    public let trackId   : Int
    public var playState : PlayState
    public var playBegan : TimeInterval

    public init(_ deckId: Int) {
        self.deckId    = deckId
        self.trackId   = UUID().uuidString.hashValue
        self.playState = PlayState([.loop, .stop])
        self.playBegan = 0
    }
    public var script: String {
        "deck/track: \(deckId.script5)/\(trackId.script5) state: \(playState.description))"
    }
    public var Script: String {
        "PlayStatus " + script
    }
    public mutating func setState(_ newState: PlayState) {
        playState = newState
    }
    public mutating func updateState(_ state: PlayState, on: Bool) {
        playState.updateState(state, on: on)
    }

}
