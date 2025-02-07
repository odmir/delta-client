import Foundation
import MetalKit

// TODO: remove when not needed anymore
var stopwatch = Stopwatch(mode: .summary)

public class RenderCoordinator: NSObject, MTKViewDelegate {
  private var client: Client
  
  private var camera: Camera
  private var physicsEngine: PhysicsEngine
  private var worldRenderer: WorldRenderer?
  
  private var commandQueue: MTLCommandQueue
  
  private var frame = 0
  
  private var device: MTLDevice
  
  public init(client: Client) {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("failed to get metal device")
    }
    
    guard let commandQueue = device.makeCommandQueue() else {
      fatalError("failed to make render command queue")
    }
    
    self.client = client
    self.device = device
    self.commandQueue = commandQueue
    
    // Setup physics engine
    // TODO: put physics engine in the client instead of the renderer
    physicsEngine = PhysicsEngine(client: client)
    
    // Setup camera
    let fovDegrees: Float = 90
    let fovRadians = fovDegrees / 180 * Float.pi
    camera = Camera()
    camera.setFovY(fovRadians)
    
    super.init()
    
    // Create world renderer
    if let world = client.server?.world {
      do {
        worldRenderer = try WorldRenderer(device: device, world: world, client: client, resourcePack: client.resourcePack, commandQueue: commandQueue)
      } catch {
        log.critical("Failed to create world renderer")
        client.eventBus.dispatch(ErrorEvent(error: error, message: "Failed to create world renderer"))
      }
    }
    
    // Register listener for changing worlds
    client.eventBus.registerHandler { [weak self] event in
      guard let self = self else { return }
      self.handleClientEvent(event)
    }
  }
  
  public func draw(in view: MTKView) {
    stopwatch.startMeasurement("whole frame")
    guard
      client.server?.world != nil,
      let player = client.server?.player,
      let worldRenderer = worldRenderer
    else {
      return
    }
    
    updatePhysics()
    updateCamera(player, view)
    
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      return
    }
    
    stopwatch.startMeasurement("world renderer")
    worldRenderer.draw(device: device, view: view, commandBuffer: commandBuffer, camera: camera, commandQueue: commandQueue)
    stopwatch.stopMeasurement("world renderer")
    
    guard let drawable = view.currentDrawable else {
      log.warning("Failed to get current drawable")
      return
    }
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
    
    logFrame()
    stopwatch.stopMeasurement("whole frame")
  }
  
  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
  
  private func updatePhysics() {
    client.server?.player.updateVelocity()
    physicsEngine.update()
  }
  
  private func updateCamera(_ player: Player, _ view: MTKView) {
    let aspect = Float(view.drawableSize.width / view.drawableSize.height)
    camera.setAspect(aspect)
    camera.setPosition(player.eyePositon.vector)
    camera.setRotation(playerLook: player.look)
    camera.cacheFrustum()
  }
  
  private func handleClientEvent(_ event: Event) {
    switch event {
      case let event as JoinWorldEvent:
        do {
          worldRenderer = try WorldRenderer(
            device: device,
            world: event.world,
            client: client,
            resourcePack: client.resourcePack,
            commandQueue: commandQueue)
        } catch {
          log.critical("Failed to create world renderer")
          client.eventBus.dispatch(ErrorEvent(error: error, message: "Failed to create world renderer"))
        }
      case let event as ChangeFOVEvent:
        let fov = MathUtil.radians(from: Float(event.fovDegrees))
        camera.setFovY(fov)
      default:
        break
    }
  }
  
  private func logFrame() {
    frame += 1
    if frame % 100 == 0 {
      stopwatch.summary(repeats: 100)
      stopwatch.reset()
      print("")
    }
  }
}
