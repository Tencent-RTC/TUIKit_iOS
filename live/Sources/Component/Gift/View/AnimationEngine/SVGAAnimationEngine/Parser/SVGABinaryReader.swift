//
//  SVGABinaryReader.swift
//  TUILiveKit
//
//  Created on 2026/2/5.
//  High-Performance SVGA Player Core
//
//  Zero-copy binary reader with FlatBuffers-inspired design
//

import Foundation
import simd

// MARK: - SVGABinaryReader

/// Zero-copy binary reader for SVGA protobuf data
/// Inspired by FlatBuffers: reads data directly from buffer without intermediate allocations
///
/// Key features:
/// - No memory allocations during read operations
/// - Direct pointer access to embedded data (images, paths)
/// - Lazy field access - only parse what you need
/// - SIMD-aligned reads for transform matrices
@frozen
public struct SVGABinaryReader {
    
    // MARK: - Properties
    
    /// Base pointer to data buffer
    @usableFromInline
    let base: UnsafeRawPointer
    
    /// Total buffer size
    @usableFromInline
    let size: Int
    
    /// Current read position
    @usableFromInline
    var position: Int
    
    // MARK: - Initialization
    
    /// Initialize with raw buffer pointer
    @inlinable
    public init(buffer: UnsafeRawBufferPointer) {
        self.base = buffer.baseAddress!
        self.size = buffer.count
        self.position = 0
    }
    
    /// Initialize with pointer and size
    @inlinable
    public init(pointer: UnsafeRawPointer, size: Int) {
        self.base = pointer
        self.size = size
        self.position = 0
    }
    
    // MARK: - Position Control
    
    /// Remaining bytes
    @inlinable
    public var remaining: Int {
        size - position
    }
    
    /// Whether reader has more data
    @inlinable
    public var hasMore: Bool {
        position < size
    }
    
    /// Seek to absolute position
    @inlinable
    public mutating func seek(to offset: Int) {
        position = min(max(0, offset), size)
    }
    
    /// Skip bytes
    @inlinable
    public mutating func skip(_ count: Int) {
        position = min(position + count, size)
    }
    
    /// Get current position
    @inlinable
    public var offset: Int {
        position
    }
    
    // MARK: - Primitive Reads (Zero-Copy)
    
    /// Read UInt8 without advancing
    @inlinable
    public func peekUInt8() -> UInt8 {
        guard position < size else { return 0 }
        return base.load(fromByteOffset: position, as: UInt8.self)
    }
    
    /// Read UInt8
    @inlinable
    public mutating func readUInt8() -> UInt8 {
        guard position < size else { return 0 }
        let value = base.load(fromByteOffset: position, as: UInt8.self)
        position += 1
        return value
    }
    
