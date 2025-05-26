package main

import "core:math/rand"
import "core:fmt"
import "core:sort"

sort_rooms :: proc(a, b: Room) -> int {
    return b.size - a.size
}
 
generate_house :: proc(grid: ^[]int, bedrooms, width, int: int) {


    public_rooms := make([dynamic]Room)
    private_rooms := make([dynamic]Room)
    hallway_rooms := make([dynamic]Room)

    public_root := generate_bsp(50, 25,50, 4, {0, 0})
    room_to_array(public_root, &public_rooms)

    hallway_root := generate_bsp(50, 10, 50, 0, {0,25})
    room_to_array(hallway_root, &hallway_rooms)

    private_root := generate_bsp(50, 15, 50, 2, {0,35})
    room_to_array(private_root, &private_rooms)

    generate_grid_array(&public_rooms, grid)
    generate_grid_array(&private_rooms, grid)
    generate_grid_array(&hallway_rooms, grid)

    assign_room_public(&public_rooms)
    assign_room_private(&private_rooms)

    free_bsp_tree(public_root)
    free_bsp_tree(hallway_root)
    free_bsp_tree(private_root)
    delete(private_rooms)
    delete(hallway_rooms)
    delete(public_rooms)
}

generate_grid_array :: proc(rooms: ^[dynamic]Room, grid: ^[]int) {

    last_room: Room
    doors := make([dynamic][2]int)

    for room, index in rooms {
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
        
        if index > 0 {
            if last_room.x+last_room.width == room.x {
                overlap_start := max(last_room.y, room.y)
                overlap_end := max(last_room.y+last_room.height, room.y+room.height)-1
                
                door_y := rand_int_range(overlap_start+3, overlap_end-3)
                append(&doors, [2]int{last_room.x+last_room.width-2, door_y})
            } else if last_room.y+last_room.height == room.y {
                overlap_start := max(last_room.x, room.x)
                overlap_end := max(last_room.x+last_room.width, room.x+room.width)-1
                
                door_x := rand_int_range(overlap_start+3, overlap_end-3)
                append(&doors, [2]int{door_x, last_room.y+last_room.height-2})
            }
        }
        last_room = room
    }

    for d in doors {
        for x in 0..<3 {
            for y in 0..<3 {
                tile_index := (d[1]+y) * GRID_WIDTH + (d[0]+x)
                grid[tile_index] = 2
            }
        }
    }

    delete(doors)
}

room_to_array :: proc(node: ^BSPNode, room_array: ^[dynamic]Room) {
    if node == nil do return

    if !node.is_leaf {
        room_to_array(node.left, room_array)
        room_to_array(node.right, room_array)
    } else {
        append(room_array, node.room)
    }
}

assign_room_public :: proc(room_array: ^[dynamic]Room) {
    room_lenth := len(room_array)

    sort.quick_sort_proc(room_array[:], sort_rooms)

    for &r, i in room_array {
        if i == 0 {
            r.type = .Living
        } else if i == 1 {
            r.type = .Dining
        } else {
            r.type = .Kitchen
        }
    }
}

assign_room_private :: proc(room_array: ^[dynamic]Room) {
    room_lenth := len(room_array)

    sort.quick_sort_proc(room_array[:], sort_rooms)

    for &r, i in room_array {
        if i == 0 {
            r.type = .Bedroom
        } else if i == 1 {
            r.type = .Bathroom
        } else {
            r.type = .Wardrobe
        }
    }
}