package main

import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"

Room :: struct {
    x, y: int,
    width, height: int,
    entrance: bool,
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
MAX_ROOM_SIZE :: 20
SPLIT_RATIO_MIN :: 0.4  // Minimum ratio for splitting (30%)
SPLIT_RATIO_MAX :: 0.6  // Maximum ratio for splitting (70%)
GRID_WIDTH := 50

new_bsp_node :: proc(x, y, width, height: int) -> ^BSPNode {
    node := new(BSPNode)
    node.room = Room{x, y, width, height, false}
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

print_bsp_tree_text :: proc(node: ^BSPNode, depth: int = 0) {
    if node == nil {
        return
    }
    
    // Print indentation
    for i in 0..<depth {
        fmt.print("  ")
    }

    // Print node information
    fmt.printf("Node: x=%d, y=%d, w=%d, h=%d, leaf=%v\n", 
               node.room.x, node.room.y, 
               node.room.width, node.room.height,
               node.is_leaf)
    
    // Recursively print children
    if !node.is_leaf {
        print_bsp_tree_text(node.left, depth + 1)
        print_bsp_tree_text(node.right, depth + 1)
    } else if is_exterior_node(node, 50,50) {
        node.room.entrance = false
    }
}

is_exterior_node :: proc(node: ^BSPNode, grid_width, grid_height: int) -> bool {
    // Check if the room has at least one edge on the perimeter
    return node.room.x == 0 || 
           node.room.y == 0 || 
           node.room.x + node.room.width == grid_width || 
           node.room.y + node.room.height == grid_height
}


generate_tileset_array :: proc(node: ^BSPNode, grid, floor: ^[]int) {
    if node == nil do return

    // Early recursion for non-leaf nodes
    if !node.is_leaf {
        generate_tileset_array(node.left, grid, floor)
        generate_tileset_array(node.right, grid, floor)
        return
    }
    
    // Process leaf nodes
    process_leaf_node(node, grid, floor)
}

process_leaf_node :: proc(node: ^BSPNode, grid, floor: ^[]int) {
    room := node.room

    door_x, door_y: int
    if room.entrance {
        door_x = int(rand.float32_range(f32(room.x + 3), f32(room.x + room.width - 3)))
        door_y = int(rand.float32_range(f32(room.y + 5), f32(room.y + room.height - 5)))
    }

    // Process each tile in the room
    for x in room.x..<room.x + room.width {
        for y in room.y..<room.y + room.height {
            tile_index := y * GRID_WIDTH + x
            
            // Set tile type based on position
            if room.entrance {
                process_tile(x, y, tile_index, room, door_x, door_y, grid, floor)
            } else {
                process_tile_no_door(x, y, tile_index, room, grid, floor)
            }
        }
    }
}

process_tile_no_door :: proc(x, y, tile_index: int, room: Room, grid, floor: ^[]int) {
    // Default to wall
    grid[tile_index] = 1
    
    // Outer walls
    if x == room.x || y == room.y {
        grid[tile_index] = 0
    }
    
    // Inner floor area (simpler version without door considerations)
    inner_x := room.x + 1
    inner_y := room.y + 1
    room_right := room.x + room.width
    room_bottom := room.y + room.height
    
    if x >= inner_x && y >= inner_y && x < room_right && y < room_bottom {
        if x < room_right - 1 {
            floor[tile_index] = 1
        }
        if y >= inner_y && y <= inner_y + 2 {
            if x >= inner_x && x <= room_right - 2 {
                floor[tile_index] = 2
            }
        }
    }
}

process_tile :: proc(x, y, tile_index: int, room: Room, door_x, door_y: int, grid, floor: ^[]int) {
    // Default to wall
    grid[tile_index] = 1
    
    // Outer walls
    if x == room.x || y == room.y {
        grid[tile_index] = 0
    }
    
    // Door area
    if is_in_door_area(x, y, door_x, door_y) {
        grid[tile_index] = 1
        if x < door_x + 3 {
            floor[tile_index] = 1
        }
    }
    
    // Inner floor area
    process_inner_floor(x, y, tile_index, room, door_x, door_y, floor)
    
    // Side door area
    process_side_door(x, y, tile_index, room, door_y, floor)
}

is_in_door_area :: proc(x, y, door_x, door_y: int) -> bool {
    return (x >= door_x && x <= door_x + 3) || (y >= door_y && y <= door_y + 5)
}

process_inner_floor :: proc(x, y, tile_index: int, room: Room, door_x, door_y: int, floor: ^[]int) {
    inner_x := room.x + 1
    inner_y := room.y + 1
    room_right := room.x + room.width
    room_bottom := room.y + room.height
    
    

    if x >= inner_x && y >= inner_y && x < room_right && y < room_bottom {
        if x < room_right - 1 {
            floor[tile_index] = 1
        }
        
        // Special floor tiles near entrance
        if y >= inner_y && y <= inner_y + 2 {
            if x >= inner_x && x <= room_right - 2 {
                floor[tile_index] = 2
            }
            
            // Door threshold
            if x >= door_x && x <= door_x + 2 {
                floor[tile_index] = 1
            }
        }
    }

}

process_side_door :: proc(x, y, tile_index: int, room: Room, door_y: int, floor: ^[]int) {
    if y >= door_y && y <= door_y + 5 && x == room.x {
        floor[tile_index] = 1
        
        // Set floor for adjacent tile to the left
        if x > 0 {
            adjacent_index := y * GRID_WIDTH + x - 1
            floor[adjacent_index] = 1
        }
        
        // Special floor type for lower door area
        if y < door_y + 3 {
            floor[tile_index] = 2
            if x > 0 {
                adjacent_index := y * GRID_WIDTH + x - 1
                floor[adjacent_index] = 2
            }
        }
    }
}

print_bsp_tree :: proc(node: ^BSPNode, depth: int = 0) {
    if node == nil {
        return
    }
    
    rl.DrawRectangle(i32(node.room.x)*32, i32(node.room.y)*32, i32(node.room.width)*32, i32(node.room.height)*32, rl.BLACK)
    rl.DrawRectangle(i32(node.room.x+1)*32, i32(node.room.y+1)*32, i32(node.room.width-1)*32, i32(node.room.height-1)*32, rl.RED)

    if !node.is_leaf {
        print_bsp_tree(node.left, depth + 1)
        print_bsp_tree(node.right, depth + 1)
    }
}