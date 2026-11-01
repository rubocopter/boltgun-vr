-- Geometry only: no collision tracing, target selection or damage calls.
local M = {}
local function finite(v)
    return type(v) == 'number' and v == v and math.abs(v) < math.huge
end
local function valid_vec(v)
    return type(v) == 'table' and finite(v.x) and finite(v.y) and finite(v.z)
end
local function valid_quat(q)
    return type(q) == 'table' and finite(q.x) and finite(q.y) and
           finite(q.z) and finite(q.w) and
           q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w > .00001
end
local function normalize(q)
    local n = math.sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w)
    return {x=q.x/n,y=q.y/n,z=q.z/n,w=q.w/n}
end
local function rotate(q,v)
    local tx,ty,tz=2*(q.y*v.z-q.z*v.y),2*(q.z*v.x-q.x*v.z),2*(q.x*v.y-q.y*v.x)
    return {x=v.x+q.w*tx+q.y*tz-q.z*ty,
            y=v.y+q.w*ty+q.z*tx-q.x*tz,
            z=v.z+q.w*tz+q.x*ty-q.y*tx}
end
local function add(a,b)
    return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z}
end
local function sub(a,b)
    return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}
end
local function mul(v,s)
    return {x=v.x*s,y=v.y*s,z=v.z*s}
end
local function dist(a,b)
    local v=sub(a,b)
    return math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z)
end
local function at(p,v)
    return add(p.position,rotate(normalize(p.rotation),v))
end

function M.generate(previous,current,base,tip,radius,dt)
    if type(previous) ~= 'table' or type(current) ~= 'table' or
       not valid_vec(previous.position) or not valid_vec(current.position) or
       not valid_quat(previous.rotation) or not valid_quat(current.rotation) or
       not valid_vec(base) or not valid_vec(tip) or not finite(radius) or
       radius <= 0 or radius > 20 or not finite(dt) or dt <= 0 or dt > .1 then
        return nil, 'invalid'
    end
    local pbase,ptip,cbase,ctip=at(previous,base),at(previous,tip),at(current,base),at(current,tip)
    local travel=math.max(dist(pbase,cbase),dist(ptip,ctip))
    local qa,qb=normalize(previous.rotation),normalize(current.rotation)
    local dot=qa.x*qb.x+qa.y*qb.y+qa.z*qb.z+qa.w*qb.w
    local degrees=2*math.deg(math.acos(math.min(1,math.abs(dot))))
    if travel > 50 or travel/dt > 1500 or degrees > 100 then return nil,'discontinuity' end
    local blade_length=dist(base,tip)
    if blade_length < .01 or blade_length > 200 then return nil,'invalid' end
    local time_steps=math.max(2,math.ceil(travel/math.max(radius,1))+1,
                              math.ceil(degrees/8)+1)
    local blade_steps=math.max(1,math.ceil(blade_length/math.max(radius*1.5,1)))
    if time_steps*blade_steps > 1200 then return nil,'budget' end
    local segments={}
    if dot < 0 then qb={x=-qb.x,y=-qb.y,z=-qb.z,w=-qb.w} end
    for t=0,time_steps-1 do
        local alpha=t/(time_steps-1)
        local blend=normalize({x=qa.x+(qb.x-qa.x)*alpha,
                               y=qa.y+(qb.y-qa.y)*alpha,
                               z=qa.z+(qb.z-qa.z)*alpha,
                               w=qa.w+(qb.w-qa.w)*alpha})
        local location=add(previous.position,mul(sub(current.position,previous.position),alpha))
        local world_base=add(location,rotate(blend,base))
        local world_tip=add(location,rotate(blend,tip))
        local delta=sub(world_tip,world_base)
        for j=0,blade_steps-1 do
            segments[#segments+1]={from=add(world_base,mul(delta,j/blade_steps)),
                                   to=add(world_base,mul(delta,(j+1)/blade_steps)),
                                   radius=radius}
        end
    end
    return segments,nil
end

return M
