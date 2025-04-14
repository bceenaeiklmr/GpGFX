; Script     CS50AI-DFS-BFS-Visualizer.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/GpGFX
; Date       14.04.2025

#SingleInstance Force
#include ../../../GpGfx.ahk
#Warn LocalSameAsGlobal, Off

Maze1()
Maze2()
Maze5()
Maze6()
Maze7()

End()
^Esc:: End()

/**
 * Represents a single position (state) in the maze during the search.  
 * __New(state, parent, action): The constructor.  
 * state: An array [row, col] representing the coordinates.  
 * parent: The Node object from which this node was reached (used to reconstruct the path). It's "" for the starting node.  
 * action: The action ("up", "down", "left", "right") taken to reach this state from the paren
 */
class Node {
    __New(state, parent, action) {
        this.state := state
        this.parent := parent
        this.action := action
    }
}

/**
 * Implements a Last-In, First-Out (LIFO) frontier using an array, suitable for Depth-First Search (DFS).
 * @method add(node): Adds a Node to the end of the frontier array using Push.
 * @method contains_state(state_to_check): Checks if a given state (coordinate array) is already present in any node within the frontier. It iterates through the nodes and compares the row and column elements.
 * @method empty(): Returns true if the frontier array is empty, false otherwise.
 * @method remove(): Removes and returns the last node added to the frontier (LIFO) using Pop. Throws an error if the frontier is empty.
 * @constructor __New(): Initializes an empty array this.frontier to store Node objects.
 */
class StackFrontier {

    __New() {
        this.frontier := []
    }

    add(node) {
        this.frontier.Push(node)
    }

    contains_state(state_to_check) {
        local node
        for node in this.frontier {
            ; Compare array elements
            if (node.state[1] == state_to_check[1] && node.state[2] == state_to_check[2]) {
                return true
            }
        }
        return false
    }

    empty() {
        return (this.frontier.Length == 0)
    }

    remove() {
        local node
        if (this.empty()) {
            throw "Empty frontier"
        }
        node := this.frontier.Pop()
        return node
    }

}

class QueueFrontier extends StackFrontier {
    remove() {
        local node
        if (this.empty()) {
            throw "Empty frontier"
        }
        node := this.frontier[1]
        this.frontier.RemoveAt(1)
        return node
    }
}

class Maze {

    print(explored_map := "", current_state := "", frontier_obj := "") {

        local is_solution_path, is_explored, is_current, is_frontier, current_key, solution_cells, i, row, j, cell_is_wall, found

        global lyr, obj, start, infobar, hatchStyle, sleeptime

        ; Get the array of cell coordinates
        solution_cells := (this.solution.Length > 0) ? this.solution[2] : ""

        found := false

        for i, row in this.walls {
            for j, cell_is_wall in row {
                is_solution_path := false
                is_explored := false
                is_current := false
                is_frontier := false
                current_key := i "," j

                ; Check if it's the current node being explored
                if IsObject(current_state) && i == current_state[1] && j == current_state[2] {
                    is_current := true
                }
                ; Check if it's in the frontier
                else if IsObject(frontier_obj) && frontier_obj.contains_state([i, j]) {
                    is_frontier := true
                }
                ; Check if it's part of the final solution path
                else if IsObject(solution_cells) {
                    for sol_cell in solution_cells {
                        if (sol_cell[1] == i && sol_cell[2] == j) {
                            is_solution_path := true
                            break
                        }
                    }
                }
                ; Check if it's explored
                else if IsObject(explored_map) && explored_map.Has(current_key) {
                    is_explored := true
                }

                ; Calculate the cell index, CreateGraphicsObject is not a 2D array
                cell_index := (i - 1) * this.walls[1].Length + j

                ; Wall check
                if (cell_is_wall) {
                    continue
                }
                ; Start
                else if (i == this.start[1] && j == this.start[2]) {
                    obj[cell_index].color := "33ff00"
                    obj[cell_index].str := "A"
                }
                ; Goal
                else if (i == this.goal[1] && j == this.goal[2]) {
                    obj[cell_index].color := "red"
                    obj[cell_index].str := "B"
                }
                ; Current node
                else if (is_current) {
                    obj[cell_index].color := "fd09c8"
                    obj[cell_index].str := "?"
                }
                ; Frontier
                else if (is_frontier) {
                    obj[cell_index].color := "efff14"
                    obj[cell_index].str := "F"
                }
                ; Solution path
                else if (is_solution_path) {
                    obj[cell_index].color := "e9ff1f"
                    obj[cell_index].str := "*"
                    (!found) ? found := true : 0
                }
                ; Explored cells
                else if (is_explored) {
                    obj[cell_index].color := "59c959"
                    obj[cell_index].str := "+"
                }
                ; Empty, unexplored
                else {
                    obj[cell_index].color := ["Hatch", "000000", "0b23ff", hatchStyle]
                    obj[cell_index].str := ""
                }
            }
        }

        try {
            infobar[1].str := "Algorithm: " (Type(frontier_obj) == "QueueFrontier" ? "BFS" : "DFS")
            infobar[2].str := "Explored: " this.num_explored
            infobar[3].str := "X, Y : " Format("{:02}", current_state[1]) ", " Format("{:02}", current_state[2])
            infobar[4].str := "Elapsed: " Round((A_TickCount - start) / 1000, 2) " s"
        }

        ; Draw the main maze layer updates
        lyr.Draw()
        Draw(lyrInfo)
        ; Show solution
        if (found)
            Sleep(2500)
        Sleep(sleeptime)

    }