    /// Read UInt16 (little endian) - unaligned safe
    @inlinable
    public mutating func readUInt16LE() -> UInt16 {
        guard position + 2 <= size else { return 0 }
        var value: UInt16 = 0
        withUnsafeMutableBytes(of: &value) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(start: base.advanced(by: position), count: 2))
        }
        position += 2
        return UInt16(littleEndian: value)
    }
    
    /// Read UInt32 (little endian) - unaligned safe
    @inlinable
    public mutating func readUInt32LE() -> UInt32 {
        guard position + 4 <= size else { return 0 }
        var value: UInt32 = 0
        withUnsafeMutableBytes(of: &value) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(start: base.advanced(by: position), count: 4))
        }
        position += 4
        return UInt32(littleEndian: value)
    }
    
    /// Read UInt64 (little endian) - unaligned safe
    @inlinable
    public mutating func readUInt64LE() -> UInt64 {
        guard position + 8 <= size else { return 0 }
        var value: UInt64 = 0
        withUnsafeMutableBytes(of: &value) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(start: base.advanced(by: position), count: 8))
        }
        position += 8
        return UInt64(littleEndian: value)
    }
    
    /// Read Float32 (little endian) - unaligned safe
    @inlinable
    public mutating func readFloat32LE() -> Float {
        guard position + 4 <= size else { return 0 }
        var bits: UInt32 = 0
        withUnsafeMutableBytes(of: &bits) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(start: base.advanced(by: position), count: 4))
        }
        position += 4
        return Float(bitPattern: UInt32(littleEndian: bits))
    }
    
    /// Read Float64 (little endian) - unaligned safe
    @inlinable
    public mutating func readFloat64LE() -> Double {
        guard position + 8 <= size else { return 0 }
        var bits: UInt64 = 0
        withUnsafeMutableBytes(of: &bits) { dst in
            dst.copyBytes(from: UnsafeRawBufferPointer(start: base.advanced(by: position), count: 8))
        }
        position += 8
        return Double(bitPattern: UInt64(littleEndian: bits))
    }
    
    // MARK: - Protobuf Varint Reads
    
    /// Read protobuf varint (up to 64-bit)
    @inlinable
    public mutating func readVarint64() -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        
        while position < size {
            let byte = base.load(fromByteOffset: position, as: UInt8.self)
            position += 1
            
            result |= UInt64(byte & 0x7F) << shift
            
            if byte & 0x80 == 0 {
                break
            }
            shift += 7
            
            // Prevent infinite loop on malformed data
            if shift >= 64 {
                break
            }
        }
        
        return result
    }
    
    /// Read protobuf varint as UInt32
    @inlinable
    public mutating func readVarint32() -> UInt32 {
        UInt32(truncatingIfNeeded: readVarint64())
    }
    
    /// Read protobuf varint as Int32 (zigzag decoded)
    @inlinable
    public mutating func readSVarint32() -> Int32 {
        let n = readVarint32()
        return Int32(bitPattern: (n >> 1) ^ (0 &- (n & 1)))
    }
    
    /// Read protobuf varint as Int64 (zigzag decoded)
    @inlinable
    public mutating func readSVarint64() -> Int64 {
        let n = readVarint64()
        return Int64(bitPattern: (n >> 1) ^ (0 &- (n & 1)))
    }
    
    // MARK: - Protobuf Field Reads
    
    /// Read protobuf field tag
    @inlinable
    public mutating func readTag() -> (fieldNumber: Int, wireType: ProtoWireType) {
        let tag = readVarint32()
        let fieldNumber = Int(tag >> 3)
        let wireType = ProtoWireType(rawValue: Int(tag & 0x7)) ?? .varint
        return (fieldNumber, wireType)
    }
    
    /// Skip a protobuf field based on wire type
    @inlinable
    public mutating func skipField(wireType: ProtoWireType) {
        switch wireType {
        case .varint:
            _ = readVarint64()
        case .fixed64:
            skip(8)
        case .lengthDelimited:
            let length = Int(readVarint32())
            skip(length)
        case .startGroup, .endGroup:
            // Deprecated, skip
            break
        case .fixed32:
            skip(4)
        }
    }
    
    // MARK: - Zero-Copy Data Access
    
    /// Read length-delimited bytes (returns pointer, no copy)
    @inlinable
    public mutating func readBytesPointer() -> UnsafeRawBufferPointer {
        let length = Int(readVarint32())
        guard position + length <= size else {
            return UnsafeRawBufferPointer(start: nil, count: 0)
        }
        
        let ptr = UnsafeRawBufferPointer(
            start: base.advanced(by: position),
            count: length
        )
        position += length
        return ptr
    }
    
    /// Read length-delimited string (returns pointer, no copy)
    @inlinable
    public mutating func readStringPointer() -> (pointer: UnsafePointer<CChar>, length: Int)? {
        let length = Int(readVarint32())
        guard position + length <= size else { return nil }
        
        let ptr = base.advanced(by: position).assumingMemoryBound(to: CChar.self)
        position += length
        return (ptr, length)
    }
    
    /// Read string with zero-copy when possible
    @inlinable
    public mutating func readString() -> String {
        guard let (ptr, length) = readStringPointer() else { return "" }
        
        // Create string from buffer without intermediate Data allocation
        return String(
            decoding: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(ptr)), count: length),
            as: UTF8.self
        )
    }
    
    /// Get sub-reader for embedded message
    @inlinable
    public mutating func readSubReader() -> SVGABinaryReader {
        let length = Int(readVarint32())
        guard position + length <= size else {
            return SVGABinaryReader(pointer: base, size: 0)
        }
        
        let subReader = SVGABinaryReader(
            pointer: base.advanced(by: position),
            size: length
        )
        position += length
        return subReader
    }
    
    // MARK: - SIMD-Aligned Reads
    
    /// Read 2D transform matrix (6 floats: a, b, c, d, tx, ty)
    /// Converts to simd_float3x3 for GPU rendering
    @inlinable
    public mutating func readTransformMatrix() -> simd_float3x3 {
        // Read 6 float values (protobuf transform: a, b, c, d, tx, ty)
        let a = readFloat32LE()
        let b = readFloat32LE()
        let c = readFloat32LE()
        let d = readFloat32LE()
        let tx = readFloat32LE()
        let ty = readFloat32LE()
        
        // Convert to 3x3 matrix (column-major for Metal)
        // [ a  c  tx ]
        // [ b  d  ty ]
        // [ 0  0  1  ]
        return simd_float3x3(
            SIMD3<Float>(a, b, 0),
            SIMD3<Float>(c, d, 0),
            SIMD3<Float>(tx, ty, 1)
        )
    }
    
    /// Read transform from protobuf message fields
    @inlinable
    public mutating func readTransformFromProto() -> simd_float3x3 {
        var a: Float = 1, b: Float = 0, c: Float = 0, d: Float = 1
        var tx: Float = 0, ty: Float = 0
        
        let end = position + Int(readVarint32())
        
        while position < end {
            let (fieldNum, wireType) = readTag()
            
            switch fieldNum {
            case 1: a = Float(readFloat64LE())
            case 2: b = Float(readFloat64LE())
            case 3: c = Float(readFloat64LE())
            case 4: d = Float(readFloat64LE())
            case 5: tx = Float(readFloat64LE())
            case 6: ty = Float(readFloat64LE())
            default: skipField(wireType: wireType)
            }
        }
        
        return simd_float3x3(
            SIMD3<Float>(a, b, 0),
            SIMD3<Float>(c, d, 0),
            SIMD3<Float>(tx, ty, 1)
        )
    }
    
    // MARK: - Batch Reads
    
    /// Read multiple varints into pre-allocated buffer
    @inlinable
    public mutating func readVarintsInto(
        buffer: UnsafeMutablePointer<UInt32>,
        count: Int
    ) -> Int {
        var read = 0
        while read < count && hasMore {
            buffer[read] = readVarint32()
            read += 1
        }
        return read
    }
    
    /// Read multiple floats directly (for frame data arrays)
    @inlinable
    public mutating func readFloatsInto(
        buffer: UnsafeMutablePointer<Float>,
        count: Int
    ) -> Int {
        let bytesNeeded = count * 4
        guard position + bytesNeeded <= size else {
            return 0
        }
        
        // Direct memory copy (SIMD-friendly)
        memcpy(buffer, base.advanced(by: position), bytesNeeded)
        position += bytesNeeded
        
        // Handle endianness if needed (assuming little-endian source)
        #if _endian(big)
        for i in 0..<count {
            buffer[i] = Float(bitPattern: buffer[i].bitPattern.littleEndian)
        }
        #endif
        
        return count
    }
}

