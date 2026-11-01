-- Pure, fail-closed policy for provenance-tagged XR controller samples.
-- This module deliberately does not create or authenticate tracking samples.
local M = {}

local function valid_number(x)
    return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge
end

function M.new()
    local gate = {last = nil, armed = false}

    function gate:reset()
        self.last = nil
        self.armed = false
    end

    function gate:allow(s, now, owner, hand)
        local h = type(s) == 'table' and type(s.hands) == 'table' and s.hands[hand] or nil
        if type(s) ~= 'table' or s.source ~= 'openxr' or s.trusted ~= true or
           s.fresh ~= true or s.focused ~= true or s.foreground ~= true or
           type(s.process_nonce) ~= 'string' or #s.process_nonce == 0 or
           not valid_number(s.epoch) or not valid_number(s.sequence) or
           not valid_number(s.clock) or not valid_number(now) or
           s.owner ~= owner or not owner or (hand ~= 'left' and hand ~= 'right') or
           type(h) ~= 'table' or h.tracked ~= true or h.active ~= true or
           now < s.clock or now - s.clock > .075 then
            self:reset()
            return false, 'untrusted_or_stale'
        end

        local last = self.last
        if last and (last.nonce ~= s.process_nonce or last.epoch ~= s.epoch or
                     last.owner ~= owner or last.hand ~= hand) then
            self:reset()
            last = nil
        end
        if last and (s.sequence <= last.sequence or s.clock <= last.clock) then
            self:reset()
            return false, 'replay_or_clock_regression'
        end
        self.last = {nonce=s.process_nonce, epoch=s.epoch, sequence=s.sequence,
                     clock=s.clock, owner=owner, hand=hand}
        if not last then
            self.armed = false
            return false, 'warming'
        end
        self.armed = true
        return true, 'armed'
    end

    return gate
end

return M
