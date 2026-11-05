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
    if not ray then return nil,'marker-ray-invalid' end
    if not vec(eye) then return nil,'marker-camera-invalid' end
    local point=ray.finish
    if hit then
        if hit.initial then return nil,'marker-initial-overlap' end
        if not finite(hit.time) or hit.time<0 or hit.time>1 then return nil,'marker-hit-time-invalid' end
        point=hit.point
    end
    if not vec(point) then return nil,'marker-hit-point-invalid' end
    local d={x=point.x-ray.origin.x,y=point.y-ray.origin.y,z=point.z-ray.origin.z}
    local along=d.x*ray.direction.x+d.y*ray.direction.y+d.z*ray.direction.z
    local perpendicular=d.x*d.x+d.y*d.y+d.z*d.z-along*along
    if along<0 or along>M.range_cm+1 or perpendicular>1 then return nil,'marker-hit-off-ray' end
    if hit and math.abs(along-hit.time*M.range_cm)>2 then return nil,'marker-hit-time-mismatch' end
    -- Keep the setback within the traced segment, including a hit at the muzzle.
    local position=add(ray.origin,ray.direction,along-math.min(.4,along*.5))
    local ex,ey,ez=eye.x-position.x,eye.y-position.y,eye.z-position.z
    local distance=math.sqrt(ex*ex+ey*ey+ez*ez)
    if distance<10 then return nil,'marker-camera-near' end
    return {point=point,position=position,near_hit=hit~=nil and along<2,
        scale=math.max(.1,math.min(20,distance*.0015)),
        rotation={pitch=math.deg(math.atan(ez,math.sqrt(ex*ex+ey*ey))),yaw=math.deg(math.atan(ey,ex))}}