    ; Depth-First Search (DFS) solver.
    solveDFS() {
        this.num_explored := 0
        this.solution := []
        start_node := Node(this.start, "", "")
        frontier := StackFrontier()
        frontier.add(start_node)
        this.explored := Map()

        while true {
            if (frontier.empty()) {
                throw "No solution"
            }

            objNode := frontier.remove()
            this.num_explored++

            this.print(this.explored, objNode.state, frontier)

            ; Ensure objNode.state is valid
            if !IsObject(objNode.state) || objNode.state.Length != 2 {
                throw ValueError("Invalid objNode.state")
            }

            if (objNode.state[1] == this.goal[1] && objNode.state[2] == this.goal[2]) {
                actions := []
                cells := []
                temp_node := objNode
                while (IsObject(temp_node.parent)) {
                    actions.Push(temp_node.action)
                    cells.Push(temp_node.state)
                    temp_node := temp_node.parent
                }
                actions := arr_reverse(actions)
                cells := arr_reverse(cells)
                this.solution := [actions, cells]
                notification("Solution Found: Depth-First Search", , , 1500)
                this.print()
                return
            }

            explored_key := objNode.state[1] "," objNode.state[2]

            if this.explored.Has(explored_key) {
                continue
            }
            this.explored[explored_key] := true

            neighbors_result := this.neighbors(objNode.state)
            for neighbor_data in neighbors_result {
                action := neighbor_data[1]
                current_state := neighbor_data[2]
                current_explored_key := current_state[1] "," current_state[2]

                if (!frontier.contains_state(current_state) && !this.explored.Has(current_explored_key)) {
                    child := Node(current_state, objNode, action)
                    frontier.add(child)
                }
            }
        }
    }