// MARK: - ProtoWireType

/// Protobuf wire types
public enum ProtoWireType: Int {
    case varint = 0
    case fixed64 = 1
    case lengthDelimited = 2
    case startGroup = 3  // Deprecated
    case endGroup = 4    // Deprecated
    case fixed32 = 5
}

// MARK: - SVGABinaryReader + Image Access

extension SVGABinaryReader {
    
    /// Read image data pointer directly (zero-copy)
    /// Returns pointer to PNG/JPEG data in buffer
    @inlinable
    public mutating func readImageDataPointer() -> (pointer: UnsafeRawPointer, size: Int)? {
        let length = Int(readVarint32())
        guard length > 0, position + length <= size else { return nil }
        
        let ptr = base.advanced(by: position)
        position += length
        return (ptr, length)
    }
}

// MARK: - SVGAProtoFieldAccessor

/// Lazy field accessor for protobuf messages
/// Stores field positions for on-demand reading
@frozen
public struct SVGAProtoFieldAccessor {
    
    /// Field position in buffer
    public struct FieldPosition {
        @usableFromInline
        internal let offset: Int
        @usableFromInline
        internal let length: Int
        let wireType: ProtoWireType
        
        @usableFromInline
        internal init(offset: Int, length: Int, wireType: ProtoWireType) {
            self.offset = offset
            self.length = length
            self.wireType = wireType
        }
    }
    
    /// Base buffer
    @usableFromInline
    let buffer: UnsafeRawBufferPointer
    
    /// Indexed field positions
    @usableFromInline
    var fields: [Int: FieldPosition] = [:]
    
    /// Initialize by scanning message
    @inlinable
    public init(buffer: UnsafeRawBufferPointer) {
        self.buffer = buffer
        indexFields()
    }
    
    /// Index all fields in message
    @usableFromInline
    mutating func indexFields() {
        var reader = SVGABinaryReader(buffer: buffer)
        
        while reader.hasMore {
            let startOffset = reader.position
            let (fieldNumber, wireType) = reader.readTag()
            
            guard fieldNumber > 0 else { break }
            
            let valueOffset = reader.position
            reader.skipField(wireType: wireType)
            let length = reader.position - valueOffset
            
            fields[fieldNumber] = FieldPosition(
                offset: valueOffset,
                length: length,
                wireType: wireType
            )
        }
    }
    
    /// Check if field exists
    @inlinable
    public func hasField(_ number: Int) -> Bool {
        fields[number] != nil
    }
    
    /// Get reader positioned at field
    @inlinable
    public func readerForField(_ number: Int) -> SVGABinaryReader? {
        guard let pos = fields[number] else { return nil }
        return SVGABinaryReader(
            pointer: buffer.baseAddress!.advanced(by: pos.offset),
            size: pos.length
        )
    }
    
    /// Read varint field
    @inlinable
    public func readVarint(_ number: Int) -> UInt64? {
        guard var reader = readerForField(number) else { return nil }
        return reader.readVarint64()
    }
    
    /// Read float64 field
    @inlinable
    public func readFloat64(_ number: Int) -> Double? {
        guard var reader = readerForField(number) else { return nil }
        return reader.readFloat64LE()
    }
    
    /// Read string field
    @inlinable
    public func readString(_ number: Int) -> String? {
        guard var reader = readerForField(number),
              let (ptr, length) = reader.readStringPointer() else { return nil }
        return String(
            decoding: UnsafeBufferPointer(start: UnsafePointer<UInt8>(OpaquePointer(ptr)), count: length),
            as: UTF8.self
        )
    }
    
    /// Read bytes pointer (zero-copy)
    @inlinable
    public func readBytesPointer(_ number: Int) -> UnsafeRawBufferPointer? {
        guard let pos = fields[number] else { return nil }
        return UnsafeRawBufferPointer(
            start: buffer.baseAddress!.advanced(by: pos.offset),
            count: pos.length
        )
    }
}