end
function M.new(uevr)
    local api,hook,vr=uevr.api,uevr.types.UObjectHook,uevr.params.vr
    local JOURNAL='bolter3d.reticle.owned'
    local CLASS='Class /Script/UMG.WidgetComponent'
    local LEGACY_CLASS='Class /Script/ProceduralMeshComponent.ProceduralMeshComponent'
    local WIDGET_ALPHA='MaterialInstanceConstant /Engine/EngineMaterials/Widget3DPassThrough_Translucent.Widget3DPassThrough_Translucent'
    local WIDGET_ALPHA_PARENT='Material /Engine/EngineMaterials/Widget3DPassThrough.Widget3DPassThrough'
    local state,recovered,query,descriptors,gs=nil,false,nil,nil,nil
    local s={stopped=false,status='not-stepped',ticks=0,acks=0,traces=0,placed=0,
        material='not-created',rejected=0,last_rejection='none',
        geometry_rejected=0,last_geometry_rejection='none',initial_overlaps=0,near_placed=0}
    local status_tick,last_logged,log_budget=nil,nil,12
    local function diagnostic(stage,force)
        s.status=stage
        if stage~='placed' then s.rejected=s.rejected+1;s.last_rejection=stage end
        -- One small, overwritten snapshot at most every 120 post-engine ticks.
        -- Diagnostics must never break ownership recovery or disable gameplay.
        if not force and status_tick and s.ticks-status_tick<120 then return end
        status_tick=s.ticks
        local text=string.format('v1\nstage=%s\nticks=%d\nacks=%d\ntraces=%d\nplaced=%d\nrejected=%d\nlast_rejection=%s\nmaterial=%s\nphase=%s\n'..
            'geometry_rejected=%d\nlast_geometry_rejection=%s\ninitial_overlaps=%d\nnear_placed=%d\n',
            stage,s.ticks,s.acks,s.traces,s.placed,s.rejected,s.last_rejection,s.material,s.phase or 'none',
            s.geometry_rejected,s.last_geometry_rejection,s.initial_overlaps,s.near_placed)
        local ok=pcall(function()
            fs.write('bolter3d.reticle.status',text)
            assert(fs.read('bolter3d.reticle.status')==text,'Reticle status write unavailable')
        end)
        if log_budget>0 and (last_logged~=stage or not ok) then
            log_budget=log_budget-1;last_logged=stage
            pcall(uevr.params.functions.log_info,'[Boltgun reticle] Status: '..stage..
                '; material='..s.material..(ok and '' or '; status-file-unavailable'))
        end
    end
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
                (state.part.object:get_class():get_full_name()==CLASS or
                 state.part.object:get_class():get_full_name()==LEGACY_CLASS),'Reticle owner changed')
            state.part.object:SetHiddenInGame(true,false);state.part.object:SetVisibility(false,false)
            state.part.object:K2_DestroyComponent(state.owner.object)
            -- UE unregisters/destroys the component before garbage collection
            -- removes its UObject. UObjectHook.exists may stay true until then.
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
    local function alpha_material(part)
        -- Boltgun's resident pass-through is a cooked MIC. Domain and depth
        -- testing belong to its parent; blend and shading can be overridden.
        s.material='widget-alpha-unavailable'
        local candidate=prop(part,'TranslucentMaterial')
        if not valid(candidate) or candidate:get_full_name()~=WIDGET_ALPHA then return false end
        local parent=prop(candidate,'Parent')
        if not valid(parent) or parent:get_full_name()~=WIDGET_ALPHA_PARENT or
            prop(parent,'MaterialDomain')~=0 or prop(parent,'bDisableDepthTest')~=false then return false end
        local overrides=prop(candidate,'BasePropertyOverrides')
        if not overrides or type(overrides.bOverride_BlendMode)~='boolean' or
            type(overrides.bOverride_ShadingModel)~='boolean' or
            overrides.bOverride_TwoSided~=true or overrides.TwoSided~=true then return false end
        local blend=prop(parent,'BlendMode')
        if overrides.bOverride_BlendMode then blend=overrides.BlendMode end
        local unlit
        if overrides.bOverride_ShadingModel then
            unlit=overrides.ShadingModel==0 -- MSM_Unlit
        else
            local models=prop(parent,'ShadingModels')
            unlit=models and models.ShadingModelField==1 -- only MSM_Unlit
        end
        if blend~=2 or not unlit then return false end -- BLEND_Translucent
        if not state.alpha or not same(state.alpha) or state.alpha.object~=candidate then
            part:SetMaterial(0,candidate);state.appearance_key=nil;state.alpha=record(candidate)
        end
        -- WidgetComponent may return its render-target MID from GetMaterial.
        -- Reapplying the source every tick would recreate that MID repeatedly.
        local actual,instance=part:GetMaterial(0),part:GetMaterialInstance()
        assert(actual==candidate or valid(instance) and actual==instance,'Reticle alpha material rejected')
        if valid(instance) and prop(instance,'Parent')~=candidate then return false end
        s.material='original-hud-brush-alpha';return true
    end
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
        descriptors={vector=structure('Vector'),vector2=structure('Vector2D'),rotator=structure('Rotator')}
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
    local function hud_image(controller)
        local hud=controller:GetHUD()
        if not valid(hud) or not hud:get_full_name():match('^Gameplay_HUD_C ') or prop(hud,'PlayerOwner')~=controller then return end
        local root=prop(hud,'Player HUD Widget')
        if not valid(root) or not root:get_full_name():match('^Gameplay_HUD_UI_C ') or not root:IsVisible() then return end
        local cross=prop(root,'W_PlayerHUD_Crosshair')
        if not valid(cross) or not cross:get_full_name():match('^W_PlayerHUD_Crosshair_C ') or not cross:IsVisible() then return end
        local image=prop(cross,'Crosshair')
        if not valid(image) or image:get_class():get_full_name()~='Class /Script/UMG.Image' or
            image:get_full_name()~='Image '..cross:get_full_name():match('^[^ ]+ (.+)$')..'.WidgetTree.Crosshair' then return end
        if not image:IsVisible() then return end
        return image,cross
    end
    local function equal(a,b,fields)
        if not a or not b then return false end
        for _,k in ipairs(fields) do
            if not finite(a[k]) or not finite(b[k]) or math.abs(a[k]-b[k])>.00001 then return false end
        end
        return true
    end
    local function brush(image)
        local b=prop(image,'Brush')
        local size=b and b.ImageSize
        if b and valid(b.ResourceObject) and size and finite(size.X) and finite(size.Y) and
            size.X>0 and size.Y>0 and size.X<=512 and size.Y<=512 then return b end
    end
    local function key(...)
        local fields={}
        for i=1,select('#',...) do fields[i]=tostring(select(i,...)) end
        return table.concat(fields,'|')
    end
    local function component(v,k) return v and v[k] end
    local function canvas(transform,pivot)
        -- A square bound using the L1 norm also covers rotations and shear.
        -- Keep the authored centered 128px slot, with transparent padding;
        -- scaling the native image must not crop it at the render target edge.
        local scale,shift,shear=transform.Scale,transform.Translation,transform.Shear
        if math.abs(shear.X)>=80 or math.abs(shear.Y)>=80 then return end
        local radius=128*(math.abs(scale.X)*math.max(math.abs(pivot.X),math.abs(1-pivot.X))+
            math.abs(scale.Y)*math.max(math.abs(pivot.Y),math.abs(1-pivot.Y))) *
            (1+math.abs(math.tan(math.rad(shear.X)))+math.abs(math.tan(math.rad(shear.Y))))+
            128*(math.abs(pivot.X-.5)+math.abs(pivot.Y-.5))+math.abs(shift.X)+math.abs(shift.Y)
        local size=math.max(128,math.ceil(radius*2))
        if size<=1024 then return size end
    end
    local function appearance(image,cross,pc)
        local part=state.part.object
        if not state.widget then
            local cls=api:find_uobject('Class /Script/UMG.WidgetBlueprintLibrary')
            assert(valid(cls),'Missing widget library')
            local widget=cls:get_class_default_object():Create(state.owner.object,cross:get_class(),pc)
            assert(valid(widget) and widget~=cross and widget:get_class()==cross:get_class(),'Reticle widget creation failed')
            state.widget=record(widget)
            part:SetWidget(widget)
            assert(part:GetUserWidgetObject()==widget,'Reticle widget binding rejected')
            local glyph=prop(widget,'Crosshair')
            assert(valid(glyph) and glyph~=image and glyph:get_class():get_full_name()=='Class /Script/UMG.Image' and
                glyph:get_full_name()=='Image '..widget:get_full_name():match('^[^ ]+ (.+)$')..'.WidgetTree.Crosshair',
                'Reticle glyph identity rejected')
            state.glyph=record(glyph)
        end
        assert(same(state.widget) and same(state.glyph) and part:GetUserWidgetObject()==state.widget.object and
            prop(state.widget.object,'Crosshair')==state.glyph.object,'Reticle widget identity changed')
        local glyph=state.glyph.object
        local b=brush(image);if not b then return false end
        glyph:SetBrush(b)
        local actual=prop(glyph,'Brush')
        assert(actual and actual.ResourceObject==b.ResourceObject and equal(actual.ImageSize,b.ImageSize,{'X','Y'}),
            'Reticle original brush rejected')
        local color=prop(image,'ColorAndOpacity')
        assert(equal(color,color,{'R','G','B','A'}),'Invalid native crosshair color')
        glyph:SetColorAndOpacity(color)
        assert(equal(prop(glyph,'ColorAndOpacity'),color,{'R','G','B','A'}),'Reticle color rejected')
        local transform,pivot=prop(image,'RenderTransform'),prop(image,'RenderTransformPivot')
        assert(transform and equal(transform.Scale,transform.Scale,{'X','Y'}) and
            equal(transform.Translation,transform.Translation,{'X','Y'}) and
            equal(transform.Shear,transform.Shear,{'X','Y'}) and finite(transform.Angle) and
            equal(pivot,pivot,{'X','Y'}),'Invalid native crosshair transform')
        glyph:SetRenderTransform(transform);glyph:SetRenderTransformPivot(pivot)
        local t=prop(glyph,'RenderTransform')
        assert(t and equal(t.Scale,transform.Scale,{'X','Y'}) and
            equal(t.Translation,transform.Translation,{'X','Y'}) and equal(t.Shear,transform.Shear,{'X','Y'}) and
            finite(t.Angle) and math.abs(t.Angle-transform.Angle)<.00001 and
            equal(prop(glyph,'RenderTransformPivot'),pivot,{'X','Y'}),'Reticle glyph transform rejected')
        local opacity=image:GetRenderOpacity()
        if state.hud and state.hud.object==image and same(state.hud) and opacity~=0 then restore_hud() end
        if state.hud and state.hud.object==image and same(state.hud) and opacity==0 then opacity=state.hud.opacity end
        assert(finite(opacity) and opacity>=0 and opacity<=1,'Invalid native crosshair opacity')
        glyph:SetRenderOpacity(opacity)
        assert(glyph:GetRenderOpacity()==opacity,'Reticle glyph opacity rejected')
        local visibility=prop(image,'Visibility')
        glyph:SetVisibility(visibility)
        assert(prop(glyph,'Visibility')==visibility,'Reticle glyph visibility rejected')
        local size=canvas(transform,pivot);if not size then return false end
        if not equal(part:GetDrawSize(),{X=size,Y=size},{'X','Y'}) then
            part:SetDrawSize(make(descriptors.vector2,{X=size,Y=size}))
        end
        assert(equal(part:GetDrawSize(),{X=size,Y=size},{'X','Y'}),'Reticle padded canvas rejected')
        local tint=b.TintColor
        local tint_color=tint and tint.SpecifiedColor
        local margin,uv=b.Margin,b.UVRegion
        local lo,hi=uv and uv.Min,uv and uv.Max
        local name=b.ResourceName
        local current=key(image:get_address(),b.ResourceObject:get_address(),b.ImageSize.X,b.ImageSize.Y,
            b.DrawAs,b.Tiling,b.Mirroring,b.ImageType,b.bIsDynamicallyLoaded,name and name:to_string(),
            component(tint,'ColorUseRule'),component(tint_color,'R'),component(tint_color,'G'),
            component(tint_color,'B'),component(tint_color,'A'),component(margin,'Left'),component(margin,'Top'),
            component(margin,'Right'),component(margin,'Bottom'),component(uv,'bIsValid'),
            component(lo,'X'),component(lo,'Y'),component(hi,'X'),component(hi,'Y'),
            color.R,color.G,color.B,color.A,transform.Scale.X,transform.Scale.Y,
            transform.Translation.X,transform.Translation.Y,transform.Shear.X,transform.Shear.Y,
            transform.Angle,pivot.X,pivot.Y,opacity,visibility,size)
        if state.appearance_key~=current then part:RequestRedraw();state.appearance_key=current end
        return true
    end
    local function suppress_hud(image)
        if state.hud and (state.hud.name~=image:get_full_name() or state.hud.address~=tostring(image:get_address())) then restore_hud() end
        if not state.hud then
            local opacity=image:GetRenderOpacity();assert(finite(opacity) and opacity>=0 and opacity<=1,'Invalid HUD opacity')
            state.hud=record(image);state.hud.opacity=opacity;write()
        end
        image:SetRenderOpacity(0);assert(image:GetRenderOpacity()==0,'HUD opacity rejected')
    end
    local function step(pawn,weapon,enabled)
        s.phase='recovery'
        if not recovered and not recover() then return 'recovery-engine-unavailable' end
        if state and (not same(state.owner) or state.owner.object~=pawn or not same(state.part)) then cleanup() end
        local function reject(reason) hide();return reason end
        s.phase='gates'
        if not enabled then return reject('integration-disabled') end
        if not valid(pawn) or api:get_local_pawn(0)~=pawn or not valid(weapon) then return reject('local-owner-unavailable') end
        if not vr.is_runtime_ready() then return reject('runtime-not-ready') end
        if not vr.is_hmd_active() then return reject('hmd-inactive') end
        if not vr.is_using_controllers() then return reject('controllers-inactive') end
        if not vr.is_aim_allowed() then return reject('aim-disallowed') end
        if uevr.params.functions.is_drawing_ui() then return reject('uevr-menu') end
        local handler=prop(pawn,'WeaponHandlerComponent')
        local pc=api:get_player_controller(0)
        if not valid(handler) or handler:get_outer()~=pawn or prop(handler,'EquippedWeapon')~=weapon or
            weapon:GetOwner()~=pawn or prop(pawn,'bPlayerFinishedLevelLoad')~=true or pawn:IsDead()~=false or not valid(pc) then return reject('weapon-owner-gate') end
        s.phase='query-reflection'
        if not query then query=prepare_query() end
        local menu=prop(prop(pc,'MyHUD'),'CurrentMenu')
        if gs:IsGamePaused(pc)~=false or valid(menu) and menu:IsInViewport() and menu:IsVisible() then return reject('paused-or-menu') end
        local image,cross=hud_image(pc)
        if not image or not brush(image) then return reject('original-brush-unavailable') end
        if not state then
            s.phase='widget'
            local engine=api:get_engine();assert(valid(engine),'Missing reticle engine')
            local class=api:find_uobject(CLASS);assert(valid(class),'Missing reticle component class')
            local part=api:add_component_by_class(pawn,class,false)
            assert(valid(part) and part:get_outer()==pawn and part:get_class():get_full_name()==CLASS,'Reticle creation failed')
            state={engine=tostring(engine:get_address()),owner=record(pawn),part=record(part)};write()
            part:SetHiddenInGame(true,false);part:SetVisibility(false,false)
            part:SetCollisionEnabled(0);part:SetGenerateOverlapEvents(false);part:SetMobility(2);part:SetCastShadow(false)
            part:SetOwnerNoSee(false);part:SetOnlyOwnerSee(false)
            part:SetWidgetSpace(0);part:SetDrawAtDesiredSize(false);part:SetTickWhenOffscreen(true)
            -- UE4 exposes the enum property but not SetBlendMode to reflection.
            -- Set it before SetBackgroundColor and the engine's MID creation.
            part:set_property('BlendMode',2) -- EWidgetBlendMode::Transparent
            part:SetDrawSize(make(descriptors.vector2,{X=128,Y=128}))
            part:SetPivot(make(descriptors.vector2,{X=.5,Y=.5}));part:SetWindowFocusable(false)
            part:SetBackgroundColor({R=0,G=0,B=0,A=0})
            assert(part:GetWidgetSpace()==0 and prop(part,'BlendMode')==2 and
                equal(part:GetDrawSize(),{X=128,Y=128},{'X','Y'}) and
                equal(part:GetPivot(),{X=.5,Y=.5},{'X','Y'}) and part:GetWindowFocusable()==false,
                'Reticle widget layout rejected')
        end
        local part=state.part.object
        assert(same(state.owner) and part:get_outer()==state.owner.object,'Reticle owner changed')
        s.phase='material'
        if not alpha_material(part) then return reject('widget-alpha-unavailable') end
        s.phase='appearance'
        if not appearance(image,cross,pc) then return reject('original-brush-unavailable') end
        -- RequestRedraw is asynchronous. UE clears this reflected bit on
        -- the widget draw path.
        local redraw=prop(part,'bRedrawRequested')
        if type(redraw)~='boolean' then return reject('glyph-redraw-unavailable') end
        local target=part:GetRenderTarget()
        local instance=part:GetMaterialInstance()
        if not state.slate_name then
            local strings=api:find_uobject('Class /Script/Engine.KismetStringLibrary')
            assert(valid(strings),'Missing widget parameter names')
            state.slate_name=strings:get_class_default_object():Conv_StringToName('SlateUI')
        end
        local size=part:GetDrawSize()
        -- Visibility/transform changes can request a proxy redraw. An already
        -- drawn glyph is still usable while its target, material and key match.
        local drawn=state.drawn_key==state.appearance_key and state.drawn_target==target and state.drawn_mid==instance
        if not valid(target) or not valid(instance) or (redraw and not drawn) or
            prop(target,'SizeX')~=size.X or prop(target,'SizeY')~=size.Y or
            instance:K2_GetTextureParameterValue(state.slate_name)~=target then
            state.drawn_key,state.drawn_target,state.drawn_mid=nil,nil,nil
            s.phase='glyph-warmup'
            -- This UE4 build's IsVisible checks bHiddenInGame. Give the widget
            -- tick a visible component with a collapsed, non-colliding quad.
            if part:GetCollisionEnabled()~=0 then return reject('warmup-collision-enabled') end
            part:SetWorldScale3D(vector({x=0,y=0,z=0}))
            local transform=part:K2_GetComponentToWorld()
            local scale=transform and transform.Scale3D
            if not scale or scale.X~=0 or scale.Y~=0 or scale.Z~=0 then return reject('warmup-scale-readback') end
            part:SetVisibility(true,false);part:SetHiddenInGame(false,false)
            if prop(part,'bVisible')~=true or prop(part,'bHiddenInGame')~=false then return reject('visibility-readback') end
            restore_hud();return 'glyph-render-pending'
        end
        state.drawn_key,state.drawn_target,state.drawn_mid=state.appearance_key,target,instance
        s.phase='native-ray'
        hide(true) -- Reset acknowledgement before every synchronous request; marker remains hidden.
        uevr.params.functions.dispatch_custom_event('boltgun.reticle.v1',table.concat(
            {'ray',tostring(pawn:get_address()),tostring(weapon:get_address()),tostring(part:get_address())},'|'))
        if prop(part,'bVisible')~=true then return reject('native-ack-missing') end
        s.acks=s.acks+1
        part:SetVisibility(false,false)
        local ray=M.ray(part:K2_GetComponentToWorld());if not ray then return reject('native-ray-invalid') end
        local camera=prop(pc,'PlayerCameraManager');if not valid(camera) then return reject('camera-unavailable') end
        local eye=camera:GetCameraLocation()
        s.phase='trace';s.traces=s.traces+1
        local placement,reason=M.marker(ray,query(pawn,weapon,ray),{x=eye.X,y=eye.Y,z=eye.Z})
        if not placement then
            s.geometry_rejected=s.geometry_rejected+1;s.last_geometry_rejection=reason
            if reason=='marker-initial-overlap' then
                s.initial_overlaps=s.initial_overlaps+1
                -- The acknowledged muzzle starts in a blocker. Keep the
                -- world component hidden and withhold the centered fallback.
                s.phase='hud'
                suppress_hud(image)
                return reason
            end
            return reject(reason)
        end
        s.phase='placement'
        part:K2_SetWorldLocation(vector(placement.position),false,{},true)
        part:K2_SetWorldRotation(make(descriptors.rotator,{Pitch=placement.rotation.pitch,Yaw=placement.rotation.yaw,Roll=0}),false,{},true)
        -- The authored slot is 128 pixels wide; retain the old marker's two
        -- centimetre nominal quad footprint without changing the firing ray.
        local world_scale=placement.scale/64
        part:SetWorldScale3D(vector({x=world_scale,y=world_scale,z=world_scale}))
        local placed=part:K2_GetComponentToWorld()
        local actual=M.ray(placed)
        local scale=placed and placed.Scale3D
        local p=placement.position
        if not actual or not scale or not finite(scale.X) or not finite(scale.Y) or not finite(scale.Z) or
            math.abs(scale.X-world_scale)>world_scale*.01 or math.abs(scale.Y-world_scale)>world_scale*.01 or
            math.abs(scale.Z-world_scale)>world_scale*.01 or math.abs(actual.origin.x-p.x)>.05 or
            math.abs(actual.origin.y-p.y)>.05 or math.abs(actual.origin.z-p.z)>.05 then return reject('placement-readback') end
        local dx,dy,dz=eye.X-p.x,eye.Y-p.y,eye.Z-p.z
        local facing=(actual.direction.x*dx+actual.direction.y*dy+actual.direction.z*dz)/math.sqrt(dx*dx+dy*dy+dz*dz)
        if facing<.999 then return reject('facing-readback') end
        s.phase='visibility'
        part:SetVisibility(true,false);part:SetHiddenInGame(false,false)
        if prop(part,'bVisible')~=true or prop(part,'bHiddenInGame')~=false then return reject('visibility-readback') end
        s.phase='hud'
        suppress_hud(image)
        s.placed=s.placed+1
        if placement.near_hit then s.near_placed=s.near_placed+1 end
        return 'placed'
    end
    function s:step(pawn,weapon,enabled)
        if self.stopped then return end
        self.ticks=self.ticks+1
        local ok,err=pcall(step,pawn,weapon,enabled)
        if not ok then
            self.stopped=true;pcall(hide);pcall(cleanup)
            diagnostic('api-error',true)
            uevr.params.functions.log_info('[Boltgun reticle] Disabled: '..tostring(err))
        else diagnostic(err or 'unknown') end
    end
    function s:stop() self.stopped=true end -- Reset callback never accesses UObjects; next instance recovers.
    return s
end
return M