    ; Breadth-First Search (BFS) solver.
    solveBFS() {

        ; Keep track of number of states explored
        this.num_explored := 0
        
        ; Initialize frontier to just the starting position
        start_node := Node(this.start, "", "")
        frontier := QueueFrontier()
        frontier.add(start_node)

        ; Initialize an empty explored set
        this.explored := Map()

        this.solution := []

        ; Keep looping until solution found
        while true {

            ; If nothing left in frontier, then no path
            if (frontier.empty()) {
                throw "No solution"
            }

            ; Choose a node from the frontier
            objNode := frontier.Remove()
            this.num_explored++

            ; Print the current state of the maze
            this.print(this.explored, objNode.state, frontier)

            ; Ensure objNode.state is valid
            if (!IsObject(objNode.state) || objNode.state.Length != 2) {
                throw ValueError("Invalid objNode.state")
            }

            ; If node is the goal, then we have a solution
            if (objNode.state[1] == this.goal[1] && objNode.state[2] == this.goal[2]) {
                actions := []
                cells := []
                temp_node := objNode
                while (IsObject(temp_node.parent)) {
                    actions.Push(temp_node.action)
                    cells.Push(temp_node.state)
                    temp_node := temp_node.parent
                }
                actions := arr_reverse(actions)
                cells := arr_reverse(cells)
                this.solution := [actions, cells]
                Notification("Solution Found: Breadth-First Search", , , 1500)
                this.print()
                return
            }

            ; Mark node as explored
            explored_key := objNode.state[1] "," objNode.state[2]
            ;if this.explored.Has(explored_key)
            ;    continue

            this.explored[explored_key] := true

            ; Add neighbors to frontier
            neighbors_result := this.neighbors(objNode.state)
            for neighbor_data in neighbors_result {
                action := neighbor_data[1]
                current_state := neighbor_data[2]
                current_explored_key := current_state[1] "," current_state[2]

                ; Check if the current state is already in the frontier or explored set
                if (!frontier.contains_state(current_state) && !this.explored.Has(current_explored_key)) {
                    child := Node(current_state, objNode, action)
                    frontier.add(child)
                }
            }
        }
    }

    /**
     * Returns a list of valid neighboring states (coordinates) for a given state in the maze.
     * @param state Current state (coordinates) in the maze
     * @return {array} Array of valid neighboring states, their actions
     */
    neighbors(state) {

        local row, col, candidates, result, action
        
        ; Ensure state is an array with two elements
        if (!IsObject(state) || state.Length != 2)
            throw ValueError("Invalid state")

        ; Calculate possible moves
        row := state[1]
        col := state[2]
        candidates := [
            ["up", [row - 1, col]],
            ["down", [row + 1, col]],
            ["left", [row, col - 1]],
            ["right", [row, col + 1]]
        ]

        ; Start to get the neighbors
        result := []
        result.Capacity := candidates.Length
        for candidate in candidates {
            action := candidate[1]
            row := candidate[2][1]
            col := candidate[2][2]

            ; Check: boundary, row, column, wall
            if (row < 1 || row > this.height || col < 1 || col > this.width)
            || (!this.walls.Has(row))
            || (!this.walls[row].Has(col))
            || ((this.walls[row][col]))
                continue

            ; Add valid candidate to the result
            result.Push([action, [row, col]])
        }
        return result
    }

    /**
     * Maze constructor. Reads a maze from a file and initializes a maze object.
     * @param fileName The name of the file containing the maze.
     */
    __New(fileName) {

        local i, line, contents, char, row, j

        ; Read maze from file
        contents := FileRead(fileName)

        ; Validate start and goal
        if (StrSplit(contents, "A").Length-1 !== 1)
            throw ValueError("Maze must have exactly one starting point")
        if (StrSplit(contents, "B").Length-1 !== 1)
            throw ValueError("Maze must have exactly one goal")

        ; Calculate height, width of maze
        contents := StrSplit(contents, "`n")
        this.width := StrLen(contents[1])
        this.height := contents.Length
        

        ; Keep track of walls
        this.walls := []
        this.walls.Capacity := this.height
        for i, line in contents {
            row := []
            row.Capacity := this.width
            for j, char in StrSplit(line) {
                if (char == "A") {
                    this.start := [i, j]
                    row.Push(false)
                }
                else if (char == "B") {
                    this.goal := [i, j]
                    row.Push(false)
                }
                else if (char == " ") {
                    row.Push(false)
                }
                else {
                    row.Push(true)
                }
            }
            this.walls.Push(row)
        }
        this.solution := []
    }
}

