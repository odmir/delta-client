// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: CacheBlockModelElementFace.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

//
//  CacheBlockModelElementFace.proto
//  DeltaClient
//
//  Created by Rohan van Klinken on 31/3/21.

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

struct CacheBlockModelElementFace {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var uvs: [Float] = []

  var textureIndex: UInt32 = 0

  var cullFace: CacheFaceDirection {
    get {return _cullFace ?? .up}
    set {_cullFace = newValue}
  }
  /// Returns true if `cullFace` has been explicitly set.
  var hasCullFace: Bool {return self._cullFace != nil}
  /// Clears the value of `cullFace`. Subsequent reads from it will return its default value.
  mutating func clearCullFace() {self._cullFace = nil}

  var tintIndex: Int32 = 0

  var light: Float = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _cullFace: CacheFaceDirection? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension CacheBlockModelElementFace: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "CacheBlockModelElementFace"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "uvs"),
    2: .same(proto: "textureIndex"),
    3: .same(proto: "cullFace"),
    4: .same(proto: "tintIndex"),
    5: .same(proto: "light"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedFloatField(value: &self.uvs) }()
      case 2: try { try decoder.decodeSingularUInt32Field(value: &self.textureIndex) }()
      case 3: try { try decoder.decodeSingularEnumField(value: &self._cullFace) }()
      case 4: try { try decoder.decodeSingularSInt32Field(value: &self.tintIndex) }()
      case 5: try { try decoder.decodeSingularFloatField(value: &self.light) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.uvs.isEmpty {
      try visitor.visitPackedFloatField(value: self.uvs, fieldNumber: 1)
    }
    if self.textureIndex != 0 {
      try visitor.visitSingularUInt32Field(value: self.textureIndex, fieldNumber: 2)
    }
    if let v = self._cullFace {
      try visitor.visitSingularEnumField(value: v, fieldNumber: 3)
    }
    if self.tintIndex != 0 {
      try visitor.visitSingularSInt32Field(value: self.tintIndex, fieldNumber: 4)
    }
    if self.light != 0 {
      try visitor.visitSingularFloatField(value: self.light, fieldNumber: 5)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CacheBlockModelElementFace, rhs: CacheBlockModelElementFace) -> Bool {
    if lhs.uvs != rhs.uvs {return false}
    if lhs.textureIndex != rhs.textureIndex {return false}
    if lhs._cullFace != rhs._cullFace {return false}
    if lhs.tintIndex != rhs.tintIndex {return false}
    if lhs.light != rhs.light {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}