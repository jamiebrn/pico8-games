-- todo
-- menu

function _init()
    poke(0x5f2d, 1)

    game_state = 2 -- 0: main menu, 1: level select, 2: in game

    monkey_types = {
        dart_monkey = {name = {"dart", "monkey"}, range = 20, damage = 1, sprite = 2, cost = 30,
            upgrades_one = {{name = "glasses", range = 30, sprite = 51, cost = 30}},
            upgrades_two = {{name = "sharpening", damage = 2, cost = 40}}},
        ninja_monkey = {name = {"ninja", "monkey"}, range = 25, damage = 1, sprite = 34, cost = 40,
            upgrades_one = {},
            upgrades_two = {}}
    }

    buy_menu_choices = {
        "dart_monkey", "ninja_monkey"
    }
    buy_menu_x_offset = 128
    buy_menu_x_offset_dest = 128
    buy_menu_width = 30
    buy_menu_height = 60

    darts = {}
    monkeys = {}
    bloons = {}

    particles = {}

    maps = {
        monkey_meadow = {name = "monkey meadow",
            offset = {0, 0}, path = {{-1, 6}, {8, 6}, {8, 3}, {5, 3}, {5, 12}, {2, 12}, {2, 9}, {11, 9}, {11, 6}, {13, 6}, {13, 12}, {7, 12}, {7, 16}},
            rounds = {{{[1]=10}, 50}, {{[1]=10}, 40}, {{[1]=12}, 35}, {{[1]=10, [2]=3}, 40}, {{[1]=14, [2]=5}, 40}}
        }
    }

    placing_monkey = nil
    selected_monkey = nil
    selected_monkey_radius_anim = 0

    money = 100
    health = 50
    round = 5
    round_intermission = true
    won = false

    current_map = maps["monkey_meadow"]
    current_round = nil
    load_round()

    left_mouse = false
    left_mouse_last = false
    right_mouse = false
    right_mouse_last = false

    bloon_spawn_cooldown = 0
end

function left_mouse_press()
    return left_mouse and not left_mouse_last
end

function left_mouse_consume()
    left_mouse_last = left_mouse
end

function right_mouse_press()
    return right_mouse and not right_mouse_last
end

function print_outln(s, x, y, c, o)
    print(s, x - 1, y, o)
    print(s, x + 1, y, o)
    print(s, x, y - 1, o)
    print(s, x, y + 1, o)
    print(s, x, y, c)
end

function _update60()
    left_mouse_last = left_mouse
    left_mouse = stat(34) & 1 == 1
    right_mouse_last = right_mouse
    right_mouse = stat(34) & 2 == 2

    if game_state == 0 then update_main_menu()
    elseif game_state == 1 then update_level_select()
    elseif game_state == 2 then update_in_game()
    end
end

function update_main_menu()

end

function update_level_select()

end

