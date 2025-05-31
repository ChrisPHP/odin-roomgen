package main

import "core:math/rand"
import "core:fmt"
import "core:sort"
import "core:slice"

Door :: struct {
    x, y: int,
    vertical: bool
}

Index_Value :: struct {
    index: int,
    size: int,
}


sort_rooms :: proc(a, b: Index_Value) -> int {
    return b.size - a.size
}
 
generate_house :: proc(bedrooms, width, height: int) -> ([]int, []int) {
    grid := make([]int, width*height)
    floor := make([]int, width*height)

    public_rooms := make([dynamic]Room)
    private_rooms := make([dynamic]Room)
    hallway_rooms := make([dynamic]Room)

    public_root := generate_bsp(50, 25,50, 3, {0, 0})
    room_to_array(public_root, &public_rooms)

    hallway_root := generate_bsp(50, 10, 50, 0, {0,25})
    room_to_array(hallway_root, &hallway_rooms)

    private_root := generate_bsp(50, 15, 50, 2, {0,35})
    room_to_array(private_root, &private_rooms)

    assign_room(&public_rooms, true)
    assign_room(&private_rooms, false)

    generate_grid_array(&public_rooms, &grid, &floor)
    generate_grid_array(&private_rooms, &grid, &floor)
    generate_grid_array(&hallway_rooms, &grid, &floor)

    find_hallway_connection(hallway_rooms[0], &public_rooms, &grid, &floor)
    find_hallway_connection(hallway_rooms[0], &private_rooms, &grid, &floor)
    add_exit_entrance_door(hallway_rooms[0], &grid, &floor, width, height)

    free_bsp_tree(public_root)
    free_bsp_tree(hallway_root)
    free_bsp_tree(private_root)
    delete(private_rooms)
    delete(hallway_rooms)
    delete(public_rooms)

    return grid, floor
}

