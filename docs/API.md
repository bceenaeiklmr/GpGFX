# GpGFX API Catalog (for AI-assisted development)

Read this BEFORE writing any GpGFX code. Every feature listed here is
already implemented in `core/`. Do not hand-roll math, animation,
gradients, timing, or pixel loops that the engine already provides.
When a feature here fits your need, use it — and copy the matching
demo from `examples/demos/` as the working reference (see §16).

Rule (AGENTS.md #7, engine-first discovery): search this catalog and
`examples/` first; only invent new logic when nothing here covers it.

Mental model: `Layer` (a real layered Win32 window with a backing
buffer) holds `Shape` objects (retained-mode, mutable properties).
`Draw(lyr)` / `lyr.Draw(intervalMs, updateFn)` / `Render.Layer(lyr)` /
`FrameTimer` render the shape list. Everything else (color, fonts,
bitmaps, tools, timing, IPC, workers) supports that pipeline.

Include once: `#include <path>\GpGFX.ahk` — pulls in all of `core/`.

## 0. Never hand-roll (use the primitive)

Full reference with exact signatures, defaults, `@example` blocks and "Used in" demo links:
`kb/reference/<CoreFile>.md` (index: `kb/README.md`). Working demos by purpose: `kb/examples.md`.
Both are generated from the JSDoc by `tools/BuildKB.ahk`; regenerate after changing `core/` or demos.

| If you are about to write... | Use instead | Reference |
|---|---|---|
| easing / tween math, lerp over time | `shp.Animate(prop, to, ms, easing)`, `Signal.Animate(...)`, `Time.Ease.*` | Shape.md, Time.md |
| color channel math, color lerp, HSL | `Color.Mix(c1, c2, w)`, `Color.Transition`, `Color.FromHSL`, `Color.ToHSL` | Color.md |
| multi-stop gradient, heatmap colors | `ColorBuffer(stops*).Sample(t)`, presets `ColorBuffer.Turbo/Viridis/Plasma/...` | Color.md |
| theme colors | `Palette.Nord` / `Palette.Get(name)`, `.bg .text .accent`, `.Sample(t)` | Palette.md |
| SetTimer or Sleep render loop | `lyr.Draw(intervalMs, updateFn)`, `Render.Layer(lyr)`, `FrameTimer.Start(fn, fps)` | Layer.md, Draw.md, FrameTimer.md |
| Gui + UpdateLayeredWindow overlay | `Layer(x, y, w, h)` + shapes; `Clickthrough`, `TopMost`, `Drag` | Layer.md |
| DllCall("gdiplus\...") drawing | Shape factories, `Pen`, `SolidBrush`, `LinearGradientBrush`, `PathGradientBrush`, `Graphics` | Shapes.md, Tool.md, Graphics.md |
| fade in/out alpha loop | `Layer.FadeIn/FadeOut`, `Shape.FadeIn/FadeOut` | Layer.md, Shape.md |
| self-closing popup / toast timer | `lyr.Draw(-ms)` (negative = auto-dispose), `Layer.Timeout(ms)` | Layer.md |
| WinGetPos polling to follow a window | `Layer.SnapToWindow`, `Layer.FollowWindow`, `StopFollowing` | Layer.md |
| desktop widget behind windows | `Layer.AttachToDesktop()` | Layer.md |
| per-pixel color loop | `ColorLUT.*` + `ApplyLUT`, `LockBits`/`UnlockBits`, `SetPixel`/`GetPixel` | Color.md, Bitmap.md |
| pixel / image search | `PixelSearch`, `PatternSearch`, `PixelCount` | Bitmap.md, Shape.md |
| QueryPerformanceCounter timing | `Time.Qpc()`, `Time.Since(start)`, `MCode.QpcSpinWait` | Time.md, MCode.md |
| hover / click hit-testing | `Hover`, `OnHover`, `OnClick`, `OnEvent`, `Button` | Shape.md |
| word / character hit boxes in text | `GetWordRect`, `GetTextRangeRect`, `GetCharPos` | Shape.md |
| colored / bold text segments | inline markup `{#HEX}`, `{Name}`, `<b> <i> <u> <s>` in `Text(...)` | Shape.md |
| grid of rectangles layout | `CreateGraphicsObject(rows, cols, x?, y?, w?, h?, pad?)` | Shape.md |
| screenshots, layer to PNG | `Screenshot(...)`, `lyr.ToFile(path)`, `SaveLayer`, `GdipBitmap.FromScreen` | Function.md, Layer.md, Bitmap.md |
| FPS counter | `Fps(targetfps?, position?)` | Fps.md |
| parallel rendering | `WorkerPool`, `lyr.Async := true` | WorkerPool.md, Layer.md |

## 1. Layer (core/Layer.ahk) — canvas + window

`Layer(x?, y?, w?, h?, name?, hOwner?)` — omitted dims default to the
active layer / screen. `LayerStack.ActiveLayer` tracks it.

Lifecycle & rendering:
- `Draw(trigger?, updateFn?)` — start redraw loop (`trigger` = interval ms)
- `DrawOnce(afterMs, updateFn?)` — single scheduled redraw
- `Render()` — immediate synchronous render
- `Draw()` (static) — one-shot draw of the active layer
- `Step(dt)` — advance animations/signals manually (headless use)
- `Bind(sig, updateFn?)` — redraw when a Signal changes
- `Stop()`, `Timeout(ms)`, `Wait(timeoutMs, destroyAfter?)`, `Clear()`, `Clean()`, `Dispose()`
- `FadeIn(durationMs, targetAlpha?, onDone?)`, `FadeOut(durationMs, onDone?)`
- `SetAlpha(val)`, `SetQuality("low"|"mid"|"high")` (AA preset)
- `Invalidate()`, `Prepare()`, `Debug(seconds, filled, alpha)`

Geometry & window state:
- `Move(x?, y?, w?, h?)`, `Resize(w, h)` (reallocates backing buffer), `Center()`
- `Show()`, `Hide()`, `ShowHide()`, `Activate()`, `TopMost(v)`, `AlwaysOnTop()`
- `Clickthrough(v)`, `NoActivate()`, `Drag(v?)`
- `SavePos(arr?)`, `RestorePos(obj)`
- Multi-monitor: `SetMonitor(disp, align, useWorkArea?)`, `MoveToMonitor(...)`,
  `GetCurrentMonitor()`, static `GetMonitors()`, `GetMonitor(disp)`, `GetVirtualScreen()`

Window relationships:
- `Attach(childLayer, xOff, yOff)`, `SyncAttachedLayers()`, `Swap(otherLayer)`
- `SnapToWindow(hwnd, xOff, yOff, resize?, follow?)`
- `FollowWindow(target, xOff, yOff, resize?, interval)`, `StopFollowing()`
- `AttachToDesktop(mode?)` / `PinToDesktop(mode?)`, `DetachFromDesktop()` (Rainmeter-style pinning)

Shapes & export:
- `Register(shapeObj)`, `Unregister(id)`, `BringToFront(shp)`, `SendToBack(shp)`, `DeleteShapes()`
- `OnEvent(eventName?, fn?, params*)` — layer-level Click etc.
- `GetPixel(x, y, outFormat?)`, `ToBitmap(cropToContent?)`, `ToFile(filepath, crop?, quality?)`,
  `ToClipboard(crop?)`, `ToASCII(targetW, ...)`

`LayerStack` (static): `ActiveLayer`, `Register(layer)`, `Unregister(id)`,
`Swap(l1, l2)`, `HideAll()`, `DisposeAll()`, `PushHistory(ptr)`, `PopHistory(ptr)`.

## 2. Shape base class (core/Shape.ahk) — every shape inherits these

Text:
- `Text(str?, colour?, size?, family?, style?, quality?, alignH?, alignV?, lineSpacing?, lineHeight?)`
- Rich markup inside the string: `<b> <i> <u> <s>`, `{#HEX}`, `{ColorName}`, `{reset}`, tabs, wrapping
- `TextAlign(h?, v?)` + shorthands `Left/Center/Right/Top/Middle/Bottom`,
  `TopLeft...BottomRight`, `MiddleLeft...MiddleRight` (all chainable)
- `TextOffset(dx, dy)` / `Shift(dx, dy)`
- `GetTextRangeRect(startChar, charLen?)`, `GetWordRect(word, occurrence?)`, `GetCharPos(charIndex)`
  — word/char bounding boxes for highlights, hit regions, callout anchoring

Geometry & state:
- `Move(x?, y?, w?, h?)`, `Position(x?, y?)` (accepts `"center"` etc.), `Show()`, `Hide()`, `ShowHide()`
- `SavePos(toArray?)`, `RestorePos(obj)`, `BringToFront()`, `SendToBack()`, `RedrawLayer()`

Animation & reactivity:
- `Animate(propName, toVal, durationMs?, easing?, onDone?)` — delta-timed property animation.
  Easing: `"linear"`, `"easeIn"`, `"easeOut"`, `"easeInOut"`, `"sine"`, `"bounce"`, or custom `fn(t)`
- `FadeIn/FadeOut/RollDown/RollUp` — built-in animation wrappers
- `Hover(hoverColour, normalColour?)`, `HoverAlpha(...)`, `OnHover(hoverColour, normalColour?, onClick?)`
- `OnEvent(event?, fn?, params*)`, `OnClick(fn, params*)`, `Button(label?, onClick?, ...)`
- `Bind(sig, fn?)`, `AddSignal(fn, params*)`, `HasSignal()`, `ExecuteSignals()`
- `Shrink(unit?)` / `Grow(delay?)` (instance and static batch forms)

Pixel/image ops (shapes that carry bitmaps):
- `AddImage(source, option?, effect?, x?, y?)` / alias `Image(...)` — source can be a file,
  `GdipBitmap`, HWND, or `{x,y,w,h}` screen region
- `ApplyLUT(lutB, lutG, lutR, lutA?)`, `GetPixel`, `SetPixel`, `PixelSearch(color, variation, x1, y1, x2, y2)`,
  `PixelCount(color, variation?)`, `LockBits(...)`, `UnlockBits(bmData)`
- `Resize(option?, cmatrix?)`, `RotateFlip(flip?)`, `Clone(x?, y?, w?, h?)`, `Crop(x, y, w, h)`,
  `ToFile(filepath)`, `ToClipboard()`, `ToASCII(...)`

`Signal` (Shape.ahk): reactive value. `Signal(initialValue)`, `.Value`,
`Subscribe(fn)`, `Unsubscribe(fn)`, `Notify()`; static
`Signal.Animate(sig, fromVal, toVal, durationMs?, easing?, onDone?)`.
Pattern: one signal drives width + color + label via `Bind` (see `SignalTransitions.ahk`).

## 3. Shape factories (core/Shapes.ahk)

All constructors accept shorthand forms (colors/flags can appear in any
order; omitted geometry auto-centers on the active layer). Outlined and
`Filled*` variants exist for most.

| Class | Constructor |
|---|---|
| `Rectangle` / `FilledRectangle` | `(x?, y?, w?, h?, colour?, filled?)` |
| `RoundedRectangle` (+ `RoundRect`, `RoundRectangle`, `FilledRoundedRectangle`, `FilledRoundRect`) | `(x?, y?, w?, h?, r?, colour?, filled?)` |
| `Square` / `FilledSquare` | `(x?, y?, size?, colour?, filled?)` |
| `Ellipse` / `FilledEllipse` | `(x?, y?, w?, h?, colour?, filled?)` |
| `Circle` / `FilledCircle` | `(x?, y?, r?, colour?, filled?)` |
| `Arc` | `(x?, y?, w?, h?, colour?, penwidth?, startangle?, sweepangle?)` |
| `Pie` / `FilledPie` | `(x?, y?, w?, h?, startangle?, sweepangle?, colour?, filled?)` — gauges, donuts, radial progress |
| `Triangle` / `FilledTriangle` | `(x1, y1, x2, y2, x3, y3, colour?, filled?)` |
| `Polygon` / `FilledPolygon` | `(colour?, filled?, fillmode?, aPoints?)` — arbitrary geometry, area charts |
| `Bezier` | `(x1, y1, x2, y2, x3, y3, x4, y4, colour?, penwidth?)` |
| `Beziers` | `(colour?, penwidth?, aPoints?)` — chained beziers |
| `Line` | `(x1, y1, x2, y2, colour?, penwidth?)` |
| `Lines` | `(colour?, penwidth?, aPoints?)` — polyline |
| `Point` | `(x?, y?, colour?, size?)` |
| `Curve` | `(points?, colour?, penwidth?, tension?)` — spline |
| `ClosedCurve` | `(points?, colour?, filled?, tension?, fillmode?)` — filled spline |
| `Container` / `Dummy` | `(x?, y?, w?, h?)` — group/anchor shapes |
| `Text` | `(str?, colour?, size?, family?, style?, quality?, alignH?, alignV?, lineSpacing?, lineHeight?)` |
| `Picture` / `Bitmap` / `Image` | `(source?, option?, effect?, ...)` + statics `FromFile`, `FromScreen`, `FromHWND`, `FromClipboard`, `FromHBITMAP`, `FromHICON`, `FromStream`, `FromMemory` |
| `Button` | `(label?, onClick?, hoverColour?, bgColour?, r?, ...)` — ready-made interactive button |

Invisible text container trick: `Rectangle(x, y, w, h, "0x00000000").Text(...)`.

## 4. Color (core/Color.ahk)

`Color(c?, alpha?)` — callable; accepts name, `#RGB`, `#ARGB`, `0xARGB`, int. Cached.

Statics: `Alpha(ARGB, A)`, `AlphaF(ARGB, A01)`, `Luminance(ARGB)`,
`Contrast(bgClr)`, `ChannelSwap(colour, mode?)`, `FromHSL(h, s, l, a?)`,
`ToHSL(color)`, `Mix(c1, c2, weight?)`, `LinearInterpolation(c1, c2, dist, alpha?)`,
`Transition(c1, c2, dist?, alpha?)`, `GetTransition(c1, c2, backforth?)` (continuous ramps),
`Random(colorName?, randomness?)`, `Randomize(ARGB, rand?)`, `RandomARGB()`,
`RandomARGBAlphaMax(alpha?, max?)`, `LoadFile(path)`, `SaveFile(path, section, map)`,
`AddPalette(name, colorMap)` (registers `Color.<Name>`), `AddGradient(name, colors, steps?)`
(registers `ColorBuffer.<Name>`), `RAL_load()`.

`ColorBuffer` (alias `Color.Buf` / `Color.Buffer`, global `ColorBuf(...)`):
multi-stop gradient LUT in unmanaged memory. `ColorBuffer(stops..., steps?)`,
`.Sample(t)` / `.Get(t)` (t = 0..1), `.Random()`, `.Reverse()`.
Preset ramps: `Turbo`, `Viridis`, `Plasma`, `Magma`, `Inferno`, `Rainbow`,
`Heatmap`, `CoolWarm`, `Neon`, `Sunset` (see `ColorBufferShowcase.ahk`).

`ColorLUT` — 256-entry channel tables applied as x64 machine code on Scan0
(~1.7 ms per 1080p frame). Statics build the tables: `Identity()`, `Invert()`,
`Posterize(levels?)`, `Threshold(cutoff?)`, `Solarize(cutoff?)`,
`BrightnessContrast(b?, c?)`, `Gamma(gamma?)`, `FromGradient(colorBuffer)`.
Apply: `ColorLUT.Apply(bitmap, lutB, lutG, lutR, lutA?)` or `bmp.ApplyLUT(...)`
or `ColorLUT.ApplyScan0(scan0, w, h, stride, ...)`.

## 5. Palette (core/Palette.ahk)

Built-in themes as static instances: `Palette.Catppuccin`, `.Nord`, `.Gruvbox`,
`.TokyoNight`, `.Dracula`, `.Solarized`, `.Cyberpunk`, `.Monokai`.
Each `PaletteInstance`: `.name`, `.colors`, `.bg`, `.text`, `.surface`,
`.accent`, `.accent2`, `.buffer`, `.Sample(t)`, `.Random()`.
Static API: `Palette.Get(name?)`, `Palette.Sample(name, t?)`, `Palette.Random(name?)`,
`Palette.Create(name, colors, bg?, text?, surface?, accent2?)`.

## 6. Brushes & pens (core/Tool.ahk)

`Pen(ARGB, penwidth?, mode?)`, `SolidBrush(ARGB)`,
`HatchBrush(fgARGB, bgARGB?, hatchStyle?)` (20+ GDI+ styles),
`TextureBrush(pBitmap, wrapmode?, resize?, x?, y?, w?, h?)`,
`LinearGradientBrush(fg, bg, x?, y?, w?, h?, gradMode?, wrapMode?)` with
`.Translate/.Rotate/.Scale/.ResetTransform/.SetPresetBlend`,
`PathGradientBrush(pointsOrPath, centerColor?, surroundColor?, wrapMode?)` with
statics `Radial(cx, cy, radius, ...)` and `FromRect(x, y, w, h, ...)`, plus
`.SetCenter`, `.SetCenterColor`, `.SetSurroundColor(s)`, `.SetFocusScales`, transforms.

Shape-level shortcut (no Tool objects needed): `shp.color` accepts brush
descriptor arrays — `["c1|c2|c3", "d1|d2", mode]` multi-stop gradient,
`["hatch", fg, bg, style]`, `["texture", bitmap, wrapMode, resize]`,
`["Gradient", c1, c2, mode]` (see `ToolSwitch.ahk`).

## 7. Bitmap & pixel access (core/Bitmap.ahk)

`GdipBitmap(source?, height?, cmatrix?)` — source: file path (resize % or
`"w300 h200"`; filter `bright/grayscale/invert/negative/sepia/redonly/greenonly/blueonly`),
`"cb"`/`"clip"`, HWND, HBITMAP/HICON, `{x,y,w,h}` screen region.
Statics: `FromScreen`, `FromHWND(hwnd, clientOnly?)`, `FromClipboard`,
`FromMemory(buf, size?)`, `FromStream`, `FromHBITMAP`, `FromHICON`.
Blank canvas: `GdipBitmap(w, h)` / `CreateFromScan0(w, h)` (32bpp premultiplied ARGB).

Ops: `Resize`, `RotateFlip`, `Clone(x?, y?, w?, h?)`, `Crop`, `ApplyLUT`,
`GetPixel(x, y, outFormat?)`, `SetPixel`, `LockBits(...)`/`UnlockBits` (raw Scan0),
`PatternSearch(pattern, ...)` and `PixelSearch(targetColor, ...)` (native kernel),
`SaveToFile(path, format?, quality?)` / `ToFile`, `ToMemory(format?, quality?)`,
`ToClipboard()`, `ToASCII(targetW, targetH?, ramp?, colored?, doubleChar?)`,
`Draw(gfx, x?, y?, w?, h?)`, `GetCached(gfx)` → `CachedBitmap` (pre-blended cache for repeated draws).
`ColorMatrix.get(name)` — named color transforms.

## 8. Fonts & text layout (core/Font.ahk, core/TextLayout.ahk)

`Font(family?, size?, style?, colour?, quality?, alignH?, alignV?)` — callable, cached.
Statics: `GetInstalledFonts()`, `LoadFromFile(fontPath)` (custom brand fonts),
`MeasureChar(fnt, ch)`, `MeasureString(fnt, text)` (subpixel metrics),
`ResolveQuality(size, family, style, isRotated?)`, `getStock()`,
`Release(fontOrId)`, `Unregister(id)`, `DestroyFont(fnt)`, `DisposeAll()`.
`TextLayout.Prepare(shape)` and `TextLayout.GetRangeRect(shape, startChar, charLen?)`
back the `GetWordRect`/`GetCharPos` APIs.

## 9. Timing, pacing, animation curves (core/Time.ahk, Fps.ahk, FrameTimer.ahk)

`Time`: `Now()`, `Since(start)`, `Qpc()`, `FromSeconds/FromMilliseconds/FromMinutes/FromHours`,
`Delay(ms)`.
`Time.Ease` statics (pure functions of t, deterministic): `Linear`, `InQuad`, `OutQuad`,
`InOutQuad`, `InCubic`, `OutCubic`, `InOutCubic`, `SmoothStep`, `Sine`.

Pacing options (benchmarked in `SleepVsRenderPacing.ahk`):
- `Draw(lyr)` — one-shot
- `lyr.Draw(intervalMs, updateFn?)` — SetTimer loop
- `Render.Layer(lyr)` / `Render.Layers(lyrs*)` / `Render.Call(lyr)` — QPC-paced frame
- `FrameTimer.Start(callback, fps?, autoMode?)`, `FrameTimer.Stop()`, `FrameTimer.SetFPS(fps)` —
  native C-thread pacing
- `Fps(targetfps?, position?, w?, h?)` — on-screen FPS meter: `.Display`, `.Position`,
  `.Update`, `.UpdateFreq`, `.SetTarget(fps)`, `.Toggle()`, `.Reset()`, `.Remove()`

## 10. Rendering pipeline (core/Draw.ahk, core/Graphics.ahk)

Global `Draw(lyr, updateWindow?)` — rasterize the layer's shape list into its backing buffer.
`Render` static class wraps per-layer/per-frame rendering.
`Graphics(w, h)`, `Graphics.FromHWND(hwnd, useICM?)`, `Graphics.FromHDC(hdc, hDevice?)` —
raw GDI+ graphics contexts when you need direct drawing outside the shape pipeline.

## 11. Parallelism & IPC (core/WorkerPool.ahk, core/Worker.ahk, core/IPC.ahk)

`WorkerPool` (static): `Init(count?)` spawns worker processes;
`AssignWorker(layer)`, `AutoDispatch(lyr)`, `Dispatch(lyr, workerIdx)`,
`PackLayer(lyr, workerIdx)`, `PackShapeSlice(lyr, workerIdx, start, end)`,
`StepWorker(workerIdx, dt?)`, `WaitForAll(timeout?)`,
`Composite(targetLayer, layers*)`, `Shutdown()`.
Workers rasterize directly into shared-memory Scan0 (zero-copy).

`IPC`: `FileMapping(name?, access?, protect?, size?)` with `.Write(data, offset?)` /
`.Read(buffer?, offset?, size?)`; `Mutex(name?)` with `.Lock(timeout?)` / `.Release()`;
`Semaphore(initialCount?, maxCount?, name?)` with `.Wait(timeout?)` / `.Release(count?)`;
`Worker.Spawn()`, `Worker.OffloadQpcSleep(targetTick)`, `Worker.Shutdown()`.

## 12. Native hot paths (core/MCode.ahk, src/*.c)

`MCode.Call(code)` — execute raw x64 machine code.
`MCode.InitHiResTimer()`, `HiResWait(ms)`, `DisposeHiResTimer()`,
`InitQPC()`, `QpcSpinWait(targetTick)` — sub-ms precision waits.
`BatchComputeBounds(pPoints, count, outBuf?)`, `BatchTranslate(pPoints, count, dx, dy)` —
batched point math for particle/geometry systems.
Checked-in C kernels: `bounds.c`, `colorlut.c`, `pixelsearch.c`, `qpc_spin.c`,
`throttle.c`, `translate.c`, `blend.c` (SSE2 full-frame 1080p alpha blend ~0.5 ms).

## 13. Global helpers (core/Function.ahk)

`Clean()` (dispose all layers), `Screenshot(filepath?, x?, y?, w?, h?)`,
`SaveLayer(lyr, filepath, cropToContent?)`, `GetMonitorInfo()`,
`WinGetVisiblePos(hwnd, ...)`, `itoARGB(int, rgb?)`, `IsARGB(ARGB)`,
`PositionByNumber(n)`, `TopMsg(text, title?, options?)`, `Alert(text, ...)`,
`ModifyX(shapeObj, x?)`, `End(delay?)`, `Welcome(delay?)`, `GoodBye(delay?)`.

## 14. Dialogs & debug (core/Dialog.ahk, core/Debug.ahk)

`Dialog.MsgBox(text?, title?, options?, config?)`, `Dialog.Input(prompt?, title?, defaultText?, placeholder?, options?)`,
`Dialog.GetThemeColors(themeName?, customAccent?)` — styled native dialogs.
`Debug.Register(name, fn)`, `Unregister(name)`, `Poll()`, `GetSummary()`,
`GetPhysicalCoreCount()`, `GetLogicalProcessorCount()` — frame-time profiling.

## 15. What GpGFX does NOT have (do not search for it)

- No video decoding (H.264/HEVC/AV1) — pipe frames in via FFmpeg rawvideo/Scan0
- No audio — mux externally (FFmpeg)
- 32-bit ARGB only — no 4:2:0 / 10-bit
- No 3D engine — 3D demos (StaticCube, DynamicGradientSphere) are manual projections of 2D shapes
- No scene graph / layout manager — layout is explicit coordinates (see README "Shapes in Practice")

## 16. Demo index (working reference per feature)

| Want to do | Read |
|---|---|
| Per-frame retained-mode animation loop | `examples/demos/LorenzAttractor.ahk` |
| Signal-driven reactive UI | `SignalTransitions.ahk`, `SignalStateSync.ahk` |
| Gradient ramps / data colors | `ColorBufferShowcase.ahk`, `ColorSmoothTransition.ahk` |
| Gradient / hatch / texture fills | `ToolSwitch.ahk`, `PathGradientShowcase.ahk` |
| Spline / bezier / polygon charts | `SplineCurves.ahk`, `AllShapesConstruction.ahk`, `Polygon.ahk` |
| Rich text, word rects, tabs | `RichTextStyleShowcase.ahk`, `TextRangeMeasureDemo.ahk`, `TabAndLineHeightDemo.ahk` |
| Screen/HWND capture into shapes | `BitmapSources.ahk`, `NewFeatures_Showcase.ahk` |
| Procedural pixels, SetPixel loops | `BitmapPixelAccess.ahk` |
| Bitmap memory round-trips, PixelSearch | `NewFeatures_Showcase.ahk`, `BitmapClipboard.ahk` |
| WorkerPool parallel rasterization | `AsyncLayer_Showcase.ahk`, `MultiWorker_QuadPattern.ahk` |
| Pacing comparison | `FrameTimerNative.ahk`, `SleepVsRenderPacing.ahk` |
| Desktop widgets, toasts, snapping, following | `DesktopWidgetDemo.ahk`, `ToastNotificationDemo.ahk`, `SnapToWindow.ahk`, `WindowFollowTracking.ahk` |
| Multi-monitor geometry | `MonitorTest.ahk` |
| AA quality presets | `QualityPresetDemo.ahk` |
| Particles / trails | `MouseTrail.ahk` |
| Full interactive app pattern | `examples/apps/TetrisGame.ahk` |
| Shorthand constructor forms | `ShorthandShapes.ahk` |
| Perf baselines | `benchmarks/FractalTree.ahk`, `ObjectGrid.ahk`, `LorenzSystem.ahk` |

Video-pipeline-specific catalog (footage overlay, LUT grading, FFmpeg
assembly): `private/VideoCreator/docs/gpgfx_api.md`.
