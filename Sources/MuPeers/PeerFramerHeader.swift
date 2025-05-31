// created by musesum on 5/31/25

import Foundation

/// header of two UInt32 for `type`, `length`
struct PeerFramerHeader: Codable {
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
