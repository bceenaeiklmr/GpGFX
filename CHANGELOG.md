## Changelog

### 0.7.3 — 13-04-2025

#### Example
- Added: [MouseTrail.ahk](https://github.com/bceenaeiklmr/GpGFX/blob/main/example/project/MouseTrail.ahk) to display a colorful trail of pies.

#### Fixes
- Fixed: Text rendering quality works correctly.
- Fixed: `Shape.Text` method's Font Quality parameter.
- Fixed: `Shape.Color.LinearGradientMode` now correctly accepts color values.
- Fixed: `TextureBrush` behavior.
- Fixed: `Shape.Filled` now toggles correctly between values.
- Fixed: `Shape.PenWidth` property.
- Fixed: Shapes with `Filled = 0` now result in `PenWidth = 1`; if `Filled > 1`, the assigned `PenWidth` is respected.
- Fixed: Tool switching now correctly reverts from Pen (`Shape.Filled := false`).

#### Improvements
- `Shape.Color` is now a property, added example usage.
- `Shape.Alpha` is now a property, added example usage.
- `Shape.Filled` is now a property, added example usage.
- General performance improvement: AHK functions are faster due to using commas between function calls.

#### Features
- Quality settings property implemented for layers (`layer.quality`): `"fast|low"`, `"balanced|normal"`, `"high|quality"`.
- The default quality setting is `balanced`, curved shapes are anti-aliased.

---

### 0.7.2 — 23-03-2025

#### Features
- New `Shape` methods: `RollUp`, `RollDown` (supporting single and multiple objects).
- `Layer.toFile(filepath)` method added — exports the layer to a PNG file.
- `Screenshot` function added.
- Strings can now display multiple colors.

#### Improvements
- `Layer.prepare` is now a static method and has been reworked — allows shapes to animate during drawing.
- Font quality changes fixed — text rendering quality now updates correctly for shapes.

---

### 0.7.1 — 17-03-2025

#### Changes
- `CreateGraphicsObjectGrid` renamed to `CreateGraphicsObject`:
  - The previous `CreateGraphicsObject` was removed due to redundancy.
  - Now correctly sets `x`, `y` coordinates and padding.

#### Features
- New `Layer` method: `move`.

#### Fixes & Improvements
- Shape tool switching logic updated for gradient color handling.
- `Color` class: `transition` now used as correct transition type.
- AHK version requirement updated from `v2.0.18` to `v2`.
- "Goodbye" string changed to "exiting..."; now disabled by default.
- RAL colors moved out of the `Color` class — functionality remains unchanged.

#### Examples
- Added new examples: animated ellipse, custom tooltip, simple game menu, object creation test.

#### Misc
- Minor comment typo fixes.

---

### 0.7.0 — 15-03-2025

#### Initial Release
- First public release.
