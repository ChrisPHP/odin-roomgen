package main

import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"

Room :: struct {
    x, y: int,
    width, height: int,
    entrance: bool,
    exterior: bool,
    direction: ExteriorSide,
    door: [2]int 
}

ExteriorSide :: enum {
    None,
    North,
    East,
    South,
    West,
}

BSPNode :: struct {
    room: Room,
    left: ^BSPNode,
    right: ^BSPNode,
    is_leaf: bool
}

SplitDirection :: enum {
    Horizontal,
    Vertical
}

MIN_ROOM_SIZE :: 5  // Minimum width/height for a room
MAX_ROOM_SIZE :: 10
SPLIT_RATIO_MIN :: 0.4  // Minimum ratio for splitting (30%)
SPLIT_RATIO_MAX :: 0.6  // Maximum ratio for splitting (70%)
GRID_WIDTH := 50
EXTERIOR_DOOR := false

new_bsp_node :: proc(x, y, width, height: int) -> ^BSPNode {
    node := new(BSPNode)
    node.room = Room{x, y, width, height, false, false, .None, {}}
    node.left = nil
    node.right = nil
    node.is_leaf = true
    return node
}

free_bsp_tree :: proc(node: ^BSPNode) {
    if node == nil {
        return
    }
    
    if node.left != nil {
        free_bsp_tree(node.left)
    }
    if node.right != nil {
        free_bsp_tree(node.right)
    }
    
    free(node)
}

choose_split_direction :: proc(width, height: f32) -> SplitDirection {
    if (width / height) > 1.25 {
        return .Vertical
    }

    if (height / width) > 1.25 {
        return .Horizontal
    }

    choices := [2]SplitDirection{.Vertical, .Horizontal}
    return rand.choice(choices[:])
}

should_split :: proc(width, height: int) -> bool {
    if width <= MIN_ROOM_SIZE || height <= MIN_ROOM_SIZE {
        return false
    }

    if width <= MAX_ROOM_SIZE && height <= MAX_ROOM_SIZE {
        return false
    }

    return true
}

split_node :: proc(node: ^BSPNode, iterations: int) -> bool {
    if iterations <= 0 || !should_split(node.room.width, node.room.width) {
        return false
    }

    direction := choose_split_direction(f32(node.room.width), f32(node.room.height))

    f32_width := f32(node.room.width)
    f32_height := f32(node.room.height)

    split_position: int
    if direction == .Horizontal {
        min_split := i32(f32_height * SPLIT_RATIO_MIN)
        max_split := i32(f32_height * SPLIT_RATIO_MAX)
        split_position = int(min_split + rand.int31() % (max_split - min_split + 1))

        node.left = new_bsp_node(
            node.room.x,
            node.room.y,
            node.room.width,
            split_position,
        )

        node.right = new_bsp_node(
            node.room.x,
            node.room.y + split_position,
            node.room.width,
            node.room.height - split_position,
        )
    } else {
        min_split := i32(f32_width * SPLIT_RATIO_MIN)
        max_split := i32(f32_width * SPLIT_RATIO_MAX)
        split_position = int(min_split + rand.int31() % (max_split - min_split + 1))

        node.left = new_bsp_node(
            node.room.x,
            node.room.y,
            split_position,
            node.room.height,
        )

        node.right = new_bsp_node(
            node.room.x + split_position,
            node.room.y,
            node.room.width - split_position,
            node.room.height,
        )
    }

    node.is_leaf = false

    split_node(node.left, iterations - 1)
    split_node(node.right, iterations - 1)

    return true
}

generate_bsp :: proc(width, height, iterations: int) -> ^BSPNode {
    GRID_WIDTH = width
    root := new_bsp_node(0,0, width, height)
    split_node(root, iterations)
    return root
}

generate_room_array :: proc(node: ^BSPNode, grid: ^[]int) {
    if node == nil do return

    if !node.is_leaf {
        generate_room_array(node.left, grid)
        generate_room_array(node.right, grid)
        return
    }

    process_leaf(node, grid)
}


process_leaf :: proc(node: ^BSPNode, grid: ^[]int) {
    room := node.room

    for x in room.x..<room.x + room.width {
        for y in room.y..<room.y + room.height {
            tile_index := y * GRID_WIDTH + x
            if x == 0 || y == 0 || y == room.y+room.height-1 || x == room.x+room.width-1{
                grid[tile_index] = 0
            } else {
                grid[tile_index] = 1
            }
        }
    }
}