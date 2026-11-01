-- Pure eligibility policy for a future engine-confirmed chainsword contact path.
-- The calling runtime MUST establish tracking provenance and actual collisions.
-- A caller's `tracked` or contact `verified` flag is not proof by itself.
-- This file is not installed into UEVR and never invokes game damage or haptics.
local M = {}

local function finite(x)
    return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge
end

function M.new()
    local policy = {owner = nil, time = nil, moving = 0, hits = {}, cooldown = {}}

    function policy:reset()
        self.owner, self.time, self.moving = nil, nil, 0
        self.hits, self.cooldown = {}, {}
    end

    function policy:step(frame, contact)
        local f = frame
        local owner = type(f) == 'table' and f.owner or nil
        local now = type(f) == 'table' and f.now or nil
        local valid = type(owner) == 'string' and #owner > 0 and
            finite(now) and finite(f.dt) and f.dt > 0 and f.dt <= .1 and
            finite(f.linear_cm_s) and f.linear_cm_s >= 0 and f.linear_cm_s <= 1500 and
            finite(f.angular_deg_s) and f.angular_deg_s >= 0 and f.angular_deg_s <= 1800 and
            f.tracked == true and f.focused == true and f.foreground == true and
            f.held == true and f.blade_owned == true and f.ui == false and
            f.sweep_valid == true

        -- Preserve per-target cooldown through brief trigger/focus loss in the
        -- same pawn, but never preserve a strike, pose or consecutive motion.
        if not valid then
            if owner ~= self.owner then self:reset() end
            self.time, self.moving, self.hits = nil, 0, {}
            return nil
        end
        if self.owner ~= owner then self:reset(); self.owner = owner end
        if self.time and (now <= self.time or now - self.time > .12) then
            self.moving, self.hits = 0, {}
            if now <= self.time then
                self.time = nil
                return nil
            end
        end
        self.time = now
        if f.linear_cm_s < 75 and f.angular_deg_s < 160 then
            self.moving, self.hits = 0, {}
            return nil
        end
        self.moving = math.min(2, self.moving + 1)
        if self.moving < 2 or type(contact) ~= 'table' or
           contact.verified ~= true or contact.enemy ~= true or
           contact.blocking ~= true or type(contact.target) ~= 'string' or
           #contact.target == 0 or contact.target == owner then return nil end

        local id = contact.target
        if self.hits[id] or (self.cooldown[id] and now - self.cooldown[id] < .35) then
            return nil
        end
        self.hits[id], self.cooldown[id] = true, now
        -- An eligible contact is NOT a damage event. The future engine adapter
        -- must independently validate its target before any gameplay call.
        return {target = id, impact = true}
    end

    return policy
end

return M
