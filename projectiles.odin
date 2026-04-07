package main

import "vendor:raylib"
ProjectileData :: union {
    base_projectile_data,
};
ProjectileKind :: enum {
    PkBase,
};
ProjectileHandler :: proc(element: ^Projectile);
Projectile :: struct { // effect and what not
    update, draw: ProjectileHandler,
    kind: ProjectileKind,
    data: ProjectileData,

    pos, dir, origin: raylib.Vector2,
    damage: f32,
    owner_handle: int,
};
