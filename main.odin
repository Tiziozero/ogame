package main

import "core:mem"
import "core:os"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib" 

GameContext :: struct {
    frame_arena: mem.Dynamic_Arena,
    game: game,
}

vec2 :: rl.Vector2;
rect :: rl.Rectangle;
t2d :: rl.Texture2D;
SCREEN_SIZE :: vec2{1200,900}

rect_size :: proc(r: rect) -> vec2 {
    return vec2{r.width, r.height};
}
rect_pos :: proc(r: rect) -> vec2 {
    return vec2{r.x, r.y};
}
game :: struct {
    current_handle: int,
    entities: map[int]Entity,
    mouse_pos: vec2,
    player_handle: int,
    camera: rect,
    dt: f32,
    textures: map[int]t2d,
    frame_arena: mem.Dynamic_Arena,
    wmap: [dynamic]Tile,
};

EntityHandler :: proc(game: ^game, handle: int);
AbilityHandler :: proc(game: ^game, owner_handle: int);

EntityStatus :: enum {
    ESDEAD = 0,
    ESALIVE,
    ESDYING,
    ESON=ESALIVE,
};
Ability :: struct {
    active, index: int, // it's index in the enities ablity
    cooldown, cooldown_time, cost: f32,
    init, act: AbilityHandler,
};
Entity :: struct {
    status: EntityStatus,
    handle: int,
    texture: int, // texture key for game.textures
    body: rect,
    direction: vec2,
    atk, def, health, max_health, speed: f32,
    payload: rawptr,
    update, draw: EntityHandler,
    abilities: [5]Ability
}
get_env :: proc(s: string) -> string {
    ret := os.get_env(s, context.allocator);
    fmt.printfln("-- got %s from get_env", ret);
    return ret;
}

apply_camera :: proc(game: ^game, v: vec2) -> vec2 {
    return v - rect_pos(game.camera);
};
unapply_camera :: proc(game: ^game, v: vec2) -> vec2 {
    return v + rect_pos(game.camera);
};

draw_entity :: proc(game: ^game, e: ^Entity) {
    draw_healt := false;
    // chech it's within camera
    if e.body.x > game.camera.x + game.camera.width ||
        e.body.x + e.body.width < game.camera.x {
        return;
    }
    if e.body.y > game.camera.y + game.camera.height ||
        e.body.y + e.body.height < game.camera.y {
        return;
    }
    origin := rect_size(e.body) * 0.5; // origin for raylib draw pro
    rotation : f32 = 0.0; // rodation
    // dest to draw, is center of body so add origin
    dest := apply_camera(game, rect_pos(e.body) + origin);
    img, ok := game.textures[e.texture];
    if !ok {
        fmt.panicf("failed to get image for index %d\n", e.texture);
    } else {
    }
    rl.DrawTexturePro(img,
        rect{0, 0, f32(img.width), f32(img.height)},
        rect{dest.x, dest.y, e.body.width, e.body.height},
        origin, rotation, rl.WHITE);
}
entity_new :: proc(txt_handle: int, x, y, w, h, max_health, atk, def: f32) -> Entity {
    e : Entity;
    e.texture = txt_handle;
    e.body.x = x;
    e.body.y = y;
    e.body.width = w;
    e.body.height = h;
    e.atk = atk;
    e.def = def;
    e.max_health = max_health;
    e.speed = 200;
    return e;
};
game_add_entity :: proc(game: ^game, e: ^Entity) -> int {
    e.handle = game.current_handle;
    game.entities[game.current_handle] = e^; // will copy
    game.current_handle += 1; // increment
    return e.handle;
}
game_remove_entity :: proc(game: ^game, handle: int) -> int {
    delete_key(&game.entities, handle); // delete_key
    return 1;
}
game_new ::proc() -> game {
    g : game;
    g.entities = map[int]Entity{};
    g.textures = map[int]t2d{};
    g.current_handle = 0;
    return g;
}
game_free :: proc(game: ^game) {
    for l, v in game.textures {
        rl.UnloadTexture(v);
    }
    delete(game.entities);
    delete(game.textures);
}
draw_entities_sorted :: proc(game: ^game, allocator := context.allocator) {
    handles := make([]int, len(game.entities), allocator)
    i := 0
    for handle in game.entities {
        handles[i] = handle
        i += 1
    }
    // insertion sort — fast for nearly-sorted data each frame
    for i := 1; i < len(handles); i += 1 {
        key := handles[i]
        j := i - 1
        for j >= 0 && game.entities[handles[j]].body.y > game.entities[key].body.y {
            handles[j + 1] = handles[j]
            j -= 1
        }
        handles[j + 1] = key
    }
    for handle in handles {
        e := &game.entities[handle]
        if e.status != .ESDEAD {
            draw_entity(game, e)
        }
    }
}
get_dt :: proc() -> f32 {
    return f32(rl.GetFrameTime())
}
game_load_texture :: proc(game: ^game, path: string) -> int {
    cstr_path := strings.clone_to_cstring(path);
    t := rl.LoadTexture(cstr_path);
       if t.id == 0 {
           fmt.panicf("what. rl texture id is 0");
       }
    delete(cstr_path);
    game.textures[int(t.id)] = t;
    return int(t.id);
}
Tile :: struct {
    c: int,
};
cells :: 16;

