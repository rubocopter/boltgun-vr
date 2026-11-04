-- World reticle sampled synchronously from the production projectile policy.
-- All UObject access, traces and visibility changes run on post-engine tick.
local M={range_cm=10000}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<1e12 end
local function vec(v) return v and finite(v.x) and finite(v.y) and finite(v.z) end
local function add(a,b,k) return {x=a.x+b.x*k,y=a.y+b.y*k,z=a.z+b.z*k} end
function M.ray(t)
    if not t then return nil end
    local p,q=t.Translation,t.Rotation
    if not p or not q then return nil end
    local origin={x=p.X,y=p.Y,z=p.Z}
    local x,y,z,w=q.X,q.Y,q.Z,q.W
    if not vec(origin) or not finite(x) or not finite(y) or not finite(z) or not finite(w) then return nil end
    local n=x*x+y*y+z*z+w*w
    if math.abs(n-1)>.01 then return nil end
    local direction={x=1-2*(y*y+z*z)/n,y=2*(x*y+w*z)/n,z=2*(x*z-w*y)/n}
    return {origin=origin,direction=direction,finish=add(origin,direction,M.range_cm)}
end
function M.marker(ray,hit,eye)
    if not ray or not vec(eye) then return nil end
    local point=hit and hit.point or ray.finish
    if not vec(point) or (hit and (hit.initial or not finite(hit.time) or hit.time<0 or hit.time>1)) then return nil end
    local d={x=point.x-ray.origin.x,y=point.y-ray.origin.y,z=point.z-ray.origin.z}
    local along=d.x*ray.direction.x+d.y*ray.direction.y+d.z*ray.direction.z
    local perpendicular=d.x*d.x+d.y*d.y+d.z*d.z-along*along
    if along<2 or along>M.range_cm+1 or perpendicular>1 or
        (hit and math.abs(along-hit.time*M.range_cm)>2) then return nil end
    local position=add(point,ray.direction,-.4)
    local ex,ey,ez=eye.x-position.x,eye.y-position.y,eye.z-position.z
    local distance=math.sqrt(ex*ex+ey*ey+ez*ez)
    if distance<10 then return nil end
    return {point=point,position=position,scale=math.max(.1,math.min(20,distance*.0015)),
        rotation={pitch=math.deg(math.atan(ez,math.sqrt(ex*ex+ey*ey))),yaw=math.deg(math.atan(ey,ex))}}
