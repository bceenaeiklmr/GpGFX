; Script:    TodoApp.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX

#Requires AutoHotkey v2
#include ../../GpGFX.ahk

; GpGFX Modern Interactive Todo & Task Manager App
; Demonstrates pure native vector OnEvent handlers and standalone Text shapes!

width := 520
height := 720
posX := (A_ScreenWidth - width) // 2
posY := (A_ScreenHeight - height) // 2

; Create Master UI Layer (Centered, smoothly draggable)
global lyr := Layer(posX, posY, width, height, "GpGFX Task Manager")
lyr.draggable := true

; Todo List State
global tasks := [
    { text: "Finish GpGFX Multi-Core Engine", done: true },
    { text: "Implement Fluent Method Chaining", done: true },
    { text: "Fix Layer Z-Order & NoActivate", done: true },
    { text: "Build Native Vector Control Hit-Tester", done: false },
    { text: "Create Occlusion Culling Algorithm", done: false },
    { text: "Release GpGFX v1.0 on GitHub", done: false }
]

global filterMode := "All" ; "All" | "Active" | "Completed"
global hoveredIndex := 0
global hoveredFilter := ""

RenderUI() {
    global lyr, tasks, filterMode, hoveredIndex, hoveredFilter, width, height
    local closeBtn, totalCount, doneCount, t, pct, fillW, tabs, tabX, tab, isActive, isHov, tBgClr, tTxtClr, tBtn, addBtn, itemY, idx, isItemHov, itemBgClr, itemBorderClr, iCard, cbClr, chkBox, txtClr, txtStyle, delBtn
    
    ; Clear existing layer shapes before rebuilding
    lyr.Clear()
    LayerStack.ActiveLayer := lyr

    ; 1. Window Frame & Card Backdrop
    RoundedRectangle(10, 10, width - 20, height - 20, 16, "0xFF1E1E24", true)
    RoundedRectangle(10, 10, width - 20, height - 20, 16, "0x33FCFCFA", false)

    ; Header with standalone Text shapes (Zero dummy rectangles!)
    Text(30, 25, width - 60, 35, "GpGFX TASK MANAGER", "0xFFFCFCFA", 13, "Segoe UI", "Bold").Left().Middle()
    Text(30, 58, width - 60, 20, "Native Vector Interactive UI Controls", "0xFF939293", 9, "Segoe UI", "Regular").Left().Middle()

    ; Close Button [x] at top right
    closeBtn := RoundedRectangle(width - 50, 25, 25, 25, 6, "0x20FCFCFA", true)
    Text(width - 50, 25, 25, 25, "x", "0xFFFCFCFA", 10, "Segoe UI", "Bold").Center().Middle()
    closeBtn.OnEvent("Click", (*) => ExitApp())

    ; 2. Progress Bar
    totalCount := tasks.Length
    doneCount := 0
    for t in tasks {
        if (t.done)
            doneCount++
    }
    pct := totalCount ? (doneCount / totalCount) : 0.0

    RoundedRectangle(30, 88, width - 60, 12, 6, "0xFF2D2A2E", true)
    if (pct > 0) {
        fillW := Max(12, Round((width - 60) * pct))
        RoundedRectangle(30, 88, fillW, 12, 6, "0xFFA9DC76", true)
    }

    Text(30, 105, width - 60, 20, doneCount . " of " . totalCount . " tasks completed (" . Round(pct * 100) . "%)", "0xFF939293", 8.5, "Segoe UI", "Regular").Right().Middle()

    ; 3. Filter Tabs [ All ] [ Active ] [ Completed ]
    tabs := ["All", "Active", "Completed"]
    tabX := 30
    for tab in tabs {
        isActive := (filterMode == tab)
        isHov := (hoveredFilter == tab)
        tBgClr := isActive ? "0xFFFF6188" : (isHov ? "0x33FCFCFA" : "0xFF2D2A2E")
        tTxtClr := isActive ? "White" : "0xFFFCFCFA"

        tBtn := RoundedRectangle(tabX, 130, 80, 26, 6, tBgClr, true)
        Text(tabX, 130, 80, 26, tab, tTxtClr, 9, "Segoe UI", isActive ? "Bold" : "").Center().Middle()

        ; Direct OnEvent bindings isolated per tab
        BindTabEvents(tBtn, tab)

        tabX += 90
    }

    ; 4. Add Task Quick-Button [+ New Task]
    addBtn := RoundedRectangle(width - 140, 130, 110, 26, 6, "0xFF78DCE8", true)
    Text(width - 140, 130, 110, 26, "+ New Task", "0xFF1E1E24", 9, "Segoe UI", "Bold").Center().Middle()
    addBtn.OnEvent("Click", (*) => OnAddTask())

    ; 5. Task List Items
    itemY := 175
    for idx, t in tasks {
        ; Filter check
        if (filterMode == "Active" && t.done)
            continue
        if (filterMode == "Completed" && !t.done)
            continue

        isItemHov := (hoveredIndex == idx)
        itemBgClr := isItemHov ? "0xFF363238" : "0xFF262327"
        itemBorderClr := isItemHov ? "0x8078DCE8" : "0x20FCFCFA"

        ; Task Card Container / Background
        iCard := RoundedRectangle(30, itemY, width - 60, 52, 10, itemBgClr, true)
        RoundedRectangle(30, itemY, width - 60, 52, 10, itemBorderClr, false)

        ; Checkbox [✓] or [ ]
        cbClr := t.done ? "0xFFA9DC76" : "0x40FCFCFA"
        chkBox := RoundedRectangle(45, itemY + 14, 24, 24, 6, cbClr, true)
        if (t.done) {
            Text(45, itemY + 14, 24, 24, "✓", "0xFF1E1E24", 11, "Segoe UI", "Bold").Center().Middle()
        }

        ; Task Text
        txtClr := t.done ? "0xFF727072" : "0xFFFCFCFA"
        txtStyle := t.done ? "Italic" : ""
        Text(82, itemY + 8, width - 165, 36, t.text, txtClr, 10, "Segoe UI", txtStyle).Left().Middle()

        ; Delete Button [x]
        delBtn := RoundedRectangle(width - 65, itemY + 14, 24, 24, 6, isItemHov ? "0x30FF6188" : "0x00000000", true)
        Text(width - 65, itemY + 14, 24, 24, "x", isItemHov ? "0xFFFF6188" : "0x40FCFCFA", 10, "Segoe UI").Center().Middle()

        ; Bind Native OnEvent Handlers isolated per task index
        BindTaskEvents(iCard, chkBox, delBtn, idx)

        itemY += 60
    }

    ; Footer Instructions
    Text(30, height - 45, width - 60, 25, "Click tasks to toggle | Smooth vector drag on background", "0xFF727072", 8.5, "Segoe UI").Center().Middle()

    Draw(lyr)
}