random_from_coords :: proc(i, j, s: int, a, b: int) -> int {
    // Mix inputs into a single value (hash)
    x := i * 374761393 + j * 668265263 + s * 1442695040888963407
    x = (x ~ (x >> 13)) * 1274126177
    x = x ~ (x >> 16)

    // Ensure positive
    if x < 0 {
        x = -x
    }

    // Map to range [a, b]
    range := b - a + 1
    return a + (x % range)
}
get_draw_tile_f :: proc(game: ^game, i,j: int, f: f32) {
    // apply to draw pos, so * f
    d := apply_camera(game, vec2{f32(i*cells)*f, f32(j*cells)*f});
    c := random_from_coords(i, j, 69, 0, 2);
    src := rect{x=304 + f32(cells*c),y=16,
              width=cells, height=cells};
               // again dest is draw pos, so * f
    dest := rect{d.x, d.y, cells*f32(f), cells*f32(f)};
    color : rl.Color;
    if c == 1 {
        color = rl.WHITE
    } else if color == 2 {
        color = rl.RED
    } else {
        color = rl.BLUE
    }
    rl.DrawRectangleRec(dest,color);
}
entity_ability_act :: proc(game: ^game, e: ^Entity, index: int) {
    if e.abilities[index].active == 0 {
        fmt.printfln("ability %d is inactive.", index);
        return;
    }
    e.abilities[index].act(game, e.handle);
}
main :: proc() {
    fmt.printfln("Hello %s", get_env("a"));
    fmt.println("Hellp, World loop!");
    // init game/ctx
    rl.InitWindow(1200,900, "Entricity");
    defer rl.CloseWindow();
    // rl.SetTargetFPS(60);

    game := game_new();

    player_tx_handle := game_load_texture(&game, "imgs/apple.png");
    player := entity_new(player_tx_handle, 100, 100, 80, 80, 500, 100, 5);
    player.update = proc(game: ^game, handle: int) {
    };
    player.draw = proc(game: ^game, handle: int) {
        draw_entity(game, &game.entities[handle]);
    };
    player_handle := game_add_entity(&game, &player);

    enemy1_tx_handle := game_load_texture(&game, "imgs/banana.png");
    enemy1 := entity_new(enemy1_tx_handle, 200, 200, 100, 100, 500, 100, 5);
    enemy1.update = proc(game: ^game, handle: int) {
    };
    enemy1.draw = proc(game: ^game, handle: int) {
        draw_entity(game, &game.entities[handle]);
    };
    enemy1_handle := game_add_entity(&game, &enemy1);

   // player abilities
   {
       a: Ability;
          a.active = 1;
          a.index = 0;
          a.act = proc(game: ^game, owner_handle: int) {
              fmt.println("called act for ability.");
          };
          p := &game.entities[player_handle];
             p.abilities[0] = a;
   }

    handle_player_input :: proc(game: ^game, p: ^Entity, dt: f32) {
        pv: vec2;
        if rl.IsKeyDown(.A) {
            pv.x -= 1;
        }
        if rl.IsKeyDown(.D) {
            pv.x += 1;
        }
        if rl.IsKeyDown(.W) {
            pv.y -= 1;
        }
        if rl.IsKeyDown(.S) {
            pv.y += 1;
        }
        if rl.IsMouseButtonPressed(.LEFT) {
            entity_ability_act(game, p, 0);
        }
        pv = rl.Vector2Normalize(pv);
        p.body.x += pv.x * p.speed * dt;
        p.body.y += pv.y * p.speed * dt;
    }
    for !rl.WindowShouldClose() {
        {
            player := game.entities[player_handle];
            // cam pos is player center - half screen size
            campos := rect_pos(player.body) + // get camera pas
                        rect_size(player.body)/2 - SCREEN_SIZE/2;
            camsize := SCREEN_SIZE;
            game.camera.x = campos.x
            game.camera.y = campos.y
            game.camera.width = camsize.x
            game.camera.height = camsize.y
        }
        // get dt
        game.dt = get_dt();
        handle_player_input(&game, &game.entities[player_handle], game.dt);
        for handle, e in game.entities {
            e.update(&game, handle);
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);
        { // draw bg
            f :f32= 1; // scale factor
            player := game.entities[player_handle];
            px: = int(player.body.x / cells);
            py: = int(player.body.y / cells);
            for i in px-20..=px+20 {
                for j in py-20..=py+20 {
                    // if i < 0 || j < 0 {continue;}
                    // if i >= 128 || j >= 128 {continue;}
                    get_draw_tile_f(&game, i, j, f);
                }
            }
        }
        for handle, e in game.entities {
            e.draw(&game, handle);
        }
        rl.DrawFPS(10,10);
        rl.EndDrawing();
        draw_entities_sorted(&game);
    }

    game_free(&game);
}
