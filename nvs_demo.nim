import
  math,
  sdl2/sdl,
  sdl2/sdl_image as img, # for image loading
  sdl2/sdl_gfx_primitives, sdl2/sdl_gfx_primitives_font # for text output


converter toColor*(u: uint32): Color =
  ##  0xRRGGBBAA to Color(r, g, b, a)
  ##
  Color(r: uint8(u shr 24), g: uint8(u shr 16), b: uint8(u shr 8), a: uint8(u))


const
  BackgroundColor: Color = 0x9090e0ff'u32
  Details = [0.3, 0.025, 0.02, 0.015, 0.01, 0.005, 0.0015, 0.001, 0.0005, 0.0]
  DistanceMin = 100
  DistanceMax = 2000
  MapSquare = 1024 * 1024
  WindowTitle = "Nim VoxelSpace Demo (SDL2)"
  UpdateInterval = 10 # in ms
  Maps = [
    ("C1W",  "D1"),
    ("C2W",  "D2"),
    ("C3",   "D3"),
    ("C4",   "D4"),
    ("C5W",  "D5"),
    ("C6W",  "D6"),
    ("C7W",  "D7"),
    ("C8",   "D6"),
    ("C9W",  "D9"),
    ("C10W", "D10"),
    ("C11W", "D11"),
    ("C12W", "D11"),
    ("C13",  "D13"),
    ("C14",  "D14"),
    ("C14W", "D14"),
    ("C15",  "D15"),
    ("C16W", "D16"),
    ("C17W", "D17"),
    ("C18W", "D18"),
    ("C19W", "D19"),
    ("C20W", "D20"),
    ("C21",  "D21"),
    ("C22W", "D22"),
    ("C23W", "D21"),
    ("C24W", "D24"),
    ("C25W", "D25"),
    ("C26W", "D18"),
    ("C27W", "D15"),
    ("C28W", "D25"),
    ("C29W", "D16"),
  ]


type
  Camera = object
    pos: tuple[x, y: float]
    height, angle, horizon, details: float
    distance: int

  Input = object
    forwardBackward, leftRight, upDown: float
    lookUp, lookDown, mouse: bool
    mousePosition: tuple[x, y: int32]

  Map = tuple
    height: array[MapSquare, uint8]
    color:  array[MapSquare, Color]
    index:  int


var
  camera: Camera
  info = true
  input: Input
  map: Map
  running = false
  window: sdl.Window
  windowSize = (w: 800, h: 600)
  renderer: sdl.Renderer


proc loadMap(index: int): bool =
  let
    colorName = "maps/" & Maps[index][0] & ".png"
    heightName = "maps/" & Maps[index][1] & ".png"

  var
    colorSurface = img.load(colorName)
    heightSurface = img.load(heightName)

  if colorSurface == nil:
    sdl.logCritical(sdl.LogCategoryError, "Can't load color map %s", colorName)
    return false

  if heightSurface == nil:
    sdl.logCritical(sdl.LogCategoryError, "Can't load height map %s", heightName)
    return false

  map.index = index

  discard lockSurface(colorSurface)
  discard lockSurface(heightSurface)

  var
    colorPixels = cast[ptr uint8](colorSurface.pixels)
    heightPixels = cast[ptr uint8](heightSurface.pixels)
    color: Color

  for i in 0..<MapSquare:
    ptrMath:
      # color
      color = colorPixels[i].uint32.getRGBA(colorSurface.format)
      map.color[i] = color
      # height
      map.height[i] = heightPixels[i].uint8


  unlockSurface(colorSurface)
  unlockSurface(heightSurface)

  freeSurface(colorSurface)
  freeSurface(heightSurface)

  return true


proc init(): bool =
  # SDL2
  if sdl.init(sdl.InitEverything) != 0:
    sdl.logCritical(
      sdl.LogCategoryError, "Can't init SDL: %s", sdl.getError)
    return false

  if img.init(img.InitPNG) == 0:
    sdl.logCritical(
      sdl.LogCategoryError, "Can't init SDL_image: %s", img.getError)
    return false

  window = sdl.createWindow(
    WindowTitle, sdl.WindowPosUndefined, sdl.WindowPosUndefined,
    windowSize.w, windowSize.h, sdl.WindowResizable)
  if window == nil:
    sdl.logCritical(
      sdl.LogCategoryError, "Can't create window: %s", sdl.getError)

  renderer = sdl.createRenderer(
    window, -1, sdl.RendererAccelerated or sdl.RendererPresentVsync)
  if renderer == nil:
    sdl.logCritical(
      sdl.LogCategoryError, "Can't create renderer: %s", sdl.getError)

  # Camera
  camera.pos.x = 512.0
  camera.pos.y = 800.0
  camera.height = 78.0
  camera.angle = 0.0
  camera.horizon = 100.0
  camera.details = 0.01
  camera.distance = 800

  # Map
  for i in 0..<MapSquare:
    map.color[i] = 0x705000ff'u32
    map.height[i] = 0

  return loadMap(0)


