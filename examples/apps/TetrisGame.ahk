; Script:    TetrisGame.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#Include ../../GpGFX.ahk

; GpGFX Classic Tetris Game Demo
; Full mechanics: 7 Tetrominoes, Ghost piece, Wall kicks, Line clears, 
; Dynamic gravity scoring, Next piece preview, and Keyboard controls.
;
; Controls:
;   [Left / Right / A / D] : Move Left / Right
;   [Up / W]               : Rotate 90° Clockwise
;   [Down / S]             : Soft Drop
;   [Space]                : Hard Drop
;   [P]                    : Pause / Resume
;   [R]                    : Restart Game
;   [Esc]                  : Exit

; Grid Configuration
global COLS := 10
global ROWS := 20
global CELL := 26
 
global boardX := 30
global boardY := 35
global boardW := COLS * CELL  ; 260px
global boardH := ROWS * CELL  ; 520px

global winW := boardW + 220    ; 510px
global winH := boardH + 70     ; 590px

; 1. Create Main Window Layer
global lyr := Layer((A_ScreenWidth - winW) // 2, (A_ScreenHeight - winH) // 2, winW, winH, "GpGFX Tetris")
lyr.draggable := true
lyr.redraw := true

; 2. Define the 7 Classic Tetrominoes (4 rotation states each)
global PIECES := [
    ; 1. I - Cyan
    { clr: 0xFF00F0FF, shapes: [
        [[0,1], [1,1], [2,1], [3,1]],
        [[2,0], [2,1], [2,2], [2,3]],
        [[0,2], [1,2], [2,2], [3,2]],
        [[1,0], [1,1], [1,2], [1,3]]
    ]},
    ; 2. J - Blue
    { clr: 0xFF36ABFB, shapes: [
        [[0,0], [0,1], [1,1], [2,1]],
        [[1,0], [2,0], [1,1], [1,2]],
        [[0,1], [1,1], [2,1], [2,2]],
        [[1,0], [1,1], [0,2], [1,2]]
    ]},
    ; 3. L - Orange
    { clr: 0xFFF66B19, shapes: [
        [[2,0], [0,1], [1,1], [2,1]],
        [[1,0], [1,1], [1,2], [2,2]],
        [[0,1], [1,1], [2,1], [0,2]],
        [[0,0], [1,0], [1,1], [1,2]]
    ]},
    ; 4. O - Yellow
    { clr: 0xFFFFD866, shapes: [
        [[1,0], [2,0], [1,1], [2,1]],
        [[1,0], [2,0], [1,1], [2,1]],
        [[1,0], [2,0], [1,1], [2,1]],
        [[1,0], [2,0], [1,1], [2,1]]
    ]},
    ; 5. S - Green
    { clr: 0xFFA9DC76, shapes: [
        [[1,0], [2,0], [0,1], [1,1]],
        [[1,0], [1,1], [2,1], [2,2]],
        [[1,1], [2,1], [0,2], [1,2]],
        [[0,0], [0,1], [1,1], [1,2]]
    ]},
    ; 6. T - Purple
    { clr: 0xFFBD93F9, shapes: [
        [[1,0], [0,1], [1,1], [2,1]],
        [[1,0], [1,1], [2,1], [1,2]],
        [[0,1], [1,1], [2,1], [1,2]],
        [[1,0], [0,1], [1,1], [1,2]]
    ]},
    ; 7. Z - Red
    { clr: 0xFFFF6188, shapes: [
        [[0,0], [1,0], [1,1], [2,1]],
        [[2,0], [1,1], [2,1], [1,2]],
        [[0,1], [1,1], [1,2], [2,2]],
        [[1,0], [0,1], [1,1], [0,2]]
    ]}
]

; 3. Game State Variables
global grid := []
global score := 0
global linesCleared := 0
global level := 1
global isGameOver := false
global isPaused := false

global curPieceIdx := 1
global curRot := 1
global curX := 3
global curY := 0
global nextPieceIdx := 1
global dropInterval := 500

; Initialize 10x20 Grid (0 = empty, uint = ARGB color)
ResetGrid() {
    global grid, ROWS, COLS
    grid := []
    loop ROWS {
        row := []
        loop COLS
            row.Push(0)
        grid.Push(row)
    }
}

; Check collision with walls and locked pieces
IsValidPos(pieceIdx, rot, testX, testY) {
    global grid, PIECES, ROWS, COLS
    coords := PIECES[pieceIdx].shapes[rot]
    for pt in coords {
        gx := testX + pt[1]
        gy := testY + pt[2]
        if (gx < 0 || gx >= COLS || gy >= ROWS)
            return false
        if (gy >= 0 && grid[gy + 1][gx + 1] != 0)
            return false
    }
    return true
}

; Spawn Next Piece
SpawnPiece() {
    global curPieceIdx, curRot, curX, curY, nextPieceIdx, isGameOver, PIECES
    curPieceIdx := nextPieceIdx
    nextPieceIdx := Random(1, PIECES.Length)
    curRot := 1
    curX := 3
    curY := 0

    if (!IsValidPos(curPieceIdx, curRot, curX, curY)) {
        isGameOver := true
        SetTimer(GameTick, 0)
    }
}

; Lock piece into the board and check line clears
LockPiece() {
    global grid, PIECES, curPieceIdx, curRot, curX, curY, score, linesCleared, level, dropInterval
    coords := PIECES[curPieceIdx].shapes[curRot]
    clr := PIECES[curPieceIdx].clr

    for pt in coords {
        gx := curX + pt[1]
        gy := curY + pt[2]
        if (gy >= 0 && gy < ROWS && gx >= 0 && gx < COLS)
            grid[gy + 1][gx + 1] := clr
    }

    ; Check full lines
    clearedCount := 0
    y := ROWS
    while (y >= 1) {
        isFull := true
        loop COLS {
            if (grid[y][A_Index] == 0) {
                isFull := false
                break
            }
        }

        if (isFull) {
            clearedCount++
            grid.RemoveAt(y)
            emptyRow := []
            loop COLS
                emptyRow.Push(0)
            grid.InsertAt(1, emptyRow)
        } else {
            y--
        }
    }

    if (clearedCount > 0) {
        linesCleared += clearedCount
        ; Classic Nintendo scoring: 100, 300, 500, 800 * level
        pts := [100, 300, 500, 800]
        score += pts[clearedCount] * level
        level := 1 + linesCleared // 10
        dropInterval := Max(80, 500 - (level - 1) * 40)
        SetTimer(GameTick, dropInterval)
    }

    SpawnPiece()
}

; Calculate Ghost Piece Y Position (Projection)
GetGhostY() {
    global curPieceIdx, curRot, curX, curY
    ghostY := curY
    while (IsValidPos(curPieceIdx, curRot, curX, ghostY + 1))
        ghostY++
    return ghostY
}

; Render the entire Game Frame
RenderGame() {
    global lyr, grid, ROWS, COLS, CELL, boardX, boardY, boardW, boardH, winW, winH
    global PIECES, curPieceIdx, curRot, curX, curY, nextPieceIdx, score, linesCleared, level, isGameOver, isPaused

    lyr.Clear()

    ; 1. Outer Dark Container Window
    RoundedRectangle(10, 10, winW - 20, winH - 20, 16, "0xFF16161E", true)
    RoundedRectangle(10, 10, winW - 20, winH - 20, 16, "0x33FCFCFA", false)

    ; 2. Game Board Backdrop
    RoundedRectangle(boardX - 4, boardY - 4, boardW + 8, boardH + 8, 8, "0xFF0F0F14", true)
    RoundedRectangle(boardX - 4, boardY - 4, boardW + 8, boardH + 8, 8, "0x4078DCE8", false)

    ; Subtle Grid Lines
    loop COLS - 1 {
        gx := boardX + A_Index * CELL
        Rectangle(gx, boardY, 1, boardH, "0x15FFFFFF", true)
    }
    loop ROWS - 1 {
        gy := boardY + A_Index * CELL
        Rectangle(boardX, gy, boardW, 1, "0x15FFFFFF", true)
    }

    ; 3. Render Locked Blocks in Board
    loop ROWS {
        r := A_Index
        loop COLS {
            c := A_Index
            blockClr := grid[r][c]
            if (blockClr != 0) {
                px := boardX + (c - 1) * CELL
                py := boardY + (r - 1) * CELL
                RoundedRectangle(px + 1, py + 1, CELL - 2, CELL - 2, 4, blockClr, true)
                RoundedRectangle(px + 1, py + 1, CELL - 2, CELL - 2, 4, "0x40FFFFFF", false)
            }
        }
    }

    ; 4. Render Active Piece & Ghost Projection (If not game over)
    if (!isGameOver && curPieceIdx) {
        ; A. Ghost Projection
        ghostY := GetGhostY()
        coords := PIECES[curPieceIdx].shapes[curRot]
        if (ghostY != curY) {
            for pt in coords {
                px := boardX + (curX + pt[1]) * CELL
                py := boardY + (ghostY + pt[2]) * CELL
                if (py >= boardY) {
                    RoundedRectangle(px + 2, py + 2, CELL - 4, CELL - 4, 4, "0x30FFFFFF", false)
                }
            }
        }

        ; B. Active Tetromino Piece
        clr := PIECES[curPieceIdx].clr
        for pt in coords {
            px := boardX + (curX + pt[1]) * CELL
            py := boardY + (curY + pt[2]) * CELL
            if (py >= boardY) {
                RoundedRectangle(px + 1, py + 1, CELL - 2, CELL - 2, 4, clr, true)
                RoundedRectangle(px + 1, py + 1, CELL - 2, CELL - 2, 4, "0x80FFFFFF", false)
            }
        }
    }

    ; 5. Right Side HUD Panel
    hudX := boardX + boardW + 20
    hudW := winW - hudX - 25

    ; Title
    Text(hudX, 25, hudW, 26, "GpGFX TETRIS", "0xFFFCFCFA", 13, "Segoe UI", "Bold").Center().Middle()

    ; Score Card
    RoundedRectangle(hudX, 65, hudW, 60, 8, "0xFF1E1E28", true)
    Text(hudX, 72, hudW, 18, "SCORE", "0xFF939293", 8.5, "Segoe UI", "Bold").Center().Middle()
    Text(hudX, 90, hudW, 28, String(score), "0xFFFFD866", 14, "Consolas", "Bold").Center().Middle()

    ; Level & Lines Card
    RoundedRectangle(hudX, 135, hudW, 60, 8, "0xFF1E1E28", true)
    Text(hudX, 142, hudW, 18, "LINES / LEVEL", "0xFF939293", 8.5, "Segoe UI", "Bold").Center().Middle()
    Text(hudX, 160, hudW, 28, linesCleared . "  (L" . level . ")", "0xFF78DCE8", 12, "Consolas", "Bold").Center().Middle()

    ; Next Piece Card
    RoundedRectangle(hudX, 205, hudW, 110, 8, "0xFF1E1E28", true)
    Text(hudX, 212, hudW, 18, "NEXT PIECE", "0xFF939293", 8.5, "Segoe UI", "Bold").Center().Middle()
    if (nextPieceIdx) {
        nextCoords := PIECES[nextPieceIdx].shapes[1]
        nextClr := PIECES[nextPieceIdx].clr
        prevCell := 18
        previewOffsetX := hudX + (hudW - 4 * prevCell) // 2
        previewOffsetY := 245
        for pt in nextCoords {
            npx := previewOffsetX + pt[1] * prevCell
            npy := previewOffsetY + pt[2] * prevCell
            RoundedRectangle(npx + 1, npy + 1, prevCell - 2, prevCell - 2, 3, nextClr, true)
        }
    }

    ; Controls Card
    RoundedRectangle(hudX, 325, hudW, 180, 8, "0xFF1E1E28", true)
    Text(hudX, 332, hudW, 18, "CONTROLS", "0xFF939293", 8.5, "Segoe UI", "Bold").Center().Middle()
    ctrlText := "← / → / A / D : Move`n↑ / W : Rotate`n↓ / S : Soft Drop`nSPACE : Hard Drop`nP : Pause / Resume`nR : Restart Game"
    Text(hudX + 10, 354, hudW - 20, 145, ctrlText, "0xFFC0C0C8", 8, "Segoe UI").Left().Top()

    ; Status / Game Over Overlay
    if (isGameOver) {
        overW := boardW - 30, overH := 90
        overX := boardX + 15, overY := boardY + (boardH - overH) // 2
        RoundedRectangle(overX, overY, overW, overH, 10, "0xEE1E1E28", true)
        RoundedRectangle(overX, overY, overW, overH, 10, "0xFFFF6188", false)
        Text(overX, overY + 12, overW, 30, "GAME OVER", "0xFFFF6188", 14, "Segoe UI", "Bold").Center().Middle()
        Text(overX, overY + 45, overW, 25, "Press [R] to Restart", "0xFFFCFCFA", 10, "Segoe UI").Center().Middle()
    } else if (isPaused) {
        pauseW := boardW - 40, pauseH := 60
        pauseX := boardX + 20, pauseY := boardY + (boardH - pauseH) // 2
        RoundedRectangle(pauseX, pauseY, pauseW, pauseH, 8, "0xEE1E1E28", true)
        Text(pauseX, pauseY, pauseW, pauseH, "PAUSED`nPress [P] to Resume", "0xFF78DCE8", 11, "Segoe UI", "Bold").Center().Middle()
    }

    Draw(lyr)
}

; Gravity Game Loop Tick
GameTick() {
    global curPieceIdx, curRot, curX, curY, isGameOver, isPaused
    if (isGameOver || isPaused)
        return

    if (IsValidPos(curPieceIdx, curRot, curX, curY + 1)) {
        curY++
    } else {
        LockPiece()
    }
    RenderGame()
}

; Keyboard Controls

MoveLeft() {
    global curPieceIdx, curRot, curX, curY, isGameOver, isPaused
    if (isGameOver || isPaused)
        return
    if (IsValidPos(curPieceIdx, curRot, curX - 1, curY)) {
        curX--
        RenderGame()
    }
}

MoveRight() {
    global curPieceIdx, curRot, curX, curY, isGameOver, isPaused
    if (isGameOver || isPaused)
        return
    if (IsValidPos(curPieceIdx, curRot, curX + 1, curY)) {
        curX++
        RenderGame()
    }
}

RotatePiece() {
    global curPieceIdx, curRot, curX, curY, isGameOver, isPaused
    if (isGameOver || isPaused)
        return
    nextRot := (curRot >= 4) ? 1 : (curRot + 1)
    
    ; Basic rotation & standard wall-kick offsets
    if (IsValidPos(curPieceIdx, nextRot, curX, curY)) {
        curRot := nextRot
        RenderGame()
    } else if (IsValidPos(curPieceIdx, nextRot, curX - 1, curY)) {
        curX -= 1
        curRot := nextRot
        RenderGame()
    } else if (IsValidPos(curPieceIdx, nextRot, curX + 1, curY)) {
        curX += 1
        curRot := nextRot
        RenderGame()
    }
}

SoftDrop() {
    global curPieceIdx, curRot, curX, curY, isGameOver, isPaused, score
    if (isGameOver || isPaused)
        return
    if (IsValidPos(curPieceIdx, curRot, curX, curY + 1)) {
        curY++
        score += 1
        RenderGame()
    }
}

HardDrop() {
    global curPieceIdx, curRot, curX, curY, isGameOver, isPaused, score
    if (isGameOver || isPaused)
        return
    dropDist := 0
    while (IsValidPos(curPieceIdx, curRot, curX, curY + 1)) {
        curY++
        dropDist++
    }
    score += dropDist * 2
    LockPiece()
    RenderGame()
}

TogglePause() {
    global isPaused, isGameOver
    if (isGameOver)
        return
    isPaused := !isPaused
    RenderGame()
}

RestartGame() {
    global score, linesCleared, level, isGameOver, isPaused, dropInterval, PIECES, nextPieceIdx
    ResetGrid()
    score := 0
    linesCleared := 0
    level := 1
    isGameOver := false
    isPaused := false
    dropInterval := 500
    nextPieceIdx := Random(1, PIECES.Length)
    SpawnPiece()
    SetTimer(GameTick, dropInterval)
    RenderGame()
}

; Start Initial Game
RestartGame()

; Activate window for keyboard focus on launch and on mouse click
WinActivate("ahk_id " lyr.hwnd)
OnMessage(0x0201, (*) => WinActivate("ahk_id " lyr.hwnd))

; Register Context-Sensitive Hotkeys (Only active when Tetris window is focused!)
; Without '~', keys are consumed by Tetris and never type into background editors.
HotIfWinActive("ahk_id " lyr.hwnd)
HotKey("Left",   (*) => MoveLeft())
HotKey("a",      (*) => MoveLeft())
HotKey("Right",  (*) => MoveRight())
HotKey("d",      (*) => MoveRight())
HotKey("Up",     (*) => RotatePiece())
HotKey("w",      (*) => RotatePiece())
HotKey("Down",   (*) => SoftDrop())
HotKey("s",      (*) => SoftDrop())
HotKey("Space",  (*) => HardDrop())
HotKey("p",      (*) => TogglePause())
HotKey("r",      (*) => RestartGame())
HotKey("Esc",    (*) => ExitApp())
HotIfWinActive()
