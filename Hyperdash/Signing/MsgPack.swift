import Foundation

/// Minimal, order-preserving MessagePack encoder.
///
/// Hyperliquid's L1 action hash is `keccak256(msgpack(action) || nonce || …)`,
/// and the reference implementation uses Python's `msgpack.packb`. Field order
/// is significant, so actions are represented as `MsgPackValue.map([(key, value)])`
/// with explicit ordering rather than Swift dictionaries.
indirect enum MsgPackValue {
    case string(String)
    case int(Int)
    case uint(UInt64)
    case bool(Bool)
    case double(Double)
    case array([MsgPackValue])
    case map([(String, MsgPackValue)])
    case null

    func encoded() -> [UInt8] {
        var out: [UInt8] = []
        encode(into: &out)
        return out
    }

    private func encode(into out: inout [UInt8]) {
        switch self {
        case .null:
            out.append(0xc0)
        case .bool(let b):
            out.append(b ? 0xc3 : 0xc2)
        case .int(let i):
            MsgPackValue.encodeInt(Int64(i), into: &out)
        case .uint(let u):
            MsgPackValue.encodeUInt(u, into: &out)
        case .double(let d):
            out.append(0xcb)
            out.append(contentsOf: withUnsafeBytes(of: d.bitPattern.bigEndian) { Array($0) })
        case .string(let s):
            MsgPackValue.encodeString(s, into: &out)
        case .array(let items):
            MsgPackValue.encodeArrayHeader(items.count, into: &out)
            for item in items { item.encode(into: &out) }
        case .map(let pairs):
            MsgPackValue.encodeMapHeader(pairs.count, into: &out)
            for (key, value) in pairs {
                MsgPackValue.encodeString(key, into: &out)
                value.encode(into: &out)
            }
        }
    }

    private static func encodeString(_ s: String, into out: inout [UInt8]) {
        let bytes = Array(s.utf8)
        let count = bytes.count
        switch count {
        case 0..<32:
            out.append(0xa0 | UInt8(count))
        case 32..<256:
            out.append(0xd9); out.append(UInt8(count))
        case 256..<65536:
            out.append(0xda)
            out.append(contentsOf: withUnsafeBytes(of: UInt16(count).bigEndian) { Array($0) })
        default:
            out.append(0xdb)
            out.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Array($0) })
        }
        out.append(contentsOf: bytes)
    }

    private static func encodeArrayHeader(_ count: Int, into out: inout [UInt8]) {
        switch count {
        case 0..<16:
            out.append(0x90 | UInt8(count))
        case 16..<65536:
            out.append(0xdc)
            out.append(contentsOf: withUnsafeBytes(of: UInt16(count).bigEndian) { Array($0) })
        default:
            out.append(0xdd)
            out.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Array($0) })
        }
    }

    private static func encodeMapHeader(_ count: Int, into out: inout [UInt8]) {
        switch count {
        case 0..<16:
            out.append(0x80 | UInt8(count))
        case 16..<65536:
            out.append(0xde)
            out.append(contentsOf: withUnsafeBytes(of: UInt16(count).bigEndian) { Array($0) })
        default:
            out.append(0xdf)
            out.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Array($0) })
        }
    }

    private static func encodeUInt(_ value: UInt64, into out: inout [UInt8]) {
        switch value {
        case 0..<0x80:
            out.append(UInt8(value))
        case 0x80..<0x100:
            out.append(0xcc); out.append(UInt8(value))
        case 0x100..<0x10000:
            out.append(0xcd)
            out.append(contentsOf: withUnsafeBytes(of: UInt16(value).bigEndian) { Array($0) })
        case 0x10000..<0x100000000:
            out.append(0xce)
            out.append(contentsOf: withUnsafeBytes(of: UInt32(value).bigEndian) { Array($0) })
        default:
            out.append(0xcf)
            out.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
        }
    }

    private static func encodeInt(_ value: Int64, into out: inout [UInt8]) {
        if value >= 0 {
            encodeUInt(UInt64(value), into: &out)
            return
        }
        switch value {
        case -32..<0:
            out.append(UInt8(bitPattern: Int8(value)))
        case -128..<(-32):
            out.append(0xd0); out.append(UInt8(bitPattern: Int8(value)))
        case -32768..<(-128):
            out.append(0xd1)
            out.append(contentsOf: withUnsafeBytes(of: Int16(value).bigEndian) { Array($0) })
        case -2147483648..<(-32768):
            out.append(0xd2)
            out.append(contentsOf: withUnsafeBytes(of: Int32(value).bigEndian) { Array($0) })
        default:
            out.append(0xd3)
            out.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) })
        }
    }
}
