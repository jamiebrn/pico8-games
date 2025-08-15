function _init()
    poke(0x5f2d, 1)

    monkey_types = {
        dart_monkey = {range = 20, sprite = 2, cost = 30},
        ninja_monkey = {range = 25, sprite = 34, cost = 40}
    }

    darts = {}
    monkeys = {}
    bloons = {}

    particles = {}

    -- path in grid tiles
    path = {{-1, 6}, {8, 6}, {8, 3}, {5, 3}, {5, 12}, {2, 12}, {2, 9}, {11, 9}, {11, 6}, {13, 6}, {13, 12}, {7, 12}, {7, 16}}

    placing_monkey = false
    money = 100
    health = 50

    bloon_spawn_cooldown_max = 20
    bloon_spawn_cooldown = bloon_spawn_cooldown_max
end

function _update60()
    bloon_spawn_cooldown -= 1
    if bloon_spawn_cooldown <= 0 then
        bloon_spawn_cooldown = bloon_spawn_cooldown_max
        create_bloon()
    end

    for i, bloon in ipairs(bloons) do
        if not bloon:update() then
            deli(bloons, i)
            health -= 1
            for j = 0, flr(rnd(6)) + 3 do
                create_bloon_damage_particle()
            end
        end

        -- test collisions with darts
        for j, dart in ipairs(darts) do
            local sqdist = (dart.x - bloon.x) ^ 2 + (dart.y - bloon.y) ^ 2
            if sqdist <= 13 then
                bloon:damage(1)
                deli(darts, j)
                if bloon.health <= 0 then
                    deli(bloons, i)
                    money += flr(rnd(bloon:get_reward())) + 1
                    break
                end
            end
        end
    end

    for i, part in ipairs(particles) do
        if not part:update() do
            deli(particles, i)
        end
    end

    for i, dart in ipairs(darts) do
        dart:update()
        if not dart:is_alive() then
            deli(darts, i)
        end
    end

    for monkey in all(monkeys) do
        monkey:update()
    end

    if stat(34) & 2 == 2 and placing_monkey and not fget(mget(flr(stat(32) / 8), flr(stat(33) / 8)), 0) then
        add(monkeys, create_monkey(stat(32), stat(33)))
        money -= 30
        placing_monkey = false
    end

    if btnp(❎) and money >= 30 then
        placing_monkey = true
    end
end

function draw_sort(a)
	for i=1, #a do
		local j = i
		while j > 1 and a[j-1].y >= a[j].y do
			a[j], a[j-1] = a[j-1], a[j]
			j = j - 1
		end
	end
end

function _draw()
    cls()

    map(0, 0, 0, 0, 16, 16)

    if placing_monkey then
        local c1 = 12
        local c2 = 1
        if fget(mget(flr(stat(32) / 8), flr(stat(33) / 8)), 0) then
            c1 = 8
            c2 = 2
        end
        fillp(▒)
        circfill(stat(32), stat(33), 20, c2)
        fillp()
        circ(stat(32), stat(33), 20, c1)
    end

    for dart in all(darts) do
        dart:draw()
    end
    
    draw_objects = {}
    for bloon in all(bloons) do
        add(draw_objects, bloon)
    end
    for monkey in all(monkeys) do
        add(draw_objects, monkey)
    end
    draw_sort(draw_objects)

    for object in all(draw_objects) do
        object:draw()
    end

    for part in all(particles) do
        part:draw()
    end

    -- money
    line(8, 2, 8, 11, 1)
    line(9, 3, 9, 10, 1)
    rectfill(3, 2, 7, 11, 4)
    line(2, 3, 2, 10, 4)
    line(8, 3, 8, 10, 4)
    spr(16, 3, 3)
    print(money, 13, 4, 1)
    print(money, 12, 4, 7)

    -- health
    spr(17, 2, 14)
    print(health, 13, 14, 1)
    print(health, 12, 14, 7)

    spr(1, stat(32), stat(33)) -- cursor

    print("cpu " .. stat(1) .. "%", 0, 120, 7)
end

function rotate_vec(x, y, a)
    local vec = {}
    vec.x = x * cos(a) - y * sin(a)
    vec.y = x * sin(a) + y * cos(a)
    return vec
end

function create_dart(x, y, dir)
    local dart = {}
    dart.x = x
    dart.y = y
    dart.dir = dir

    dart.update = function(self)
        self.x += cos(self.dir) / 60 * 100
        self.y += sin(self.dir) / 60 * 100
    end

    dart.is_alive = function(self)
        local bottom = rotate_vec(-1, 0, self.dir)
        return self.x + bottom.x >= 0 and self.x + bottom.x <= 127 and self.y + bottom.y >= 0 and self.y + bottom.y <= 127
    end

    dart.draw = function(self)
        local top = rotate_vec(2, 0, self.dir)
        local bottom = rotate_vec(-1, 0, self.dir)
        line(self.x + top.x, self.y + top.y, self.x + bottom.x, self.y + bottom.y, 5)
    end

    add(darts, dart)
end

function ease_in_back(x)
    return (1.70158 + 1) * x * x * x - 1.70158 * x * x
end