end
function M.new(uevr)
    local api,hook,vr=uevr.api,uevr.types.UObjectHook,uevr.params.vr
    local JOURNAL='bolter3d.reticle.owned'
    local CLASS='Class /Script/ProceduralMeshComponent.ProceduralMeshComponent'
    local state,recovered,query,descriptors,gs=nil,false,nil,nil,nil
    local s={stopped=false}
    local function valid(o) return o~=nil and hook.exists(o) end
    local function prop(o,k)
        if valid(o) and o:get_class():find_property(k) then return o:get_property(k) end
    end
    local function record(o) return {object=o,name=o:get_full_name(),address=tostring(o:get_address())} end
    local function same(r)
        if not r or not valid(r.object) then return false end
        assert(r.object:get_full_name()==r.name and tostring(r.object:get_address())==r.address,'Reticle identity changed')
        return true
    end
    local function write()
        local a={'v1',state.engine,state.owner.address,state.owner.name,state.part.address,state.part.name}
        if state.hud then
            a[#a+1]=state.hud.address;a[#a+1]=state.hud.name;a[#a+1]=tostring(state.hud.opacity)
        end
        local text=table.concat(a,'\n');fs.write(JOURNAL,text)
        assert(fs.read(JOURNAL)==text,'Reticle ownership journal unavailable')
    end
    local function restore_hud()
        if not state or not state.hud then return end
        local h=state.hud
        if same(h) and h.object:GetRenderOpacity()==0 then h.object:SetRenderOpacity(h.opacity) end
        state.hud=nil
        write()
    end
    local function cleanup()
        if not state then return end
        restore_hud()
        if same(state.part) then
            assert(same(state.owner) and state.part.object:get_outer()==state.owner.object and
                state.part.object:get_class():get_full_name()==CLASS,'Reticle owner changed')
            state.part.object:SetHiddenInGame(true,false);state.part.object:SetVisibility(false,false)
            state.part.object:K2_DestroyComponent(state.owner.object)
            assert(not valid(state.part.object),'Reticle destruction pending')
        end
        fs.write(JOURNAL,'');assert(fs.read(JOURNAL)=='','Reticle journal removal failed');state=nil
    end
    local function recover()
        local text=fs.read(JOURNAL)
        if text=='' then recovered=true;return true end
        local f={};for v in text:gmatch('[^\r\n]+') do f[#f+1]=v end
        assert(f[1]=='v1' and (#f==6 or #f==9),'Unsupported reticle journal')
        local engine=api:get_engine();if not valid(engine) then return false end
        if tostring(engine:get_address())~=f[2] then fs.write(JOURNAL,'');recovered=true;return true end
        state={engine=f[2],owner={object=api:find_uobject(f[4]),address=f[3],name=f[4]},
            part={object=api:find_uobject(f[6]),address=f[5],name=f[6]}}
        if #f==9 then
            local opacity=tonumber(f[9]);assert(finite(opacity) and opacity>=0 and opacity<=1,'Invalid HUD journal')
            state.hud={object=api:find_uobject(f[8]),address=f[7],name=f[8],opacity=opacity}
        end
        cleanup();recovered=true;return true
    end
    local function hide(keep_hud)
        if not state then return end
        if same(state.part) then
            assert(same(state.owner) and state.part.object:get_outer()==state.owner.object,'Reticle owner changed')
            state.part.object:SetHiddenInGame(true,false);state.part.object:SetVisibility(false,false)
        end
        if not keep_hud then restore_hud() end
    end
    local function library(name)
        local cls=api:find_uobject('Class /Script/Engine.'..name);assert(valid(cls),'Missing '..name)
        local obj=cls:get_class_default_object();assert(valid(obj),'Missing library default');return obj
    end
    local function structure(name)
        local d=api:find_uobject('ScriptStruct /Script/CoreUObject.'..name)
        assert(valid(d),'Missing '..name);return d:as_struct()
    end
    local function make(desc,values)
        local v=StructObject.new(desc);for k,n in pairs(values) do v:set_property(k,n) end;return v
    end
    local function vector(p) return make(descriptors.vector,{X=p.x,Y=p.y,Z=p.z}) end
    local function parameters(fn,inputs)
        assert(fn,'Missing reticle function')
        local fields,seen={},{};local field=fn:get_child_properties()
        while field do
            local n=field:get_fname():to_string();local p=fn:find_property(n)
            if p and p:is_param() and not p:is_return_param() then
                assert(not seen[n] and (inputs and inputs[n] or not inputs and (n=='Hit' or p:is_out_param())),
                    'Unsupported reticle parameter '..n)
                fields[#fields+1]=n;seen[n]=true
            end
            field=field:get_next()
        end
        if inputs then for n in pairs(inputs) do assert(seen[n],'Missing reticle input '..n) end end
        return fields,seen
    end
    local function prepare_query()
        descriptors={vector=structure('Vector'),rotator=structure('Rotator')}
        gs=library('GameplayStatics')
        local system=library('KismetSystemLibrary')
        local trace=system:get_class():find_function('LineTraceSingle')
        local inputs={WorldContextObject=true,Start=true,End=true,TraceChannel=true,bTraceComplex=true,
            ActorsToIgnore=true,DrawDebugType=true,OutHit=true,bIgnoreSelf=true,TraceColor=true,TraceHitColor=true,DrawTime=true}
        local names=parameters(trace,inputs)
        local breaker=gs:get_class():find_function('BreakHitResult')
        local breaks,outputs=parameters(breaker)
        for _,n in ipairs({'Hit','bBlockingHit','bInitialOverlap','ImpactPoint','Time'}) do assert(outputs[n],'Missing hit field '..n) end
        return function(pawn,weapon,ray)
            local out={};local values={WorldContextObject=pawn,Start=vector(ray.origin),End=vector(ray.finish),
                TraceChannel=0,bTraceComplex=false,ActorsToIgnore={pawn,weapon},DrawDebugType=0,OutHit=out,
                bIgnoreSelf=true,TraceColor={R=0,G=0,B=0,A=0},TraceHitColor={R=0,G=0,B=0,A=0},DrawTime=0}
            local args={};for _,n in ipairs(names) do args[#args+1]=values[n] end
            local found=trace(system,table.unpack(args));assert(type(found)=='boolean','Invalid trace result')
            if not found then return nil end
            assert(out.result,'Missing real reticle HitResult')
            args={};local outs={}
            for _,n in ipairs(breaks) do
                if n=='Hit' then args[#args+1]=out.result else local o={};args[#args+1]=o;outs[n]=o end
            end
            breaker(gs,table.unpack(args));local d={};for n,o in pairs(outs) do d[n]=o.result end
            assert(d.bBlockingHit==true,'Reticle trace returned a nonblocking hit')
            local p=d.ImpactPoint;assert(p,'Missing impact point')
            return {point={x=p.X,y=p.Y,z=p.Z},time=d.Time,initial=d.bInitialOverlap==true}
        end
    end
    local function suppress_hud(controller)
        local hud=controller:GetHUD()
        if not valid(hud) or not hud:get_full_name():match('^Gameplay_HUD_C ') or prop(hud,'PlayerOwner')~=controller then restore_hud();return end
        local root=prop(hud,'Player HUD Widget')
        if not valid(root) or not root:get_full_name():match('^Gameplay_HUD_UI_C ') then restore_hud();return end
        local cross=prop(root,'W_PlayerHUD_Crosshair')
        if not valid(cross) or not cross:get_full_name():match('^W_PlayerHUD_Crosshair_C ') then restore_hud();return end
        local image=prop(cross,'Crosshair')
        if not valid(image) or image:get_class():get_full_name()~='Class /Script/UMG.Image' or
            image:get_full_name()~='Image '..cross:get_full_name():match('^[^ ]+ (.+)$')..'.WidgetTree.Crosshair' then restore_hud();return end
        if state.hud and (state.hud.name~=image:get_full_name() or state.hud.address~=tostring(image:get_address())) then restore_hud() end
        if not state.hud then
            local opacity=image:GetRenderOpacity();assert(finite(opacity) and opacity>=0 and opacity<=1,'Invalid HUD opacity')
            state.hud=record(image);state.hud.opacity=opacity;write()
        end
        image:SetRenderOpacity(0);assert(image:GetRenderOpacity()==0,'HUD opacity rejected')
    end
    local function step(pawn,weapon,enabled)
        if not recovered and not recover() then return end
        if state and (not same(state.owner) or state.owner.object~=pawn or not same(state.part)) then cleanup() end
        if not enabled or not valid(pawn) or api:get_local_pawn(0)~=pawn or not valid(weapon) or
            not vr.is_runtime_ready() or not vr.is_hmd_active() or not vr.is_using_controllers() or
            not vr.is_aim_allowed() or uevr.params.functions.is_drawing_ui() then hide();return end
        local handler=prop(pawn,'WeaponHandlerComponent')
        local pc=api:get_player_controller(0)
        if not valid(handler) or handler:get_outer()~=pawn or prop(handler,'EquippedWeapon')~=weapon or
            weapon:GetOwner()~=pawn or prop(pawn,'bPlayerFinishedLevelLoad')~=true or pawn:IsDead()~=false or not valid(pc) then hide();return end
        if not query then query=prepare_query() end
        local menu=prop(prop(pc,'MyHUD'),'CurrentMenu')
        if gs:IsGamePaused(pc)~=false or valid(menu) and menu:IsInViewport() and menu:IsVisible() then hide();return end
        if not state then
            local engine=api:get_engine();assert(valid(engine),'Missing reticle engine')
            local class=api:find_uobject(CLASS);assert(valid(class),'Missing reticle component class')
            local part=api:add_component_by_class(pawn,class,false)
            assert(valid(part) and part:get_outer()==pawn and part:get_class():get_full_name()==CLASS,'Reticle creation failed')
            state={engine=tostring(engine:get_address()),owner=record(pawn),part=record(part)};write()
            part:SetHiddenInGame(true,false);part:SetVisibility(false,false)
            part:SetCollisionEnabled(0);part:SetGenerateOverlapEvents(false);part:SetMobility(2);part:SetCastShadow(false)
            part:SetOwnerNoSee(false);part:SetOnlyOwnerSee(false)
            local dispatch=assert(uevr.params.functions.dispatch_custom_event,'Reticle bridge unavailable')
            dispatch('boltgun.reticle.v1',table.concat({'mesh',tostring(pawn:get_address()),tostring(weapon:get_address()),tostring(part:get_address())},'|'))
            assert(part:GetNumSections()==1,'Reticle geometry request rejected')
        end
        hide(true) -- Reset acknowledgement before every synchronous request; marker remains hidden.
        local part=state.part.object
        uevr.params.functions.dispatch_custom_event('boltgun.reticle.v1',table.concat(
            {'ray',tostring(pawn:get_address()),tostring(weapon:get_address()),tostring(part:get_address())},'|'))
        if prop(part,'bVisible')~=true then hide();return end
        part:SetVisibility(false,false)
        local ray=M.ray(part:K2_GetComponentToWorld());if not ray then hide();return end
        local camera=prop(pc,'PlayerCameraManager');if not valid(camera) then hide();return end
        local eye=camera:GetCameraLocation()
        local placement=M.marker(ray,query(pawn,weapon,ray),{x=eye.X,y=eye.Y,z=eye.Z});if not placement then hide();return end
        part:K2_SetWorldLocation(vector(placement.position),false,{},true)
        part:K2_SetWorldRotation(make(descriptors.rotator,{Pitch=placement.rotation.pitch,Yaw=placement.rotation.yaw,Roll=0}),false,{},true)
        part:SetWorldScale3D(vector({x=placement.scale,y=placement.scale,z=placement.scale}))
        local placed=part:K2_GetComponentToWorld()
        local actual=M.ray(placed)
        local scale=placed and placed.Scale3D
        local p=placement.position
        if not actual or not scale or not finite(scale.X) or not finite(scale.Y) or not finite(scale.Z) or
            math.abs(scale.X-placement.scale)>.01 or math.abs(scale.Y-placement.scale)>.01 or
            math.abs(scale.Z-placement.scale)>.01 or math.abs(actual.origin.x-p.x)>.05 or
            math.abs(actual.origin.y-p.y)>.05 or math.abs(actual.origin.z-p.z)>.05 then hide();return end
        local dx,dy,dz=eye.X-p.x,eye.Y-p.y,eye.Z-p.z
        local facing=(actual.direction.x*dx+actual.direction.y*dy+actual.direction.z*dz)/math.sqrt(dx*dx+dy*dy+dz*dz)
        if facing<.999 then hide();return end
        part:SetVisibility(true,false);part:SetHiddenInGame(false,false)
        suppress_hud(pc)
    end
    function s:step(pawn,weapon,enabled)
        if self.stopped then return end
        local ok,err=pcall(step,pawn,weapon,enabled)
        if not ok then
            self.stopped=true;pcall(hide);pcall(cleanup)
            uevr.params.functions.log_info('[Boltgun reticle] Disabled: '..tostring(err))
        end
    end
    function s:stop() self.stopped=true end -- Reset callback never accesses UObjects; next instance recovers.
    return s
end
return M
