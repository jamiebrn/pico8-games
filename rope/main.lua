function _init()
    poke(0x5F2D, 1)

    a = create_anchor(40, 40)
    n1 = create_node(40, 47)
    n1:connect_to(a)
    n2 = create_node(40, 54)
    n2:connect_to(n1)
    n3 = create_node(40, 61)
    n3:connect_to(n2)
    n4 = create_node(40, 68)
    n4:connect_to(n3)
    n5 = create_node(40, 75)
    n5:connect_to(n4)
end

function _update60()
    n1:update()
    n2:update()
    n3:update()
    n4:update()
    n5:update()

    -- if btn(0) then a.x -= 1 end
    -- if btn(1) then a.x += 1 end
    -- if btn(2) then a.y -= 1 end
    -- if btn(3) then a.y += 1 end

    a.x = stat(32)
    a.y = stat(33)
end

function _draw()
    cls()
    n5:draw()
    n4:draw()
    n3:draw()
    n2:draw()
    n1:draw()
    a:draw()
end

function create_anchor(x, y)
    local anchor = {}
    anchor.x = x
    anchor.y = y

    anchor.draw = function(self)
        circfill(self.x, self.y, 2, 8)
    end
    
    return anchor
end

function create_node(x, y)
    local gravity = 200
    local connection_force = 16
    local connection_constraint = 2
    local velx_dampen = 0.92
    local vely_dampen = 0.9

    local node = {}
    node.x = x
    node.y = y
    node.velx = 0
    node.vely = 0

    node.connected = nil
    node.connected_len = nil

    node.connect_to = function(self, obj)
        self.connected = obj
        self.connected_len = sqrt((self.x - obj.x) ^ 2 + (self.y - obj.y) ^ 2)
    end

    node.update = function(self)
        self.x += self.velx / 60
        self.y += self.vely / 60
        self.vely += gravity / 60
        self.velx *= velx_dampen
        self.vely *= vely_dampen
        
        if not self.connected then return end
        
        local len = sqrt((self.x - self.connected.x) ^ 2 + (self.y - self.connected.y) ^ 2) - self.connected_len
        if len <= 0 then return end
        
        local extension = len / self.connected_len
        local a = atan2(self.connected.x - self.x, self.connected.y - self.y)
        
        if extension >= connection_constraint then
            local angle = atan2(self.x - self.connected.x, self.y - self.connected.y)
            self.x = self.connected.x + cos(angle) * self.connected_len * connection_constraint
            self.y = self.connected.y + sin(angle) * self.connected_len * connection_constraint
        end

        self.velx += cos(a) * extension ^ 1.2 * connection_force
        self.vely += sin(a) * extension ^ 1.2 * connection_force
    end

    node.draw = function(self)
        -- circfill(self.x, self.y, 2, 9)
        if self.connected then
            line(self.x, self.y, self.connected.x, self.connected.y, 9)
            local len = sqrt((self.x - self.connected.x) ^ 2 + (self.y - self.connected.y) ^ 2) - self.connected_len
            -- print(len, self.x, self.y, 7)
        end
    end

    return node
end