function create_monkey(x, y)
    local throw_cooldown_max = 50
    
    local monkey = {}
    monkey.x = x
    monkey.y = y
    monkey.dir = 0

    monkey.throw_cooldown = 0

    monkey.throw_progress = 0
    monkey.throw_target = nil

    monkey.throw = function(self, xtarget, ytarget)
        if self.throw_target then return end
        self.throw_progress = 0
        self.throw_target = {x = xtarget, y = ytarget}
    end

    monkey._get_closest_bloon_pos = function(self)
        local shortest = 401
        local pos = nil
        for bloon in all(bloons) do
            local sqdist = (bloon.x - self.x) ^ 2 + (bloon.y - self.y) ^ 2
            if sqdist < shortest then
                if not pos then pos = {} end
                pos.x = bloon.x
                pos.y = bloon.y
                shortest = sqdist
            end
        end
        return pos
    end

    monkey.update = function(self)
        self.throw_cooldown -= 1

        local closest_bloon = self:_get_closest_bloon_pos()
        if closest_bloon and not self.throw_target then
            self.dir = atan2(closest_bloon.x - self.x, closest_bloon.y - self.y)

            if self.throw_cooldown <= 0 then
                self.throw_cooldown = throw_cooldown_max
                self:throw(closest_bloon.x, closest_bloon.y)
            end
        end

        if self.throw_target then
            self.dir = atan2(self.throw_target.x - self.x, self.throw_target.y - self.y)
            self.throw_progress += 10 / 60

            if self.throw_progress >= 1 then
                local hand = self:_get_hand_local_pos()
                local angle = atan2(self.throw_target.x - (self.x + hand.x), self.throw_target.y - (self.y + hand.y))
                create_dart(self.x + hand.x, self.y + hand.y, angle)
                self.throw_target = nil
                self.throw_progress = 0
            end
        end
    end

    monkey._get_hand_local_pos = function(self)
        return rotate_vec(2 + ease_in_back(self.throw_progress) * 3, 5, self.dir)
    end

    monkey.draw = function(self)
        local s =  min(flr((1 - self.dir) * 8 + 0.5) + 2, 9)
        spr(s, self.x - 4, self.y - 4)

        local hand = self:_get_hand_local_pos()
        local dart_top = rotate_vec(4 + ease_in_back(self.throw_progress) * 3, 5, self.dir)
        local dart_bottom = rotate_vec(1 + ease_in_back(self.throw_progress) * 3, 5, self.dir)
        line(self.x + dart_top.x, y + dart_top.y, self.x + dart_bottom.x, y + dart_bottom.y, 5)
        circfill(self.x + hand.x, y + hand.y, 1, 4)
    end

    return monkey
end

function create_bloon()
    local speed = 20
    local type_healths = {1, 3, 5, 10}
    local type_reward = {1, 2, 4, 8}

    local bloon = {}
    bloon.path_index_dest = 1

    bloon._get_pos_from_path_index = function(self)
        return {x = path[self.path_index_dest][1] * 8 + 4, y = path[self.path_index_dest][2] * 8}
    end

    local pos = bloon:_get_pos_from_path_index()
    bloon.x = pos.x
    bloon.y = pos.y

    bloon.type = flr(rnd(4)) + 1
    bloon.health = type_healths[bloon.type]

    bloon.flash_time = 0

    bloon.hover_seed = rnd(5)

    bloon.path_index_dest += 1

    bloon.update = function(self)
        self.flash_time = max(self.flash_time - 1, 0)

        local dest_pos = bloon:_get_pos_from_path_index()
        local dist = (dest_pos.x - self.x) ^ 2 + (dest_pos.y - self.y) ^ 2
        if dist <= 1 then
            self.path_index_dest += 1
            if self.path_index_dest > #path then return false end
            dest_pos = bloon:_get_pos_from_path_index()
            dist = (dest_pos.x - self.x) ^ 2 + (dest_pos.y - self.y) ^ 2
        end

        dist = sqrt(dist)

        self.x += (dest_pos.x - self.x) / dist * speed / 60
        self.y += (dest_pos.y - self.y) / dist * speed / 60

        return true
    end

    bloon.damage = function(self, amount)
        self.health -= amount
        bloon.flash_time = 7
    end

    bloon.get_reward = function(self)
        return type_reward[self.type]
    end

    bloon.draw = function(self)
        local s = 9 + self.type
        if self.flash_time > 0 then s = 26 end
        spr(s, self.x - 4, self.y - 4 + sin(time() + self.hover_seed) * 1)
    end

    add(bloons, bloon)
end

function create_particle(x, y)
    local part = {}
    part.x = x
    part.y = y
    part.velx = 0
    part.vely = 0
    part.color = 0
    part.size = 0
    part.lifetime = 0
    part.lifetime_max = 1

    part.update = function(self)
        self.x += self.velx / 60
        self.y += self.vely / 60
        self.lifetime -= 1
        return self.lifetime > 0
    end

    part.draw = function(self)
        local s = self.size * self.lifetime / self.lifetime_max
        circfill(self.x, self.y, s, self.color)
    end

    part.init_lifetime = function(self, time)
        self.lifetime = time
        self.lifetime_max = time
    end

    return part
end

function create_bloon_damage_particle()
    local final_grid = path[#path]
    local part = create_particle(final_grid[1] * 8 + 4, final_grid[2] * 8 + 4)

    part:init_lifetime(rnd(40) + 30)
    part.velx = rnd(80) - 40
    part.vely = rnd(80) - 40
    part.size = rnd(3) + 1
    part.color = flr(rnd(2)) + 8

    add(particles, part)
end