BindTabEvents(tBtn, tabName) {
    global filterMode, hoveredFilter
    tBtn.OnEvent("Click", (s, mx, my) => (filterMode := tabName, RenderUI()))
    tBtn.OnEvent("MouseEnter", (s, mx, my) => (hoveredFilter != tabName ? (hoveredFilter := tabName, RenderUI()) : 0))
    tBtn.OnEvent("MouseLeave", (s, mx, my) => (hoveredFilter == tabName ? (hoveredFilter := "", RenderUI()) : 0))
}

BindTaskEvents(iCard, chkBox, delBtn, taskIndex) {
    global tasks, hoveredIndex
    chkBox.OnEvent("Click", (s, mx, my) => (tasks[taskIndex].done := !tasks[taskIndex].done, RenderUI()))
    iCard.OnEvent("Click", (s, mx, my) => (tasks[taskIndex].done := !tasks[taskIndex].done, RenderUI()))
    delBtn.OnEvent("Click", (s, mx, my) => (tasks.RemoveAt(taskIndex), RenderUI()))
    iCard.OnEvent("MouseEnter", (s, mx, my) => (hoveredIndex != taskIndex ? (hoveredIndex := taskIndex, RenderUI()) : 0))
    iCard.OnEvent("MouseLeave", (s, mx, my) => (hoveredIndex == taskIndex ? (hoveredIndex := 0, RenderUI()) : 0))
}

OnAddTask() {
    global tasks
    local res := Dialog.Input("Enter new task description:", "Add New Task", "", "e.g. Build Occlusion Culler...", { accent: "0xFF78DCE8", okText: "+ Add Task" })
    if (res && Trim(res) != "") {
        tasks.Push({ text: Trim(res), done: false })
        RenderUI()
    }
}

; Initial Render
RenderUI()

; Escape to exit
HotKey("~*Esc", (*) => ExitApp())