proc free() =
  destroyRenderer(renderer)
  destroyWindow(window)
  img.quit()
  sdl.quit()


proc handleEvent(event: sdl.Event) =
  case event.kind:
  of sdl.KeyDown:
    case event.key.keysym.scancode:
    of sdl.ScancodeEscape: # Exit
      running = false
    of sdl.ScancodeLeft, sdl.ScancodeA:
      input.leftRight = 1.0
    of sdl.ScancodeRight, sdl.ScancodeD:
      input.leftRight = -1.0
    of sdl.ScancodeUp, sdl.ScancodeW:
      input.forwardBackward = 3.0
    of sdl.ScancodeDown, sdl.ScancodeS:
      input.forwardBackward = -3.0
    of sdl.ScancodeR:
      input.upDown = 2.0
    of sdl.ScancodeF:
      input.upDown = -2.0
    of sdl.ScancodeE:
      input.lookUp = true
    of sdl.ScancodeQ:
      input.lookDown = true
    of sdl.Scancode1..sdl.Scancode0:
      camera.details = Details[event.key.keysym.scancode.int - sdl.Scancode1.int]
    of sdl.ScancodeZ:
      camera.distance = (camera.distance - 100).clamp(DistanceMin, DistanceMax)
    of sdl.ScancodeX:
      camera.distance = (camera.distance + 100).clamp(DistanceMin, DistanceMax)
    of sdl.ScancodeI:
      info = not info
    of sdl.ScancodeN:
      let index = if map.index > 0: map.index - 1 else: Maps.high
      discard loadMap(index)
    of sdl.ScancodeM:
      let index = if map.index < Maps.high: map.index + 1 else: 0
      discard loadMap(index)
    else: discard

  of sdl.KeyUp:
    case event.key.keysym.scancode:
    of sdl.ScancodeLeft, sdl.ScancodeA:
      input.leftRight = 0
    of sdl.ScancodeRight, sdl.ScancodeD:
      input.leftRight = 0
    of sdl.ScancodeUp, sdl.ScancodeW:
      input.forwardBackward = 0
    of sdl.ScancodeDown, sdl.ScancodeS:
      input.forwardBackward = 0
    of sdl.ScancodeR:
      input.upDown = 0
    of sdl.ScancodeF:
      input.upDown = 0
    of sdl.ScancodeE:
      input.lookUp = false
    of sdl.ScancodeQ:
      input.lookDown = false
    else: discard

  of sdl.MouseButtonDown:
    input.forwardBackward = 3.0
    input.mousePosition = (event.motion.x, event.motion.y)
    input.mouse = true

  of sdl.MouseButtonUp:
    input.forwardBackward = 0
    input.leftRight = 0
    input.upDown = 0
    input.mouse = false

  of sdl.MouseMotion:
    if input.mouse and input.forwardBackward != 0:
      let
        diffX = (input.mousePosition.x - event.motion.x) / windowSize.w
        diffY = (input.mousePosition.y - event.motion.y) / windowSize.h
      input.leftRight = diffX * 2
      camera.horizon = diffY * 500
      input.upDown = diffY * 10

  of sdl.WindowEvent:
    case event.window.event:
    of sdl.WindowEventResized:
      windowSize = (event.window.data1.int, event.window.data2.int)
    else: discard
  else: discard


template mapOffset(pos: tuple[x, y: float]): int =
  (((pos.y.floor.int and 1023) shl 10) + (pos.x.floor.int and 1023))


proc updateCamera(ms: int) =
  let elapsed = ms.float * 0.03

  if input.leftRight != 0:
    camera.angle += input.leftRight * 0.1 * elapsed

  if input.forwardBackward != 0:
    camera.pos.x -= input.forwardBackward * sin(camera.angle) * elapsed
    camera.pos.y -= input.forwardBackward * cos(camera.angle) * elapsed

  if input.upDown != 0:
    camera.height += input.upDown * elapsed

  if input.lookUp:
    camera.horizon += 2 * elapsed

  if input.lookDown:
    camera.horizon -= 2 * elapsed

  # Collision detection
  var mapoffset = mapOffset(camera.pos)
  let mapHeight = map.height[mapoffset].float + 10
  if mapHeight > camera.height:
    camera.height = mapHeight