Maze1() {

    global sleeptime, infobar, obj, start, lyrinfo, hatchStyle, lyr

    lyr := Layer()
    lyr.Redraw := 1

    ; Initialize a Maze instance
    m := Maze("maze1.txt")
    size := 160

    sleeptime := 500

    start := A_TickCount

    obj := CreateGraphicsObject(m.walls.Length, m.walls[1].Length, , , size, size, 0)
    loop obj.Length {
        obj[A_Index].Text(, "black", 14)
    }

    hatchStyle := Random(0, 52)

    lyrInfo := Layer()
    infobar := CreateGraphicsObject(1, 4, obj[1].x, obj[obj.Length].y + size + 20, size * m.walls[1].Length // 4, 100, 0, "000000")
    loop infobar.Length {
        infobar[A_Index].Text(, "white", 24, "Roboto", , 0)
    }

    Draw(lyr)
    Draw(lyrInfo)

    m.solveBFS()
    Clean()
}
Maze2() {

    global sleeptime, infobar, obj, start, lyrinfo, hatchStyle, lyr

    lyr := Layer()
    lyr.Redraw := 1

    m := Maze("maze2.txt")
    size := 66

    sleeptime := 150

    obj := CreateGraphicsObject(m.walls.Length, m.walls[1].Length, , , size, size, 0)
    loop obj.Length {
        obj[A_Index].Text(, "black", 14)
    }

    hatchStyle := Random(0, 52)

    lyrInfo := Layer()
    infobar := CreateGraphicsObject(1, 4, obj[1].x, obj[obj.Length].y + size + 20, size * m.walls[1].Length // 4, 100, 0, "000000")
    loop infobar.Length {
        infobar[A_Index].Text(, "white", 24, "Roboto", , 0)
    }

    notification("With ~100 ms delay...")

    Draw(lyr)
    Draw(lyrInfo)

    
    m.solveDFS()
    start := A_TickCount
    m.solveBFS()

    Clean()
    lyr := ""
}
Maze5() {

    global sleeptime, infobar, obj, start, lyrinfo, hatchStyle, lyr

    lyr := Layer()
    lyr.Redraw := 1

    m := Maze("maze5.txt")
    size := 37

    sleeptime := -1

    obj := CreateGraphicsObject(m.walls.Length, m.walls[1].Length, , , size, size, 0)
    loop obj.Length {
        obj[A_Index].Text(, "black", 14)
    }

    hatchStyle := Random(0, 52)

    lyrInfo := Layer()
    infobar := CreateGraphicsObject(1, 4, obj[1].x, obj[obj.Length].y + size + 20, size * m.walls[1].Length // 4, 100, 0, "000000")
    loop infobar.Length {
        infobar[A_Index].Text(, "white", 24, "Roboto", , 0)
    }

    notification("A bit more challenging maze...")

    Draw(lyr)
    Draw(lyrInfo)


    sleeptime := -1

    start := A_TickCount
    m.solveDFS()
    t1 := A_TickCount - start - 1500

    start := A_TickCount
    m.solveBFS()
    t2 := A_TickCount - start - 1500

    if (t1 < t2) {
        notification("Depth-first search won by " Round(t1 / t2 * 100, 2) " %", , , 1500)
    }
    else {
        notification("Breadth-first search won by " Round(t2 / t1 * 100, 2) " %", , , 1500)
    }
    Clean()
    lyr := ""
}
Maze7() {

    global sleeptime, infobar, obj, start, lyrinfo, hatchStyle, lyr

    lyr := Layer()
    lyr.Redraw := 1

    m := Maze("maze6.txt")
    size := 25

    sleeptime := -1

    obj := CreateGraphicsObject(m.walls.Length, m.walls[1].Length, , , size, size, 0)
    loop obj.Length {
        obj[A_Index].Text(, "black", 14)
    }

    hatchStyle := Random(0, 52)

    lyrInfo := Layer()
    infobar := CreateGraphicsObject(1, 4, obj[1].x, obj[obj.Length].y + size + 20, size * m.walls[1].Length // 4, 100, 0, "000000")
    loop infobar.Length {
        infobar[A_Index].Text(, "white", 24, "Roboto", , 0)
    }

    notification("Even more challenging...")

    Draw(lyr)
    Draw(lyrInfo)


    sleeptime := -1

    start := A_TickCount
    m.solveDFS()
    t1 := A_TickCount - start - 1500

    start := A_TickCount
    m.solveBFS()
    t2 := A_TickCount - start - 1500

    if (t1 < t2) {
        notification("Depth-first search won by " Round(t1 / t2 * 100, 2) " %", , , 1500)
    }
    else {
        notification("Breadth-first search won by " Round(t2 / t1 * 100, 2) " %", , , 1500)
    }
    Clean()
    lyr := ""
}
Maze6() {

    global sleeptime, infobar, obj, start, lyrinfo, hatchStyle, lyr

    lyr := Layer()
    lyr.Redraw := 1

    m := Maze("maze7.txt")
    size := 29

    sleeptime := -1

    obj := CreateGraphicsObject(m.walls.Length, m.walls[1].Length, , , size, size, 0)
    loop obj.Length {
        obj[A_Index].Text(, "black", 14)
    }

    hatchStyle := Random(0, 52)

    lyrInfo := Layer()
    infobar := CreateGraphicsObject(1, 4, obj[1].x, obj[obj.Length].y + size + 20, size * m.walls[1].Length // 4, 100, 0, "000000")
    loop infobar.Length {
        infobar[A_Index].Text(, "white", 24, "Roboto", , 0)
    }

    Draw(lyr)
    Draw(lyrInfo)

    sleeptime := -1

    start := A_TickCount
    m.solveDFS()
    t1 := A_TickCount - start - 1500

    start := A_TickCount
    m.solveBFS()
    t2 := A_TickCount - start - 1500

    if (t1 < t2) {
        notification("Depth-first search won by " Round(t1 / t2 * 100, 2) " %", , , 1500)
    }
    else {
        notification("Breadth-first search won by " Round(t2 / t1 * 100, 2) " %", , , 1500)
    }
    Clean()
    lyr := ""
}
Maze8() {

    global sleeptime, infobar, obj, start, lyrinfo, hatchStyle, lyr

    lyr := Layer()
    lyr.Redraw := 1

    m := Maze("maze8.txt")
    size := 17

    sleeptime := -1

    obj := CreateGraphicsObject(m.walls.Length, m.walls[1].Length, , , size, size, 0)
    loop obj.Length {
        obj[A_Index].Text(, "black", 14)
    }

    hatchStyle := Random(0, 52)

    lyrInfo := Layer()
    infobar := CreateGraphicsObject(1, 4, obj[1].x, obj[obj.Length].y + size + 20, size * m.walls[1].Length // 4, 100, 0, "000000")
    loop infobar.Length {
        infobar[A_Index].Text(, "white", 24, "Roboto", , 0)
    }

    Draw(lyr)
    Draw(lyrInfo)

    sleeptime := -1

    start := A_TickCount
    m.solveDFS()
    t1 := A_TickCount - start - 1500

    start := A_TickCount
    m.solveBFS()
    t2 := A_TickCount - start - 1500

    if (t1 < t2) {
        notification("Depth-first search won by " Round(t1 / t2 * 100, 2) " %", , , 1500)
    }
    else {
        notification("Breadth-first search won by " Round(t2 / t1 * 100, 2) " %", , , 1500)
    }
    Clean()
    lyr := ""
}

; Function to reverse an array.
arr_reverse(arr) {
    local arrRev := []
    arrRev.Length := arr.Length
    loop arr.Length {
        arrRev[A_Index] := arr[arr.Length - A_Index + 1]
    }
    return arrRev
}

/**
 * A simple example of a gradient notification tooltip.  
 * Script     AnimatedTooltip.ahk  
 * License:   MIT License  
 * Author:    Bence Markiel (bceenaeiklmr)  
 * Github:    https://github.com/bceenaeiklmr/GpGFX  
 * Date       17.03.2025
 */
notification(str := "", color1 := "orange", color2 := "red", timeout := 1000) {

    ; Create layer
    width := 1440
    height := 400
    lyr := Layer(width, height)

    ; Create rectangle with gradient color
    rect := Rectangle(0, 0, width, height, 'Black')
    rect.color := [color1, color2]
    rect.w := 0
    rect.Text(, 'black', 72)

    ; Basically how fast the rectangle grows
    unit := 4

    ; Grow
    loop (lyr.w // unit) {
        lyr.Draw()
        rect.w += unit
    }
    ; Text
    loop StrLen(str) {
        rect.str := SubStr(str, 1, A_Index)
        Sleep(15.6)
        lyr.Draw()
    }
    ; Wait
    Sleep(timeout)
    rect.str := ""
    lyr.Draw()
    ; Shrink
    loop (lyr.w // unit) {
        rect.w -= unit
        lyr.Draw()
    }
}
