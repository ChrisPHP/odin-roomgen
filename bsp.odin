package main

import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"

Room :: struct {
    x, y: int,
    width, height: int,
    size: int,
    entrance: bool,
    exterior: bool,
    type: RoomTypes,
    direction: ExteriorSide,
    doors: [2]int 
}

RoomTypes :: enum {
    None,
    Living,
    Kitchen,
    Dining,
    Bedroom,
    Bathroom,
    Toilet,
    Hallway,
    Wardrobe
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

MIN_ROOM_SIZE :: 10  // Minimum width/height for a room
SPLIT_RATIO_MIN :: 0.4  // Minimum ratio for splitting (30%)
SPLIT_RATIO_MAX :: 0.6  // Maximum ratio for splitting (70%)
GRID_WIDTH := 50
EXTERIOR_DOOR := false

rand_int_range :: proc(start, end: int) -> int {
    return int(rand.float32_range(f32(start), f32(end)))
}

new_bsp_node :: proc(x, y, width, height: int) -> ^BSPNode {
    node := new(BSPNode)
    node.room = Room{x, y, width, height, width*height, false, false, .None, .None, {}}
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

    return true
}

split_node :: proc(node: ^BSPNode, iterations: int) -> bool {
    if iterations <= 1 || !should_split(node.room.width, node.room.width) {
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

    val := rand.float32()
    if val > 0.5 {
        split_node(node.left, iterations - 1)
    } else {
        split_node(node.right, iterations - 1)
    }

    return true
}

generate_bsp :: proc(width, height, grid_width, iterations: int, start: [2]int) -> ^BSPNode {
    GRID_WIDTH = grid_width
    
    root := new_bsp_node(start[0],start[1], width, height)
    split_node(root, iterations)
    return root
}

generate_room_array :: proc(node: ^BSPNode, grid: ^[]int) {
    if node == nil do return
    
    if !node.is_leaf {
        generate_room_array(node.left, grid)
        generate_room_array(node.right, grid)
        process_doors(node.room.doors, grid)
        return
    }

    process_leaf(node, grid)
}

process_outer_edge :: proc(x, y:int, room: Room) -> bool {
    width := room.x+room.width-1
    height := room.y+room.height-1
    return x==0 || y==0 || y==height || x==width
}

process_inner_wall :: proc(x, y:int, room: Room) -> bool {
    width := room.x+room.width
    height := room.y+room.height

    return x==0 || y==0 || x==room.x || y==room.y || x==width || y == height
}

process_doors :: proc(door: [2]int, grid: ^[]int) {
    for x in 0..<3 {
        for y in 0..<3 {
            tile_index := (door[1]-y) * GRID_WIDTH + (door[0]-x)
            grid[tile_index] = 2 
        }  
    }
}

process_leaf :: proc(node: ^BSPNode, grid: ^[]int) {
    room := node.room

    for x in room.x..<room.x + room.width {
        for y in room.y..<room.y + room.height {
            tile_index := y * GRID_WIDTH + x
            grid[tile_index] = 0
            if process_outer_edge(x,y,room) {
                grid[tile_index] = 0
            } else if process_inner_wall(x,y,room) {
                grid[tile_index] = 1
            }
        }
    }
}