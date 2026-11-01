-- Independent trigger policy. The caller must authenticate the frontend and input owner.
local M = {}
local A_BUTTON = 4096

function M.new()
    local policy = {released=false, held=false, drain=false}

    function policy:step(context, raw_rt, buttons)
        local result = {rt=raw_rt, buttons=buttons, accepted=false}
        if type(context) ~= 'table' or type(raw_rt) ~= 'number' or
           type(buttons) ~= 'number' or context.source_owned ~= true then
            return result
        end
        local valid = context.mode == 'frontend' and context.tracking_ok == true and
                      context.focused == true and context.foreground == true
        if not valid then
            if self.held or self.drain then
                self.drain = raw_rt > 32
                result.rt = 0
                self.held = false
                self.released = false
            else
                self.released = false
            end
            return result
        end
        if self.drain then
            result.rt = 0
            if raw_rt <= 32 then self.drain = false end
            self.released = false
            return result
        end
        if raw_rt <= 32 then
            self.released = true
            self.held = false
            return result
        end
        if raw_rt >= 166 and self.released then
            result.rt = 0
            if not self.held then
                result.buttons = buttons | A_BUTTON
                result.accepted = true
            end
            self.held = true
        end
        return result
    end

    return policy
end

return M