proc line(x, y1, y2: int, c: Color) =
  let y1: int = if y1 < 0: 0 else: y1
  if y1 > y2: return
  discard renderer.setRenderDrawColor(c.r, c.g, c.b, c.a)
  discard renderer.renderDrawLine(x, y1, x, y2)


proc render() =
  let
    sinAngle = sin(camera.angle)
    cosAngle = cos(camera.angle)

  var
    hiddenY = newSeq[int](windowSize.w)
    dz = 1.0

  for i in 0..<windowSize.w:
    hiddenY[i] = windowSize.h

  # draw from front to back
  var z = 1.0
  while z < camera.distance.float:
    # 90 degree field of view
    let
      sinAngleZ = sinAngle * z
      cosAngleZ = cosAngle * z

    var
      pLeft = (x: -cosAngleZ - sinAngleZ,
               y:  sinAngleZ - cosAngleZ)
      pRight= (x:  cosAngleZ - sinAngleZ,
               y: -sinAngleZ - cosAngleZ)
      dx = (pRight.x - pLeft.x) / windowSize.w.float
      dy = (pRight.y - pLeft.y) / windowSize.w.float
      invz = 1.0 / z * 240.0

    pLeft.x += camera.pos.x
    pLeft.y += camera.pos.y

    for i in 0..<windowSize.w:
      let
        mapoffset = mapOffset(pLeft)
        heightOnScreen = int(
          (camera.height - map.height[mapoffset].float) * invz + camera.horizon)

      line(i, heightOnScreen, hiddenY[i], map.color[mapoffset])

      if heightOnScreen < hiddenY[i]:
        hiddenY[i] = heightOnScreen
      pLeft.x += dx
      pLeft.y += dy

    z += dz
    dz += camera.details
  # while z < camera.distance


template timeDiff(a, b: uint64): int =
  int(((b - a) * 1000) div sdl.getPerformanceFrequency())


# COUNT

type
  Count = ref object
    counter, current, interval: int
    lastTime: uint64

proc newCount(interval: int = 1000): Count =
  new result
  result.counter = 0
  result.current = 0
  result.interval = interval
  result.lastTime = sdl.getPerformanceCounter()

proc update(count: Count) =
  inc(count.counter)
  let currTime = sdl.getPerformanceCounter()
  if timeDiff(count.lastTime, currTime) > count.interval:
    count.current = count.counter
    count.counter = 0
    count.lastTime = currTime



# RUN

proc run() =
  if running:
    sdl.logError(sdl.LogCategoryError, "Already running")
  running = true

  var
    timePrev, timeCurr: uint64
    elapsed, lag, updateCounter: int
    event: sdl.Event
    fps = newCount()

  gfxPrimitivesSetFont(nil, 0, 0)

  while running:
    timeCurr = sdl.getPerformanceCounter()
    elapsed = timeDiff(timePrev, timeCurr)
    timePrev = timeCurr
    lag += elapsed

    # Update
    updateCounter = 0
    while lag >= UpdateInterval:
      updateCamera(UpdateInterval)
      lag -= UpdateInterval
      inc updateCounter

    # Events
    while sdl.pollEvent(addr(event)) != 0:
      if event.kind == sdl.Quit:
        running = false
        break
      handleEvent(event)

    # Clear screen
    discard renderer.setRenderDrawColor(BackgroundColor)
    discard renderer.renderClear()

    # Render
    render()
    if info:
      discard renderer.boxColor(4, 4, 320, 88, 0x60000000'u32)
      discard renderer.stringColor(8, 8,
        $fps.current & " FPS", 0xffffffff'u32)
      discard renderer.stringColor(8, 24,
        "Map " & Maps[map.index][0] & " (prev/next map: N/M)", 0xffffffff'u32)
      discard renderer.stringColor(8, 40,
        "Fly: WASD, arrows, or mouse click", 0xffffffff'u32)
      discard renderer.stringColor(8, 52,
        "Pitch: Q/E, Altitude: R/F", 0xffffffff'u32)
      discard renderer.stringColor(8, 64,
        "Draw distance: Z/X, Detail level: 1..0", 0xffffffff'u32)
      discard renderer.stringColor(8, 76,
        "Toggle info: I", 0xffffffff'u32)
    renderer.renderPresent()

    # FPS
    fps.update()

  # while running

  echo "Shutting down."
  free()


# START

if init():
  echo "Init complete, running..."
  run()
else:
  echo "Can't init the demo!"
