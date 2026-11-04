-- Physical contact runtime. Capture displayed poses after attachment; damage only on engine tick.
local Sweep=require('boltgun_blade_sweep')
local Engine=require('boltgun_chainsword_engine')
local M={}
local finite=Engine.finite
local function pose(component)
    local t=component:K2_GetComponentToWorld();local p,q=t.Translation,t.Rotation
    local result={position={x=p.X,y=p.Y,z=p.Z},rotation={x=q.X,y=q.Y,z=q.Z,w=q.W}}
    for _,v in pairs(result.position) do assert(finite(v),'Invalid blade position') end
    local n=0;for _,v in pairs(result.rotation) do assert(finite(v),'Invalid blade rotation');n=n+v*v end
    assert(math.abs(n-1)<.01,'Invalid blade quaternion')
    return result
end
function M.new(uevr)
    local vr=uevr.params.vr
    local engine,previous,captured,scope,trigger
    local tick,clock=0,0
    local cooldown={}
    local s={stopped=false}
    local samples,queries,hits,damage=0,0,0,0
    local phase,diagnostic_at,diagnostic_windows='initializing',6,0
    function s:reset_pose() previous=nil;captured=nil end
    local function ready(pawn,component,enabled)
        phase='gameplay-or-vr'
        if not enabled or not vr.is_runtime_ready() or not vr.is_openxr() or not vr.is_hmd_active() or
            not vr.is_using_controllers() or not vr.is_aim_allowed() or uevr.params.functions.is_drawing_ui() then return nil end
        phase='left-trigger'
        trigger=trigger or vr.get_action_handle('/actions/default/in/Trigger')
        if trigger==nil or trigger==0 then return nil end
        local source=vr.get_left_joystick_source()
        if source==nil or vr.is_action_active(trigger,source)~=true then return nil end -- OpenXR source 0 is valid.
        phase='controller-pose'
        local index=vr.get_left_controller_index()
        if not finite(index) or index<0 or index>63 or index%1~=0 then return nil end
        -- Read the actual UEVR device matrix, never caller-supplied tracked flags.
        -- Lua exposes no per-device tracking-valid/focus bit; see the validation boundaries.
        local matrix=vr:get_transform(index)
        for i=0,3 do
            local v=matrix[i]
            if not v or not finite(v.x) or not finite(v.y) or not finite(v.z) then return nil end
            if i<3 then
                local n=v.x*v.x+v.y*v.y+v.z*v.z
                if math.abs(n-1)>.05 then return nil end
            elseif math.abs(v.x)>20 or math.abs(v.y)>20 or math.abs(v.z)>20 then return nil end
        end
        phase='owned-context'
        if not engine then engine=Engine.new(uevr) end
        return engine:context(pawn,component)
    end
    local function guarded(fn,...)
        if s.stopped then return end
        local ok,err=pcall(fn,...)
        if not ok then
            s.stopped=true;s:reset_pose()
            uevr.params.functions.log_info('[Boltgun Chainsword contact] Disabled: '..tostring(err))
        end
    end
    function s:capture(pawn,component,enabled,scale,view_index)
        if view_index~=1 then return end -- Fixed UEVR first-eye attachment branch.
        guarded(function()
            local c=ready(pawn,component,enabled)
            if not c or not finite(scale) or scale<.3 or scale>1.5 then self:reset_pose();return end
            local p=pose(component)
            local origin=pawn:K2_GetActorLocation()
            local dx,dy,dz=p.position.x-origin.X,p.position.y-origin.Y,p.position.z-origin.Z
            if not finite(dx+dy+dz) or dx*dx+dy*dy+dz*dz>250*250 then self:reset_pose();return end
            local t=component:K2_GetComponentToWorld();local z=t.Scale3D
            if not z or not finite(z.X) or not finite(z.Y) or not finite(z.Z) or
                math.abs(z.X-scale)>.001 or math.abs(z.Y-scale)>.001 or math.abs(z.Z-scale)>.001 then
                self:reset_pose();return
            end
            captured={pose=p,key=c.key,scale=scale,tick=tick}
            samples=samples+1
        end)
    end
    function s:step(pawn,component,enabled,dt,scale)
        guarded(function()
            tick=tick+1
            if not finite(dt) or dt<=0 or dt>.1 then self:reset_pose();return end
            clock=clock+dt
            local c=ready(pawn,component,enabled)
            local sample=captured;captured=nil
            if not c then previous=nil;return end
            phase='fresh-display-sample'
            if not sample or sample.tick~=tick-1 or sample.key~=c.key or sample.scale~=scale then
                previous=nil;return
            end
            -- Rebuilding the display component must not bypass the weapon's cooldown.
            if scope~=c.damage_key then scope=c.damage_key;cooldown={};previous=nil end
            local current=sample.pose
            phase='second-display-sample'
            if not previous or previous.key~=c.key or previous.scale~=scale then
                previous={pose=current,key=c.key,scale=scale};return
            end
            -- Cutting edge of the maintained 95cm Kaiser-E mesh, excluding grip/motor housing.
            local base,tip={x=5*scale,y=0,z=27*scale},{x=5*scale,y=0,z=76*scale}
            local segments=Sweep.generate(previous.pose,current,base,tip,3*scale,dt)
            previous=nil
            if not segments or #segments>256 then return end
            local contacts={};local frame_queries=0
            local function cast(a,b,r)
                frame_queries=frame_queries+1;queries=queries+1
                assert(frame_queries<=512,'Blade query budget exhausted')
                return engine:cast(c,a,b,r)
            end
            phase='occlusion'
            -- Collect before mutating: any blocking world geometry cancels this frame.
            for _,segment in ipairs(segments) do
                for _,hit in ipairs(cast(segment.from,segment.to,segment.radius)) do
                    if hit.wall then return end
                    contacts[hit.key]=contacts[hit.key] or hit
                end
            end
            local origin=pawn:K2_GetActorLocation()
            origin={x=origin.X,y=origin.Y,z=origin.Z}
            -- Pawn-to-contact occlusion also prevents an already inserted blade cutting through a wall.
            for _,hit in pairs(contacts) do
                for _,block in ipairs(cast(origin,hit.point,1)) do if block.wall then return end end
            end
            previous={pose=current,key=c.key,scale=scale}
            phase='no-contact-or-cooldown'
            for id,at in pairs(cooldown) do if clock-at>10 then cooldown[id]=nil end end
            for id,hit in pairs(contacts) do
                hits=hits+1
                if not cooldown[id] or clock-cooldown[id]>=.5 then
                    cooldown[id]=clock -- Reserve before native call, including rejected/dead targets.
                    if engine:apply(c,hit) then damage=damage+1;phase='damage-applied' end
                end
            end
        end)
        if not self.stopped and clock>=diagnostic_at and diagnostic_windows<8 then
            diagnostic_at=clock+6;diagnostic_windows=diagnostic_windows+1
            uevr.params.functions.log_info(string.format(
                '[Boltgun Chainsword contact] samples=%d sweeps=%d contacts=%d damage=%d state=%s',
                samples,queries,hits,damage,phase))
        end
    end
    function s:stop() self.stopped=true;self:reset_pose() end
    return s
end
return M
