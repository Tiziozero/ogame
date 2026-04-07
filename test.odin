package main
import "core:fmt";
import "core:math"
import "vendor:raylib";


base_projectile_data :: struct {
};
// index: ability index in entity
init_base :: proc(game:^ game, e: ^Entity, index: int) -> Ability {
    fmt.println("Init test ability");
    a :Ability;
    a.owner = e.handle;
    a.act = proc(game: ^game,  self: ^Ability, owner: ^Entity) {
        p: Projectile;
        p.kind = .PkBase;
        p.dir = owner.direction;
        p.origin = rect_pos(owner.body) + 0.5 * rect_size(owner.body);
        p.pos = p.origin;
        p.damage = 5 + math.exp(f32(self.level)*0.2); // random?
    }

    a.cooldown_time = 1;
    return a;
}
