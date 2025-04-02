# GpGFX

GpGFX is a graphics library for AutoHotkey v2, providing drawing and rendering capabilities using Gdiplus (also known as GDI+). It includes classes for creating and manipulating shapes, colors, fonts, layers, and more. For more information on GDI+, visit the [Microsoft documentation](https://docs.microsoft.com/en-us/windows/win32/gdiplus/-gdiplus-start). This is still an early version of the library, so expect some bugs and changes.

## Features

- Watch a demo of GpGFX in action on [YouTube](https://www.youtube.com/watch?v=mAJyPSuNsOk).
- Watch the presentation [CS50x - Final Project](https://www.youtube.com/watch?v=WuQWpn-uma4).

### General
- Provides an intuitive, easy-to-use API to draw graphics objects onto the screen.
- Provides debugging information about resource management.
- Manages freeing up used resources automatically.

## Installation
1. Ensure you have the latest version of [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.zip) installed.
2. Clone or download this repository.
3. Visit the example folder and run the files.  
4. There is a standalone file; you can rename it to GpGFX.ahk and use it. (optional)

## Example

Visit the [example](https://github.com/bceenaeiklmr/GpGFX/tree/main/example) folder where you can find multiple files with comments.

## Layer

A **layer** is a container for drawing operations. It holds shapes, text, and images that can be drawn onto the layer.

It is a transparent window and a GUI in AutoHotkey.

```ahk
; A layer will be the size of the main display if no parameters are specified
lyr := Layer()

; Create a square with a size of 100 pixels, centered automatically by omitting the x and y parameters.
; The color will be either red or yellow.
sq := Square(, , 100, "Red|Yellow")
sq.str := "Hello, World!"

; Display the shape for a second
Draw(lyr)
Sleep(1000)

; Destroy the window and exit the script
End()
```

## Shapes

### Available base shapes:

`Rectangle`, `Square`, `Ellipse`, `Pie`, `Polygon`, `Triangle`, `Point`, `Line`, `Lines`, `Arc`, `Bezier`, `Beziers`

### Fillable shapes:

`Rectangle`, `Square`, `Ellipse`, `Pie`, `Polygon`, `Triangle`

### Available properties:

Add text. The string will be auto-centered within the shape by default.
```ahk
rect.str := "Hello, " A_UserName
```

Add an image: 
```ahk
resize := 50 ; %
rect.AddImage(imgPath, resize, "Sepia")
```

Change color:
```ahk
; Using common formats
rect.Color := "#00FF00"

; Random color
rect.Color := ""

; Random color from a list of colors
rect.Color := "red|green|blue"

; Change to Linear Gradient Mode
rect.Color := ["red", "orange"]

; ... see the examples
```

Change fill and alpha properties to modify the shape, and so on.

## Credits

I want to thank everyone who contributes to the AHK community.

- **[iseahound](https://github.com/iseahound)**: Graphics, Textrender, and ImagePut projects provided me guidance in many cases. Thank you for your work.
- **[tic](https://github.com/tariqporter/)**: for creating the original Gdip library.
- **Contributors**: for contributing to the library [AHKv2-Gdip](https://github.com/mmikeww/AHKv2-Gdip)
  - **[mmikeww](https://github.com/mmikeww)**, **[buliasz](https://github.com/buliasz)**, **[nnnik](https://github.com/nnnik)**, **[AHK-just-me](https://github.com/AHK-just-me)**, **[sswwaagg](https://github.com/sswwaagg)**, **[Rseding91](https://github.com/Rseding91)**. Let me know if I missed someone. Thank you, guys.

- Special thanks to: **[G33kDude](https://github.com/G33kDude/Chrome.ahk)**, **Helgef**, **[mcl](https://github.com/mcl-on-github)**, **neogna2**, **[robodesign](https://github.com/marius-sucan/)**, **SKAN**.

- Finally, **[Lexikos](https://github.com/Lexikos)** for creating and maintaining AutoHotkey v2.
