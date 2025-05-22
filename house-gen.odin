package main

import "core:math/rand"
import "core:fmt"
import "core:sort"

sort_rooms :: proc(a, b: Room) -> int {
    return b.size - a.size
}
 
generate_house :: proc(bedrooms, width, int: int) {


    public_rooms := make([dynamic]Room)
    private_rooms := make([dynamic]Room)

    public_root := generate_bsp(50, 25,50, 1, {0, 25})
    room_to_array(public_root, &public_rooms)

    private_root := generate_bsp(50, 25, 50, 1, {0,0})
    room_to_array(private_root, &private_rooms)

    assign_room_public(&public_rooms)
    assign_room_private(&private_rooms)

    free_bsp_tree(public_root)
    free_bsp_tree(private_root)
    delete(private_rooms)
    delete(public_rooms)
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
            r.type = .Kitchen
        } else {
            r.type = .Toilet
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