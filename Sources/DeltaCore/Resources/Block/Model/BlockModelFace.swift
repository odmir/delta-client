import Foundation
import simd

/// A descriptor for a block model element's face
public struct BlockModelFace {
  /// The direction the face should face before transformations are applied.
  /// This won't always be the direction the face ends up facing.
  public var direction: Direction
  /// The actual direction the face will be facing after transformations are applied.
  public var actualDirection: Direction
  /// Face texture uv coordinates. One uv coordinate for each corner of the face (4 total).
  public var uvs: [simd_float2] // TODO: add a bit of info on which corner is which
  /// The index of the texture to use in the texture palette.
  public var texture: Int
  /// The direction that a culling block must be in for this face not to be rendered.
  public var cullface: Direction?
  /// The index of the tint to use.
  public var tintIndex: Int
  
  public init(direction: Direction, actualDirection: Direction, uvs: [simd_float2], texture: Int, cullface: Direction? = nil, tintIndex: Int) {
    self.direction = direction
    self.actualDirection = actualDirection
    self.uvs = uvs
    self.texture = texture
    self.cullface = cullface
    self.tintIndex = tintIndex
  }
}