generate_grid_array :: proc(rooms: ^[dynamic]Room, grid, floor: ^[]int) {

    last_room: Room
    doors := make([dynamic]Door)

    for room, index in rooms {
        for x in room.x..<room.x + room.width {
            for y in room.y..<room.y + room.height {
                tile_index := y * GRID_WIDTH + x
                grid[tile_index] = 1
                if process_outer_edge(x,y,room) {
                    grid[tile_index] = 0
                } else if process_inner_wall(x,y,room) {
                    grid[tile_index] = 1
                }

                if y > 0 && x > 0 && x < room.x+room.width-2 {
                    if y >= room.y+3  {
                        floor[tile_index] = 1 
                        if room.type == .Kitchen || room.type == .Bathroom {
                            floor[tile_index] = 3
                        } else if room.type == .Living || room.type == .Bedroom {
                            floor[tile_index] = 4 
                        }
                    } 
                    if y < room.y+3 || y == 3 {
                        floor[tile_index] = 2
                    }
                }
            }
        }
        
        if index > 0 {
            if last_room.x+last_room.width == room.x {
                overlap_start := max(last_room.y, room.y)
                overlap_end := max(last_room.y+last_room.height, room.y+room.height)-1
                
                door_y := rand_int_range(overlap_start+3, overlap_end-3)
                new_door := Door{
                    x=last_room.x+last_room.width-2,
                    y=door_y,
                    vertical=true
                }
                append(&doors, new_door)
            } else if last_room.y+last_room.height == room.y {
                overlap_start := max(last_room.x, room.x)
                overlap_end := max(last_room.x+last_room.width, room.x+room.width)-1
                
                door_x := rand_int_range(overlap_start+3, overlap_end-3)
                new_door := Door{
                    x=door_x,
                    y=last_room.y+last_room.height-2,
                    vertical=false
                }
                append(&doors, new_door)
            }
        }
        last_room = room
    }

    for d in doors {
        for x in 0..<3 {
            for y in 0..<3 {
                tile_index := (d.y+y) * GRID_WIDTH + (d.x+x)
                grid[tile_index] = 1
                if d.vertical {
                    if y < 3 && x < 2 {
                        floor[tile_index] = 2
                    }
                } else if x < 2 {
                    tile_index = (d.y+y+2) * GRID_WIDTH + (d.x+x)
                    floor[tile_index] = 1
                }
            
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

assign_room :: proc(room_array: ^[dynamic]Room, public: bool) {
    indices := make([]Index_Value, len(room_array))
    defer delete(indices)
    for i in 0..<len(room_array) {
        indices[i] = {index = i, size = room_array[i].size}
    }

    sort.quick_sort_proc(indices[:], sort_rooms)

    for indice, i in indices {
        r := &room_array[indice.index]
        if public {
            if i == 0 {
                r.type = .Living
            } else if i == 1 {
                r.type = .Dining
            } else {
                r.type = .Kitchen
            }
        } else {
            if i == 0 {
                r.type = .Bedroom
            } else if i == 1 {
                r.type = .Bathroom
            } else {
                r.type = .Wardrobe
            }
        }
    }
}

find_hallway_connection :: proc(hallway: Room, rooms: ^[dynamic]Room, grid, floor: ^[]int) {
    door: [2]int
    vertical := false

    for r, i in rooms {
        if r.type == .Living || r.type == .Bedroom || i == len(rooms)  {
            if hallway.y == r.y+r.height {
                overlap_start := max(r.x, hallway.x)
                overlap_end := min(r.x+r.width, hallway.x+hallway.width)-1
                
                door_x := rand_int_range(overlap_start+3, overlap_end-3)
                door = [2]int{door_x, (r.y+r.height)-2}
                vertical = false
                break
            } else if hallway.x == r.x+r.width {
                overlap_start := max(r.y, hallway.y)
                overlap_end := min(r.y+r.height, hallway.y+hallway.height)-1
                
                door_y := rand_int_range(overlap_start+3, overlap_end-3)
                door = [2]int{(r.x+r.width)-2, door_y}
                vertical = true
                break
            } else if hallway.y+hallway.height == r.y {
                overlap_start := max(r.x, hallway.x)
                overlap_end := min(r.x+r.width, hallway.x+hallway.width)-1
                
                door_x := rand_int_range(overlap_start+3, overlap_end-3)
                door = [2]int{door_x, r.y-2}
                vertical = false
                break
            } else if hallway.x+hallway.width == r.x {
                overlap_start := max(r.y, hallway.y)
                overlap_end := min(r.y+r.height, hallway.y+hallway.height)-1
                
                door_y := rand_int_range(overlap_start+3, overlap_end-3)
                door = [2]int{r.x-2, door_y}
                vertical = true
                break
            }
        }
    }

    
    for x in 0..<3 {
        for y in 0..<3 {
            tile_index := (door[1]+y) * GRID_WIDTH + (door[0]+x)
            grid[tile_index] = 1
            if !vertical && x < 2 {
                tile_index = (door[1]+y+2) * GRID_WIDTH + (door[0]+x)
                floor[tile_index] = 1
            }
        }
    }
}

add_exit_entrance_door :: proc(room: Room, grid, floor: ^[]int, width,height: int) {
    door: [2]int
    vertical := false

    if room.x == 0 {
        door_y := rand_int_range(room.y+3, room.height+room.y-3)
        door = [2]int{room.x, door_y}
        vertical = true
    } else if room.y == 0 {
        door_x := rand_int_range(room.x+3, room.width+room.x-3)
        door = [2]int{door_x, room.y}
        vertical = false
    } else if room.width == width {
        door_y := rand_int_range(room.y+3, room.height+room.y-3)
        door = [2]int{room.width, door_y}
        vertical = true
    } else if room.height == height {
        door_x := rand_int_range(room.x+3, room.width+room.x-3)
        door = [2]int{door_x, room.height}
        vertical = false
    }

    for x in 0..<1 {
        for y in 0..<3 {
            tile_index := (door[1]+y) * GRID_WIDTH + (door[0]+x)
            if tile_index >= 0 {
                grid[tile_index] = 1
                if vertical {
                    if  x < 2 {
                        floor[tile_index] = 2
                    }
                } else if x < 2 {
                    tile_index = (door[1]+y+2) * GRID_WIDTH + (door[0]+x)
                    floor[tile_index] = 1
                }
            }   
        }
    }
}