-- Local controller -Z ray against an authenticated panel's oriented quad.
local M = {}
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < math.huge
end
local function vec(v)
    return type(v) == 'table' and finite(v.x) and finite(v.y) and finite(v.z)
end
local function quat(q)
    if type(q) ~= 'table' or not finite(q.x) or not finite(q.y) or
       not finite(q.z) or not finite(q.w) then return nil end
    local n = math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
    if n < .00001 then return nil end
    return {x=q.x/n,y=q.y/n,z=q.z/n,w=q.w/n}
end
local function rotate(q,v)
    local x,y,z,w = q.x,q.y,q.z,q.w
    local tx,ty,tz = 2*(y*v.z-z*v.y),2*(z*v.x-x*v.z),2*(x*v.y-y*v.x)
    return {x=v.x+w*tx+y*tz-z*ty,
            y=v.y+w*ty+z*tx-x*tz,
            z=v.z+w*tz+x*ty-y*tx}
end

function M.intersect(ray,panel)
    if type(ray) ~= 'table' or type(panel) ~= 'table' or
       ray.tracked ~= true or ray.active ~= true or
       not vec(ray.position) or not vec(panel.center) or
       not finite(panel.width) or not finite(panel.height) or
       panel.width <= 0 or panel.height <= 0 then return nil end
    local q, pq = quat(ray.rotation), quat(panel.rotation)
    if not q or not pq then return nil end
    local inverse = {x=-pq.x,y=-pq.y,z=-pq.z,w=pq.w}
    local relative = {x=ray.position.x-panel.center.x,
                      y=ray.position.y-panel.center.y,
                      z=ray.position.z-panel.center.z}
    local local_origin = rotate(inverse,relative)
    local direction = rotate(inverse,rotate(q,{x=0,y=0,z=-1}))
    if direction.z >= -.00001 then return nil end
    local distance = -local_origin.z / direction.z
    if distance <= 0 or not finite(distance) then return nil end
    local x = local_origin.x + direction.x*distance
    local y = local_origin.y + direction.y*distance
    if math.abs(x) > panel.width/2 or math.abs(y) > panel.height/2 then return nil end
    return {x=.5+x/panel.width, y=.5-y/panel.height, distance=distance}
end

return M
