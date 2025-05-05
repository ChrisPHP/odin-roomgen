package main

import "core:fmt"
import "core:math/noise"
import "core:math/rand"
import rl "vendor:raylib"
import "core:mem"
import "core:math"

import auto "autotile"

CELL_SIZE :: 32
TEXTURE: rl.Texture

Block_Struct :: struct {
    x,y: int,
    ready: bool
}



render_texture :: proc(x: int, y: int, pos: [2]int) {
    tile_x := pos[0]
    tile_y := pos[1]
    rect := rl.Rectangle{f32(tile_x)*CELL_SIZE, f32(tile_y)*CELL_SIZE, CELL_SIZE, CELL_SIZE}
    tileDest := rl.Rectangle{f32(x)*CELL_SIZE, f32(y)*CELL_SIZE, CELL_SIZE, CELL_SIZE}

    origin:f32  = CELL_SIZE / 2

    rl.DrawTexturePro(TEXTURE, rect, tileDest, rl.Vector2{-origin, -origin}, 0, rl.WHITE)
}



gen_rooms :: proc(width, height, block_size: int) -> ([]Block_Struct, []int, []int) {
    valid_directions :: proc(x,y, width, length: int, grid: []bool) -> [][2]int {
        directions := [4][2]int{{0,-1}, {1,0}, {0,1}, {-1,0}}
        available_directions: [dynamic][2]int
        for i in directions {
            new_x := x + i[0]
            new_y := y + i[1]
            size := new_y * width + new_x
            if size < 0 || size >= length {
                continue
            }
            append(&available_directions, i)
        }

        if len(available_directions) == 0 {
            return [][2]int{}
        }

        fixed := make([][2]int, len(available_directions))
        copy(fixed, available_directions[:])
        delete(available_directions)
        return fixed 
    }

    mini_grid := make([]bool, (width/block_size)*(height/block_size))
    defer delete(mini_grid)
    blocks := make([]Block_Struct, 20)

    x := (width/block_size)/2
    y := (height/block_size)/2
    new_width := width/block_size
    new_height := height/block_size

    for &i, index in blocks{

        selected_block := rand.choice(blocks[:])
        for {
            if index > 0 && selected_block.ready == false {
                selected_block = rand.choice(blocks[:])
                x = selected_block.x
                y = selected_block.y
            } else {
                break
            }
        }

        valid := valid_directions(x, y, new_width,len(mini_grid), mini_grid)
        defer delete(valid)
        item := rand.choice(valid[:])

        x += item[0]
        y += item[1]
        size := y * new_width + x
        mini_grid[size] = true
        i.x = x
        i.y = y
        i.ready = true
    }

    grid := make([]int, width*height)
    floor := make([]int, width*height)

    for b in blocks {
        p1 := (b.x*5)
        p2 := (b.y*5)
        wh := 5
        for x in p1..<p1+wh {
            for y in  p2..<p2+wh {
                size := y * width + x
                grid[size] = 1

                floor_y := y + 3
                floor_size := floor_y * width + x
                if floor_y < height && floor[floor_size] != 2 {
                    floor[floor_size] = 1
                }

                if y >= p2 && y <= p2+2 {
                    mx := x / 5
                    my := y / 5
                    left := my * new_width + (mx-1)
                    up := (my-1) * new_width + mx
                    right := my * new_width + (mx+1)
                    
                    if left >= 0 && right >= 0 && up >= 0 {
                        if x == p1 {
                            if up > 0 && left > 0 {
                                if mini_grid[left] == true &&  mini_grid[up] == false{
                                    s := y * width + x-1
                                    floor[s] = 2
                                }
                            }
                        }
    
                        if floor[size] != 1 && x < p1+wh-1 && mini_grid[up] == false {
                            floor[size] = 2
                        } else if  mini_grid[up] == false && mini_grid[right] == true {
                            floor[size] = 2       
                        } 
                    }     
                }
            }
        }
    }

    return blocks, floor, grid
}

main :: proc() {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    defer mem.tracking_allocator_destroy(&tracking_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        fmt.printfln("MEMORY SUMMARY")
        for _, leak in tracking_allocator.allocation_map {
            fmt.printfln(" %v leaked %m", leak.location, leak.size)
        }
        for bad_free in tracking_allocator.bad_free_array {
            fmt.printfln(" %v allocation %p was freed badly", bad_free.location, bad_free.memory)
        }
    }

    rl.InitWindow(1600, 1600, "Room Generator")
    rl.SetTargetFPS(60)

    TEXTURE = rl.LoadTexture("trimmings.png")

    grid_width := 50
    grid_height := 50
    
    grid := make([]int, grid_width*grid_height)
    floor := make([]int, grid_width*grid_height)
    defer delete(grid)
    defer delete(floor)

    root := generate_bsp(50, 50, 2)
    generate_tileset_array(root, &grid, &floor)
    print_bsp_tree_text(root, 1)

    auto.initialise_bit_level(grid_width, grid_height)
    new_grid := auto.create_bit_mask(&grid, 1, .wang_corner)
    new_floor := auto.create_bit_mask(&floor, 2, .wang_edge)
    defer delete(new_floor)
    defer delete(new_grid)
    /*
    auto.initialise_bit_level(grid_width, grid_height)

    
    blocks, floor, grid := gen_rooms(grid_width, grid_height, 5)
    defer delete(grid)
    defer delete(blocks)
    defer delete(floor)

    new_grid := auto.create_bit_mask(&grid, 1, .wang_corner)
    new_floor := auto.create_bit_mask(&floor, 2, .wang_edge)
    defer delete(new_floor)
    defer delete(new_grid)
    */

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)


        //print_bsp_tree(root, 1)
        
        for x in 0..<grid_width {
            for y in 0..<grid_height {
                size := y * grid_width + x
                val := new_grid[size]
                val1 := floor[size]
                val2 := new_floor[size]

                if val1 == 1 {
                    render_texture(x,y, {5, 3})
                }
                if val != 15{
                    pos := auto.select_tile_type(val, .wang_corner)
                    render_texture(x,y, pos)   
                }
                if val2 != 0 {
                    pos := auto.select_tile_type(val2, .wang_edge)
                    pos[0] += 4
                    render_texture(x,y, pos) 
                }
            }
        }
        

        rl.EndDrawing()
    }

    free_bsp_tree(root)
    rl.UnloadTexture(TEXTURE)
    rl.CloseWindow()
}