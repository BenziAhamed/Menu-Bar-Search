// Sources/SwiftProtobuf/BinaryEncodingVisitor.swift - Binary encoding support
//
// Copyright (c) 2014 - 2016 Apple Inc. and the project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE.txt for license information:
// https://github.com/apple/swift-protobuf/blob/master/LICENSE.txt
//
// -----------------------------------------------------------------------------
///
/// Core support for protobuf binary encoding.  Note that this is built
/// on the general traversal machinery.
///
// -----------------------------------------------------------------------------

import Foundation

/// Visitor that encodes a message graph in the protobuf binary wire format.
internal struct BinaryEncodingVisitor: Visitor {

  private var encoder: BinaryEncoder

  /// Creates a new visitor that writes the binary-coded message into the memory
  /// at the given pointer.
  ///
  /// - Precondition: `pointer` must point to an allocated block of memory that
  ///   is large enough to hold the entire encoded message. For performance
  ///   reasons, the encoder does not make any attempts to verify this.
  init(forWritingInto pointer: UnsafeMutablePointer<UInt8>) {
    encoder = BinaryEncoder(forWritingInto: pointer)
  }

  mutating func visitUnknown(bytes: Data) throws {
    encoder.appendUnknown(data: bytes)
  }

  mutating func visitSingularFloatField(value: Float, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .fixed32)
    encoder.putFloatValue(value: value)
  }

  mutating func visitSingularDoubleField(value: Double, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .fixed64)
    encoder.putDoubleValue(value: value)
  }

  mutating func visitSingularInt64Field(value: Int64, fieldNumber: Int) throws {
    try visitSingularUInt64Field(value: UInt64(bitPattern: value), fieldNumber: fieldNumber)
  }

  mutating func visitSingularUInt64Field(value: UInt64, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .varint)
    encoder.putVarInt(value: value)
  }

  mutating func visitSingularSInt32Field(value: Int32, fieldNumber: Int) throws {
    try visitSingularSInt64Field(value: Int64(value), fieldNumber: fieldNumber)
  }

  mutating func visitSingularSInt64Field(value: Int64, fieldNumber: Int) throws {
    try visitSingularUInt64Field(value: ZigZag.encoded(value), fieldNumber: fieldNumber)
  }

  mutating func visitSingularFixed32Field(value: UInt32, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .fixed32)
    encoder.putFixedUInt32(value: value)
  }

  mutating func visitSingularFixed64Field(value: UInt64, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .fixed64)
    encoder.putFixedUInt64(value: value)
  }

  mutating func visitSingularSFixed32Field(value: Int32, fieldNumber: Int) throws {
    try visitSingularFixed32Field(value: UInt32(bitPattern: value), fieldNumber: fieldNumber)
  }

  mutating func visitSingularSFixed64Field(value: Int64, fieldNumber: Int) throws {
    try visitSingularFixed64Field(value: UInt64(bitPattern: value), fieldNumber: fieldNumber)
  }

  mutating func visitSingularBoolField(value: Bool, fieldNumber: Int) throws {
    try visitSingularUInt64Field(value: value ? 1 : 0, fieldNumber: fieldNumber)
  }

  mutating func visitSingularStringField(value: String, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putStringValue(value: value)
  }

  mutating func visitSingularBytesField(value: Data, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putBytesValue(value: value)
  }

  mutating func visitSingularEnumField<E: Enum>(value: E,
                                                fieldNumber: Int) throws {
    try visitSingularUInt64Field(value: UInt64(bitPattern: Int64(value.rawValue)),
                                 fieldNumber: fieldNumber)
  }

  mutating func visitSingularMessageField<M: Message>(value: M,
                                             fieldNumber: Int) throws {
    // Can force partial to true here because the parent message would have
    // already recursed for the isInitialized check if it was needed.
    let t = try value.serializedData(partial: true)
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putBytesValue(value: t)
  }

  mutating func visitSingularGroupField<G: Message>(value: G, fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .startGroup)
    try value.traverse(visitor: &self)
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .endGroup)
  }

  // Repeated fields are handled by the default implementations in Visitor.swift


  // Packed Fields

  mutating func visitPackedFloatField(value: [Float], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count * MemoryLayout<Float>.size)
    for v in value {
      encoder.putFloatValue(value: v)
    }
  }

  mutating func visitPackedDoubleField(value: [Double], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count * MemoryLayout<Double>.size)
    for v in value {
      encoder.putDoubleValue(value: v)
    }
  }

  mutating func visitPackedInt32Field(value: [Int32], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
        packedSize += Varint.encodedSize(of: v)
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
        encoder.putVarInt(value: Int64(v))
    }
  }

  mutating func visitPackedInt64Field(value: [Int64], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
        packedSize += Varint.encodedSize(of: v)
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
        encoder.putVarInt(value: v)
    }
  }

  mutating func visitPackedSInt32Field(value: [Int32], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
        packedSize += Varint.encodedSize(of: ZigZag.encoded(v))
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
        encoder.putZigZagVarInt(value: Int64(v))
    }
  }

  mutating func visitPackedSInt64Field(value: [Int64], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
        packedSize += Varint.encodedSize(of: ZigZag.encoded(v))
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
        encoder.putZigZagVarInt(value: v)
    }
  }

  mutating func visitPackedUInt32Field(value: [UInt32], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
        packedSize += Varint.encodedSize(of: v)
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
        encoder.putVarInt(value: UInt64(v))
    }
  }

  mutating func visitPackedUInt64Field(value: [UInt64], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
        packedSize += Varint.encodedSize(of: v)
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
        encoder.putVarInt(value: v)
    }
  }

  mutating func visitPackedFixed32Field(value: [UInt32], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count * MemoryLayout<UInt32>.size)
    for v in value {
      encoder.putFixedUInt32(value: v)
    }
  }

  mutating func visitPackedFixed64Field(value: [UInt64], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count * MemoryLayout<UInt64>.size)
    for v in value {
      encoder.putFixedUInt64(value: v)
    }
  }

  mutating func visitPackedSFixed32Field(value: [Int32], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count * MemoryLayout<Int32>.size)
    for v in value {
       encoder.putFixedUInt32(value: UInt32(bitPattern: v))
    }
  }

  mutating func visitPackedSFixed64Field(value: [Int64], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count * MemoryLayout<Int64>.size)
    for v in value {
      encoder.putFixedUInt64(value: UInt64(bitPattern: v))
    }
  }

  mutating func visitPackedBoolField(value: [Bool], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    encoder.putVarInt(value: value.count)
    for v in value {
      encoder.putVarInt(value: v ? 1 : 0)
    }
  }

  mutating func visitPackedEnumField<E: Enum>(value: [E], fieldNumber: Int) throws {
    encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
    var packedSize = 0
    for v in value {
      packedSize += Varint.encodedSize(of: Int32(truncatingBitPattern: v.rawValue))
    }
    encoder.putVarInt(value: packedSize)
    for v in value {
      encoder.putVarInt(value: v.rawValue)
    }
  }

  mutating func visitMapField<KeyType: MapKeyType, ValueType: MapValueType>(
    fieldType: _ProtobufMap<KeyType, ValueType>.Type,
    value: _ProtobufMap<KeyType, ValueType>.BaseType,
    fieldNumber: Int
  ) throws where KeyType.BaseType: Hashable {
    for (k,v) in value {
      encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
      var sizer = BinaryEncodingSizeVisitor()
      try KeyType.visitSingular(value: k, fieldNumber: 1, with: &sizer)
      try ValueType.visitSingular(value: v, fieldNumber: 2, with: &sizer)
      let entrySize = sizer.serializedSize
      encoder.putVarInt(value: entrySize)
      try KeyType.visitSingular(value: k, fieldNumber: 1, with: &self)
      try ValueType.visitSingular(value: v, fieldNumber: 2, with: &self)
    }
  }

  mutating func visitMapField<KeyType: MapKeyType, ValueType: Enum>(
    fieldType: _ProtobufEnumMap<KeyType, ValueType>.Type,
    value: _ProtobufEnumMap<KeyType, ValueType>.BaseType,
    fieldNumber: Int
  ) throws where KeyType.BaseType: Hashable, ValueType.RawValue == Int {
    for (k,v) in value {
      encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
      var sizer = BinaryEncodingSizeVisitor()
      try KeyType.visitSingular(value: k, fieldNumber: 1, with: &sizer)
      try sizer.visitSingularEnumField(value: v, fieldNumber: 2)
      let entrySize = sizer.serializedSize
      encoder.putVarInt(value: entrySize)
      try KeyType.visitSingular(value: k, fieldNumber: 1, with: &self)
      try visitSingularEnumField(value: v, fieldNumber: 2)
    }
  }

  mutating func visitMapField<KeyType: MapKeyType, ValueType: Message & Hashable>(
    fieldType: _ProtobufMessageMap<KeyType, ValueType>.Type,
    value: _ProtobufMessageMap<KeyType, ValueType>.BaseType,
    fieldNumber: Int
  ) throws where KeyType.BaseType: Hashable {
    for (k,v) in value {
      encoder.startField(fieldNumber: fieldNumber, wireFormat: .lengthDelimited)
      var sizer = BinaryEncodingSizeVisitor()
      try KeyType.visitSingular(value: k, fieldNumber: 1, with: &sizer)
      try sizer.visitSingularMessageField(value: v, fieldNumber: 2)
      let entrySize = sizer.serializedSize
      encoder.putVarInt(value: entrySize)
      try KeyType.visitSingular(value: k, fieldNumber: 1, with: &self)
      try visitSingularMessageField(value: v, fieldNumber: 2)
    }
  }

  /// Called for each extension range.
  mutating func visitExtensionFields(fields: ExtensionFieldValueSet, start: Int, end: Int) throws {
    try fields.traverse(visitor: &self, start: start, end: end)
  }
}
