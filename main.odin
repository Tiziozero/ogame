package main

import "core:mem"
import "core:os"
import "core:fmt"
import rl "vendor:raylib"
GameContext :: struct {
    frame_arena: mem.Dynamic_Arena,
    game: game,
}

vec2 :: rl.Vector2;
rect :: rl.Rectangle;
t2d :: rl.Texture2D;

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
};

EntityHandler :: proc(game: ^game, handle: int);

EntityStatus :: enum {
    ESDEAD = 0,
    ESALIVE,
    ESDYING,
    ESON=ESALIVE,
};
Entity :: struct {
    status: EntityStatus,
    handle: int,
    texture: int, // texture key for game.textures
    body: rect,
    direction: vec2,
    atk, def, health, max_health: f32,
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
    return e;
};
game_add_entity :: proc(game: ^game, e: ^Entity) -> int {
    e.handle = game.current_handle;
    game.entities[game.current_handle] = e^; // will copy
    game.current_handle += 1; // increment
    return e.handle;
}
game_new ::proc() -> game {
    g : game;
    g.entities = map[int]Entity{};
    g.textures = map[int]t2d{};
    g.current_handle = 0;
    return g;
}
game_free :: proc(game: ^game) {
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
main::proc() {
    // init game/ctx
    game := game_new();

    fmt.printfln("Hello %s", get_env("a"));
    rl.InitWindow(1200,900, "Entricity");

    for !rl.WindowShouldClose() {
        fmt.println("Hellp, World loop!");
        // get dt
        game.dt = get_dt();


        rl.BeginDrawing();
        rl.EndDrawing();
        draw_entities_sorted(&game);
    }

    game_free(&game);
}