function update_in_game()
    bloon_spawn_cooldown = max(bloon_spawn_cooldown - 1, 0)
    if not round_intermission and bloon_spawn_cooldown <= 0 and not tbl_empty(current_round[1]) then
        bloon_spawn_cooldown = current_round[2]
        -- choose bloon
        local total = 0
        for i, blooncount in pairs(current_round[1]) do
            total += blooncount
        end
        local cumulative = 0
        local chosen = flr(rnd(total)) + 1
        for bloontype, blooncount in pairs(current_round[1]) do
            cumulative += blooncount
            if chosen <= cumulative then
                create_bloon(bloontype)
                current_round[1][bloontype] -= 1
                if current_round[1][bloontype] <= 0 then
                    current_round[1][bloontype] = nil
                end
                break
            end
        end
    end

    for i, bloon in ipairs(bloons) do
        if not bloon:update() then
            deli(bloons, i)
            health -= 1
            for j = 0, flr(rnd(6)) + 3 do
                create_bloon_damage_particle()
            end
            test_round_end()
        end

        -- test collisions with darts
        for j, dart in ipairs(darts) do
            local sqdist = (dart.x - bloon.x) ^ 2 + (dart.y - bloon.y) ^ 2
            if sqdist <= 13 then
                bloon:damage(dart.damage)
                deli(darts, j)
                if bloon.health <= 0 then
                    deli(bloons, i)
                    money += flr(rnd(bloon:get_reward())) + 1
                    test_round_end()
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

    for i, monkey in ipairs(monkeys) do
        if monkey.sold then
            deli(monkeys, i)
        else
            monkey:update()
        end
    end

    buy_menu_x_offset = lerp(buy_menu_x_offset, buy_menu_x_offset_dest, 0.1)
    if not won then
        if left_mouse_press() and rect_point_test(buy_menu_x_offset - 5, 0, buy_menu_x_offset, 8, stat(32), stat(33)) then
            if buy_menu_x_offset_dest < 128 then
                buy_menu_x_offset_dest = 128
            else
                buy_menu_x_offset_dest = 128 - buy_menu_width
            end
        end

        if selected_monkey then
            selected_monkey_radius_anim = lerp(selected_monkey_radius_anim, selected_monkey:get_range(), 0.6)
        end

        if left_mouse_press() then
            local monkey_hovering = get_monkey_hovered()
            if monkey_hovering then
                selected_monkey = monkey_hovering
                selected_monkey_radius_anim = 0
                buy_menu_x_offset_dest = 128 - buy_menu_width
            elseif selected_monkey and not rect_point_test(buy_menu_x_offset, 0, buy_menu_x_offset + buy_menu_width, buy_menu_height, stat(32), stat(33)) then
                selected_monkey = nil
                buy_menu_x_offset_dest = 128
                left_mouse_consume()
            end
        end

        if right_mouse_press() and placing_monkey then
            placing_monkey = nil
        end

        if left_mouse_press() and placing_monkey and can_place_monkey_at_mouse() then
            add(monkeys, create_monkey(stat(32), stat(33), placing_monkey))
            money -= placing_monkey.cost
            placing_monkey = nil
        end
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

    if game_state == 0 then draw_main_menu()
    elseif game_state == 1 then draw_level_select()
    elseif game_state == 2 then draw_in_game()
    end

    spr(1, stat(32), stat(33)) -- cursor
end

function draw_main_menu()

end

function draw_level_select()

end

function draw_in_game()
    local map_offset = current_map["offset"]
    map(map_offset[1], map_offset[2], 0, 0, 16, 16)

    if selected_monkey then
        selected_monkey:draw_range(selected_monkey_radius_anim)
    end

    if placing_monkey then
        local c1 = 12
        local c2 = 1
        if not can_place_monkey_at_mouse() then
            c1 = 8
            c2 = 2
        end
        fillp(0b1000011101110111.1)
        circfill(stat(32), stat(33), placing_monkey.range, c2)
        fillp()
        circ(stat(32), stat(33), placing_monkey.range, c1)
        spr(placing_monkey.sprite + 6, stat(32) - 4, stat(33) - 4)
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

    -- buy menu
    local s = rect_point_test(buy_menu_x_offset - 5, 0, buy_menu_x_offset, 8, stat(32), stat(33)) and 33 or 32
    spr(s, buy_menu_x_offset - 8, 0)
    spr(48, buy_menu_x_offset - 6, 1, 1, 1, buy_menu_x_offset_dest < 128)
    if buy_menu_x_offset < 128 then
        rectfill(buy_menu_x_offset, 0, buy_menu_x_offset + buy_menu_width, buy_menu_height, 1)

        if not selected_monkey then
            -- purchasing
            for i, monkey_name in ipairs(buy_menu_choices) do
                local monkey = monkey_types[monkey_name]

                if rect_point_test(buy_menu_x_offset, (i - 1) * 10, buy_menu_x_offset + buy_menu_width, i * 10 - 1, stat(32), stat(33)) then
                    rectfill(buy_menu_x_offset, (i - 1) * 10, buy_menu_x_offset + buy_menu_width, i * 10 - 3, 13)
                    if left_mouse_press() and money >= monkey.cost then
                        start_monkey_placement(monkey_name)
                    end
                end

                spr(monkey.sprite + 6, buy_menu_x_offset + 2, (i - 1) * 10)
                print("$" .. monkey.cost, buy_menu_x_offset + 11, (i - 1) * 10 + 1, money >= monkey.cost and 7 or 8)
            end
        else
            -- upgrading
            local i = 0
            for name in all(selected_monkey.type_data.name) do
                print(name, buy_menu_x_offset + buy_menu_width / 2 - #name * 2, 2 + i, 7)
                i += 7
            end
            i += 2
            spr(selected_monkey.type_data.sprite + 6, buy_menu_x_offset + buy_menu_width / 2 - 4, i)
            i += 10

            if #selected_monkey.type_data.upgrades_one <= selected_monkey.upgrade_one_amount then
                print("max", buy_menu_x_offset + 4, i + 2, 7)
            else
                if rect_point_test(buy_menu_x_offset, i, buy_menu_x_offset + buy_menu_width, i + 8, stat(32), stat(33)) then
                    rectfill(buy_menu_x_offset, i, buy_menu_x_offset + buy_menu_width, i + 8, 13)
                    if left_mouse_press() and money >= selected_monkey.type_data.upgrades_one[selected_monkey.upgrade_one_amount + 1].cost then
                        money -= selected_monkey.type_data.upgrades_one[selected_monkey.upgrade_one_amount + 1].cost
                        selected_monkey:upgrade_one_apply()
                    end
                end

                local cost = selected_monkey.type_data.upgrades_one[min(selected_monkey.upgrade_one_amount + 1, #selected_monkey.type_data.upgrades_one)].cost
                print(selected_monkey.type_data.upgrades_one[min(selected_monkey.upgrade_one_amount + 1, #selected_monkey.type_data.upgrades_one)].name,
                    buy_menu_x_offset + 4, i + 2, money >= cost and 7 or 8)
                print_outln("$" .. cost, buy_menu_x_offset - #tostr("$" .. cost) * 4 - 2, i + 2, money >= cost and 7 or 8, 1)
            end
            i += 10

            if #selected_monkey.type_data.upgrades_two <= selected_monkey.upgrade_two_amount then
                print("max", buy_menu_x_offset + 4, i + 2, 7)
            else
                if rect_point_test(buy_menu_x_offset, i, buy_menu_x_offset + buy_menu_width, i + 8, stat(32), stat(33)) then
                    rectfill(buy_menu_x_offset, i, buy_menu_x_offset + buy_menu_width, i + 8, 13)
                    if left_mouse_press() and money >= selected_monkey.type_data.upgrades_two[selected_monkey.upgrade_two_amount + 1].cost then
                        money -= selected_monkey.type_data.upgrades_two[selected_monkey.upgrade_two_amount + 1].cost
                        selected_monkey:upgrade_two_apply()
                    end
                end

                local cost = selected_monkey.type_data.upgrades_two[min(selected_monkey.upgrade_two_amount + 1, #selected_monkey.type_data.upgrades_two)].cost
                print(selected_monkey.type_data.upgrades_two[min(selected_monkey.upgrade_two_amount + 1, #selected_monkey.type_data.upgrades_two)].name,
                    buy_menu_x_offset + 4, i + 2, money >= cost and 7 or 8)
                print_outln("$" .. cost, buy_menu_x_offset - #tostr("$" .. cost) * 4 - 2, i + 2, money >= cost and 7 or 8, 1)
            end
            i += 12

            if rect_point_test(buy_menu_x_offset, i, buy_menu_x_offset + buy_menu_width, i + 8, stat(32), stat(33)) then
                rectfill(buy_menu_x_offset, i, buy_menu_x_offset + buy_menu_width, i + 8, 13)
                if left_mouse_press() then
                    -- sell tower
                    selected_monkey.sold = true
                    money += selected_monkey.sell_price
                    selected_monkey = nil
                end
            end

            if selected_monkey then
                print("sell", buy_menu_x_offset + 4, i + 2, 9)
                print_outln("$" .. selected_monkey.sell_price, buy_menu_x_offset - #tostr("$" .. selected_monkey.sell_price) * 4 - 2, i + 2, 9, 1)
            end
        end
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

    -- round
    print("round " .. round, 2, 24, 1)
    print("round " .. round, 1, 24, 7)

    if round_intermission and not won then
        local hovering = rect_point_test(1, 31, 4, 39, stat(32), stat(33))
        spr(hovering and 50 or 49, 1, 31)
        if hovering and left_mouse_press() then
            round_intermission = false
        end
    end

    if won then
        rectfill(22, 35, 106, 93, 1)
        print("congratulations!", 33, 43 + sin(time()) * 3, 5)
        print("congratulations!", 32, 43 + sin(time() + 0.2) * 3, 12)
        print("you have completed", 29, 59, 5)
        print("you have completed", 28, 58, 12)
        print(current_map["name"], 64 - #current_map["name"] * 2 + 1, 69, 5)
        print(current_map["name"], 64 - #current_map["name"] * 2, 68, 12)
    end
end

function can_place_monkey_at_mouse()
    if fget(mget(flr(stat(32) / 8), flr(stat(33) / 8)), 0) then return false end
    for monkey in all(monkeys) do
        local dist = (stat(32) - monkey.x) ^ 2 + (stat(33) - monkey.y) ^ 2
        if dist < 60 then return false end
    end
    return true
end

function get_monkey_hovered()
    for monkey in all(monkeys) do
        local dist = (stat(32) - monkey.x) ^ 2 + (stat(33) - monkey.y) ^ 2
        if dist < 16 then return monkey end
    end
    return nil
end

function test_round_end()
    if #bloons == 0 and tbl_empty(current_round[1]) then
        round_intermission = true
        if #current_map["rounds"] > round then
            round += 1
            load_round()
            bloon_spawn_cooldown = 0
        else
            won = true
            buy_menu_x_offset_dest = 128
            placing_monkey = nil
        end
    end
end

function tbl_empty(t)
    for _ in pairs(t) do return false end
    return true
end

function tbl_len(t)
    local i = 0
    for _ in pairs(t) do i += 1 end
    return i
end

function rect_point_test(x1, y1, x2, y2, x, y)
    return x1 <= x and y1 <= y and x2 >= x and y2 >= y
end

function rotate_vec(x, y, a)
    local vec = {}
    vec.x = x * cos(a) - y * sin(a)
    vec.y = x * sin(a) + y * cos(a)
    return vec
end

function lerp(a, b, t)
    if abs(b - a) < 0.5 then return b end
    return (b - a) * t + a
end

function load_round()
    local round_data = current_map["rounds"][round]
    round_copy = {{}, round_data[2]}
    for bloontype, blooncount in pairs(round_data[1]) do
        round_copy[1][bloontype] = blooncount
    end
    current_round = round_copy
end

function create_dart(x, y, dir, damage)
    local dart = {}
    dart.x = x
    dart.y = y
    dart.dir = dir
    dart.damage = damage

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

function start_monkey_placement(monkey_name)
    if placing_monkey then return end
    placing_monkey = monkey_types[monkey_name]
    selected_monkey = nil
    buy_menu_x_offset_dest = 128
end

function create_monkey(x, y, monkey_data)
    local throw_cooldown_max = 50
    
    local monkey = {}
    monkey.x = x
    monkey.y = y
    monkey.dir = 0
    monkey.type_data = monkey_data

    monkey.sell_price = monkey_data.cost / 2
    monkey.sold = false

    monkey.upgrade_one_amount = 0
    monkey.upgrade_two_amount = 0

    monkey.throw_cooldown = 0

    monkey.throw_progress = 0
    monkey.throw_target = nil

    monkey.throw = function(self, xtarget, ytarget)
        if self.throw_target then return end
        self.throw_progress = 0
        self.throw_target = {x = xtarget, y = ytarget}
    end

    monkey._get_closest_bloon_pos = function(self)
        local shortest = self:get_range() ^ 2 + 1
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
                create_dart(self.x + hand.x, self.y + hand.y, angle, self:_get_dart_damage())
                self.throw_target = nil
                self.throw_progress = 0
            end
        end
    end

    monkey._get_hand_local_pos = function(self)
        return rotate_vec(2 + ease_in_back(self.throw_progress) * 3, 5, self.dir)
    end

    monkey.get_range = function(self)
        return self:_get_highest_upgrade_stat("range")
    end

    monkey._get_dart_damage = function(self)
        return self:_get_highest_upgrade_stat("damage")
    end

    monkey._get_highest_upgrade_stat = function(self, stat_str)
        local stat = self.type_data[stat_str]
        if self.upgrade_one_amount > 0 then
            local stat_upgrade = self.type_data.upgrades_one[self.upgrade_one_amount][stat_str]
            if stat_upgrade then stat = max(stat, stat_upgrade) end
        end
        if self.upgrade_two_amount > 0 then
            local stat_upgrade = self.type_data.upgrades_two[self.upgrade_two_amount][stat_str]
            if stat_upgrade then stat = max(stat, stat_upgrade) end
        end
        return stat
    end

    monkey.upgrade_one_apply = function(self)
        self.upgrade_one_amount += 1
        self.sell_price += self.type_data.upgrades_one[self.upgrade_one_amount].cost / 2
    end

    monkey.upgrade_two_apply = function(self)
        self.upgrade_two_amount += 1
        self.sell_price += self.type_data.upgrades_two[self.upgrade_two_amount].cost / 2
    end

    monkey.draw = function(self)
        local s_offset = min(flr((1 - self.dir) * 8 + 0.5), 7)
        spr(self.type_data.sprite + s_offset, self.x - 4, self.y - 4)

        local hand = self:_get_hand_local_pos()
        local dart_top = rotate_vec(4 + ease_in_back(self.throw_progress) * 3, 5, self.dir)
        local dart_bottom = rotate_vec(1 + ease_in_back(self.throw_progress) * 3, 5, self.dir)
        line(self.x + dart_top.x, y + dart_top.y, self.x + dart_bottom.x, y + dart_bottom.y, 5)
        circfill(self.x + hand.x, y + hand.y, 1, 4)

        if self.upgrade_one_amount > 0 then
            if self.type_data.upgrades_one[self.upgrade_one_amount]["sprite"] then
                spr(self.type_data.upgrades_one[self.upgrade_one_amount].sprite + s_offset, self.x - 4, self.y - 4)
            end
        end

        if self.upgrade_two_amount > 0 then
            if self.type_data.upgrades_two[self.upgrade_two_amount]["sprite"] then
                spr(self.type_data.upgrades_two[self.upgrade_two_amount].sprite + s_offset, self.x - 4, self.y - 4)
            end
        end
    end

    monkey.draw_range = function(self, radius_override)
        local radius = radius_override or self.type_data.range
        fillp(0b0111111111111110.1)
        circfill(self.x, self.y, radius, 5)
        fillp()
        circ(self.x, self.y, radius, 6)
    end

    return monkey
end

function create_bloon(type)
    local speed = 20
    local type_healths = {1, 2, 4, 7}
    local type_reward = {2, 4, 6, 12}

    local bloon = {}
    bloon.path_index_dest = 1

    bloon._get_pos_from_path_index = function(self)
        return {x = current_map["path"][self.path_index_dest][1] * 8 + 4, y = current_map["path"][self.path_index_dest][2] * 8}
    end

    local pos = bloon:_get_pos_from_path_index()
    bloon.x = pos.x
    bloon.y = pos.y

    bloon.type = type
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
            if self.path_index_dest > #current_map["path"] then return false end
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
    local path = current_map["path"]
    local final_grid = path[#path]
    local part = create_particle(final_grid[1] * 8 + 4, final_grid[2] * 8 + 4)

    part:init_lifetime(rnd(40) + 30)
    part.velx = rnd(80) - 40
    part.vely = rnd(80) - 40
    part.size = rnd(3) + 1
    part.color = flr(rnd(2)) + 8

    add(particles, part)
end