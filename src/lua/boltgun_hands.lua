-- Native-submitted gauntlets; +X aim, +Z dorsal, wrist -X, grip at (0,0,0).
-- UObject reads, writes and controller attachment occur only on engine ticks.
local api, hook, vr = uevr.api, uevr.types.UObjectHook, uevr.params.vr
local functions, callbacks = uevr.params.functions, uevr.params.sdk.callbacks
local CLASS = 'Class /Script/ProceduralMeshComponent.ProceduralMeshComponent'
local PLANE = 'Class /Script/Engine.StaticMeshComponent'
local MATERIAL = 'MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun'
local JOURNAL = 'hands3d.owned'
local records, hands, recovered, stopped, hands_failed = {}, {}, false, false, false
local session, last_player, settings_text, settings = nil, nil, nil, {}
local warmup, last_message = 0, nil
local function report(message)
    if message == last_message then return end
    last_message = message
    functions.log_info('[Boltgun Hands] '..message)
end
local function valid(o) return o ~= nil and hook.exists(o) end
local function prop(o, key)
    if valid(o) and o:get_class():find_property(key) then return o:get_property(key) end
end
local function identity(o)
    assert(valid(o), 'Object unavailable')
    return {object=o, name=o:get_full_name(), address=tostring(o:get_address())}
end
local function same(i)
    return i and valid(i.object) and i.object:get_full_name()==i.name and
        tostring(i.object:get_address())==i.address
end
local function player(o)
    return valid(o) and o:get_full_name():match(
        '^BP_PlayerCharacter_Sternguard_C /Game/Maps/[^ ]+%.PersistentLevel%.BP_PlayerCharacter_Sternguard_C_%d+$') ~= nil
end
local function journal()
    local lines = {}
    if #records > 0 then
        assert(same(session), 'Engine identity changed')
        lines = {'v1', session.address, session.name}
        for _,r in ipairs(records) do
            local values = {r.kind,r.owner.address,r.owner.name,
                r.renderer and r.renderer.address or '-',r.renderer and r.renderer.name or '-',
                r.item.address,r.item.name,tostring(r.hidden),tostring(r.visible)}
            for _,v in ipairs(values) do assert(not v:find('[\r\n\t]'), 'Invalid journal identity') end
            lines[#lines+1] = table.concat(values,'\t')
        end
    end
    local text = table.concat(lines,'\n')
    fs.write(JOURNAL,text)
    assert(fs.read(JOURNAL)==text, 'Ownership journal could not be saved')
end
local function exact(r)
    if not valid(r.item.object) then return false end
    assert(same(r.item) and same(r.owner), 'Owned object or pawn identity changed; journal retained')
    local item, owner = r.item.object, r.owner.object
    assert(item:get_outer()==(r.renderer and r.renderer.object or owner), 'Owned object outer changed; journal retained')
    assert(item:get_class():get_full_name()==(r.kind=='mesh' and CLASS or PLANE), 'Owned class changed')
    return true
end
-- Renderer properties use their actual reflected names as record kinds.
local function verified(r)
    if r.kind=='mesh' then return exact(r) end
    if not valid(r.item.object) then return false end
    assert(same(r.item) and same(r.owner) and same(r.renderer), 'Death plane identity changed; journal retained')
    assert(r.item.object:get_class():get_full_name()==PLANE and
        r.item.object:get_outer()==r.renderer.object and r.renderer.object:get_outer()==r.owner.object and
        prop(r.owner.object,'WeaponRenderer')==r.renderer.object and
        prop(r.renderer.object,r.kind)==r.item.object, 'Death renderer ownership changed; journal retained')
    return true
end
local function restore(r)
    if not verified(r) then return end
    local o = r.item.object
    if r.kind=='mesh' then
        o:SetHiddenInGame(true,false);o:SetVisibility(false,false)
        hook.remove_motion_controller_state(o)
        o:K2_DestroyComponent(r.owner.object)
    elseif prop(o,'bHiddenInGame')==true and prop(o,'bVisible')==false then
        -- Preserve a subsequent native/game visibility change.
        o:SetHiddenInGame(r.hidden,false);o:SetVisibility(r.visible,false)
    end
end
local function remove_records(mesh_only)
    for n=#records,1,-1 do
        local r=records[n]
        if not mesh_only or r.kind=='mesh' then
            restore(r);table.remove(records,n);journal()
        end
    end
    hands={}
end
local function recover()
    local text=fs.read(JOURNAL)
    if text=='' then recovered=true;return end
    local lines={};for line in text:gmatch('[^\n]+') do lines[#lines+1]=line end
    assert(#lines>=4 and lines[1]=='v1', 'Invalid hands journal; refusing duplicate hands')
    local engine=api:get_engine();if not valid(engine) then return end
    session=identity(engine)
    if session.address~=lines[2] or session.name~=lines[3] then
        journal();recovered=true;return -- Never resolve an earlier process's object names.
    end
    for n=4,#lines do
        local f={};for v in lines[n]:gmatch('[^\t]+') do f[#f+1]=v end
        assert(#f==9 and (f[1]=='mesh' or f[1]=='PrimaryRenderPlane' or f[1]=='SecondaryRenderPlane') and
            (f[8]=='true' or f[8]=='false') and (f[9]=='true' or f[9]=='false'), 'Invalid hands ownership record')
        local o=api:find_uobject(f[7])
        if valid(o) then
            local r={kind=f[1],owner={object=api:find_uobject(f[3]),address=f[2],name=f[3]},
                item={object=o,address=f[6],name=f[7]},hidden=f[8]=='true',visible=f[9]=='true'}
            if f[1]~='mesh' then r.renderer={object=api:find_uobject(f[5]),address=f[4],name=f[5]} end
            verified(r);records[#records+1]=r
        end
    end
    remove_records(false);recovered=true
    report('Previous gauntlets and exact death-plane visibility recovered on engine tick')
end

-- Exact 25 material/BC names from the installed UE4.27 cooked death animation data.
local death_assets={}
for sequence,count in ipairs({7,9,9}) do
    local id=string.format('%02d',sequence)
    local path='/Game/Art/Animations/Player/Deaths/Death'..id..'/'
    for frame=1,count do
        local suffix=id..'_'..string.format('%02d',frame)
        local mi,bc='MI_Arms_Death'..suffix,'T_Arms_Death'..suffix..'_BC'
        death_assets['MaterialInstanceConstant '..path..mi..'.'..mi]=true
        death_assets['Texture2D '..path..bc..'.'..bc]=true
    end
end
local function fname(text)
    local cls=api:find_uobject('Class /Script/Engine.KismetStringLibrary')
    assert(valid(cls) and cls:find_function('Conv_StringToName'), 'FName library unavailable')
    return cls:get_class_default_object():Conv_StringToName(text)
end
local function death_plane(o)
    local material=o:GetMaterial(0)
    for _=1,4 do
        if not valid(material) then return false end
        if death_assets[material:get_full_name()] then return true end
        if material:get_class():find_function('K2_GetTextureParameterValue') then
            local texture=material:K2_GetTextureParameterValue(fname('BC'))
            if valid(texture) and death_assets[texture:get_full_name()] then return true end
        end
        material=prop(material,'Parent')
    end
    return false
end
local function update_death(pawn, enabled)
    for n=#records,1,-1 do
        local r=records[n]
        if r.kind~='mesh' then
            local live=verified(r)
            if not live or not enabled or not death_plane(r.item.object) then
                restore(r);table.remove(records,n);journal()
            else
                r.item.object:SetHiddenInGame(true,false);r.item.object:SetVisibility(false,false)
            end
        end
    end
    if not enabled then return end
    local candidates={}
    if player(pawn) then candidates[#candidates+1]=pawn end
    -- Death can possess BP_DeadPlayerPawn before the old renderer finishes.
    if same(last_player) and last_player.object~=pawn then candidates[#candidates+1]=last_player.object end
    for _,owner in ipairs(candidates) do
        local renderer=prop(owner,'WeaponRenderer')
        if valid(renderer) and renderer:get_outer()==owner then
            for _,key in ipairs({'PrimaryRenderPlane','SecondaryRenderPlane'}) do
                local plane=prop(renderer,key)
                if valid(plane) and plane:get_outer()==renderer and plane:get_class():get_full_name()==PLANE and
                    plane:get_short_name()==(key=='PrimaryRenderPlane' and 'Primary Render Plane' or 'Secondary Render Plane') and
                    death_plane(plane) then
                    local found=false
                    for _,r in ipairs(records) do if r.item.object==plane then found=true end end
                    if not found then
                        local hidden,visible=prop(plane,'bHiddenInGame'),prop(plane,'bVisible')
                        assert(type(hidden)=='boolean' and type(visible)=='boolean','Death visibility unavailable')
                        records[#records+1]={kind=key,owner=identity(owner),renderer=identity(renderer),
                            item=identity(plane),hidden=hidden,visible=visible}
                        journal() -- Persist original flags before either mutation.
                    end
                    plane:SetHiddenInGame(true,false);plane:SetVisibility(false,false)
                end
            end
        end
    end
end
local function library(name)
    local c=api:find_uobject('Class /Script/Engine.'..name)
    assert(valid(c),'Missing '..name)
    local o=c:get_class_default_object();assert(valid(o),'Missing default '..name);return o
end
local function load_material()
    local material=api:find_uobject(MATERIAL)
    if valid(material) then assert(material:get_full_name()==MATERIAL,'Unexpected material');return material end
    local c=api:find_uobject('Class /Script/AssetRegistry.AssetRegistryHelpers')
    local desc=api:find_uobject('ScriptStruct /Script/CoreUObject.AssetData')
    assert(valid(c) and valid(desc) and StructObject,'Material loading unavailable')
    desc=desc:as_struct();assert(valid(desc),'AssetData struct unavailable')
    local helpers=c:get_class_default_object()
    assert(valid(helpers) and c:find_function('GetAsset') and c:find_function('IsValid'),'AssetRegistry unavailable')
    local data=StructObject.new(desc)
    local path=MATERIAL:match('^MaterialInstanceConstant (.+)$')
    local package,name=path:match('^(.+)%.([^%.]+)$')
    local fields={ObjectPath=path,PackageName=package,PackagePath=package:match('^(.+)/[^/]+$'),
        AssetName=name,AssetClass='MaterialInstanceConstant'}
    for key,value in pairs(fields) do
        assert(desc:find_property(key),'Unsupported UE4 AssetData layout')
        data:set_property(key,fname(value))
    end
    assert(helpers:IsValid(data),'Material AssetData rejected')
    material=helpers:GetAsset(data)
    assert(valid(material) and material:get_full_name()==MATERIAL,'Original BC material unavailable')
    return material
end
local function refresh_settings()
    local text=fs.read('hands3d.settings');if text==settings_text then return end
    local input={};for k,v in text:gmatch('([%a_]+)%s*=%s*([^\r\n]+)') do input[k]=tonumber(v) end
    settings={scale=1}
    for _,side in ipairs({'left','right'}) do
        for _,axis in ipairs({'x','y','z','pitch','yaw','roll'}) do settings[side..'_'..axis]=0 end
    end
    for key,fallback in pairs(settings) do
        local v=input[key]
        local limit=key:find('pitch') or key:find('yaw') or key:find('roll')
        local low,high=key=='scale' and .5 or (limit and -180 or -20),key=='scale' and 1.5 or (limit and 180 or 20)
        settings[key]=v and v==v and v>=low and v<=high and v or fallback
    end
    settings_text=text
end
local function quaternion(pitch,yaw,roll)
    local p,y,r=pitch*math.pi/180,-yaw*math.pi/180,-roll*math.pi/180
    local cp,sp,cy,sy,cr,sr=math.cos(p/2),math.sin(p/2),math.cos(y/2),math.sin(y/2),math.cos(r/2),math.sin(r/2)
    local q=UEVR_Quaternionf.new()
    q.w,q.x,q.y,q.z=cy*cp*cr+sy*sp*sr,cy*sp*cr+sy*cp*sr,sy*cp*cr-cy*sp*sr,cy*cp*sr-sy*sp*cr
    return q
end
local function multiply(a,b)
    local q=UEVR_Quaternionf.new()
    q.w=a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z
    q.x=a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y
    q.y=a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x
    q.z=a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w
    return q
end
local function weapon_frame(hand)
    local text=fs.read(hand==0 and 'chainsword3d.settings' or 'bolter3d.settings')
    local values={}
    -- Match each weapon module's line parser, defaults and calibration bounds.
    for _,key in ipairs({'x','y','z','pitch','yaw','roll'}) do
        local v=tonumber(('\n'..text):match('\n'..key..'=([^\r\n]+)'))
        local limit=(key=='x' or key=='y' or key=='z') and (hand==0 and 30 or 60) or 180
        values[key]=v and v==v and v>=-limit and v<=limit and v or 0
    end
    -- bolter3d offsets are (x+s*grip_z,y-s*grip_x,z-s*grip_y).
    -- Its UE mesh-local grip cancels those scale terms exactly under UEVR's
    -- GLM->UE (y,z,-x) conversion. All arsenal profiles share this grip frame;
    -- copying their mesh-origin offsets would put the hand beside the weapon.
    -- chainsword3d is already authored about its grip, so uses (x,y,z) directly.
    return values,quaternion(values.pitch,values.yaw,values.roll)
end
local function attach(o, hand)
    local side=hand==0 and 'left_' or 'right_'
    local state=hook.get_or_add_motion_controller_state(o);assert(state,'Controller attachment unavailable')
    local base,weapon=weapon_frame(hand)
    local trim=quaternion(settings[side..'pitch'],settings[side..'yaw'],settings[side..'roll'])
    -- UEVR renders H * inverse(offset). A local trim therefore pre-multiplies
    -- the weapon offset. Rotate the base translation into the trimmed frame
    -- so adding a hand rotation never rotates the weapon's calibrated grip.
    local v=multiply(multiply(trim,{w=0,x=base.x,y=base.y,z=base.z}),
        {w=trim.w,x=-trim.x,y=-trim.y,z=-trim.z})
    local location=UEVR_Vector3f.new()
    location.x,location.y,location.z=v.x+settings[side..'x'],v.y+settings[side..'y'],v.z+settings[side..'z']
    local q=multiply(trim,weapon)
    state:set_hand(hand);state:set_permanent(false)
    state:set_location_offset(location);state:set_rotation_offset(q)
    o:SetRelativeScale3D({X=settings.scale,Y=settings.scale,Z=settings.scale})
end
local function load_texture(rendering,pawn)
    -- Atlas contract: native writes this absolute hint after submitting geometry.
    -- PNG RGB(A) is baked sRGB blue armor / black glove / gold trim, opaque alpha,
    -- UV0 in [0,1] (left/right share atlas). No vertex-color or tint multiplier:
    -- installed MI_Pickups_Boltgun metadata is MSM_Unlit, BC, Colors={}.
    -- Keep reticle's legacy 1x1 white palette separate from the hand atlas.
    local path=fs.read('hands3d.texture_path'):gsub('\\','/')
    assert(path:match('^%a:/') and path:sub(-#'/data/hands3d/hands_color.png')=='/data/hands3d/hands_color.png' and
        not path:find('[%c]') and not ('/'..path..'/'):find('/%.%./') and
        not ('/'..path..'/'):find('/%./'), 'Native hand atlas path unavailable')
    local texture=rendering:ImportFileAsTexture2D(pawn,path)
    assert(valid(texture) and texture:get_class():get_full_name()=='Class /Script/Engine.Texture2D',
        'Hand atlas import failed')
    local class=texture:get_class()
    assert(class:find_function('Blueprint_GetSizeX') and class:find_function('Blueprint_GetSizeY'),
        'Hand atlas dimensions unavailable')
    local w,h=texture:Blueprint_GetSizeX(),texture:Blueprint_GetSizeY()
    assert(w>0 and h>0 and w*h>1,'Hand atlas is empty or the obsolete 1x1 white placeholder')
    return texture
end
local function create(pawn)
    local class=api:find_uobject(CLASS);assert(valid(class),'ProceduralMeshComponent unavailable')
    for _,name in ipairs({'SetHiddenInGame','SetVisibility','SetCollisionEnabled','SetGenerateOverlapEvents',
        'SetMobility','SetCastShadow','SetOwnerNoSee','SetOnlyOwnerSee','CreateDynamicMaterialInstance',
        'SetRelativeScale3D','K2_DestroyComponent','GetNumSections'}) do
        assert(class:find_function(name),'Required hand function unavailable: '..name)
    end
    local material=load_material()
    local rendering=library('KismetRenderingLibrary')
    assert(rendering:get_class():find_function('ImportFileAsTexture2D'),'Texture import unavailable')
    local texture
    for hand=0,1 do
        local o=api:add_component_by_class(pawn,class,false)
        assert(valid(o) and o:get_outer()==pawn and o:get_class():get_full_name()==CLASS,'Hand allocation ownership failed')
        local r={kind='mesh',owner=identity(pawn),item=identity(o),hidden=true,visible=false}
        records[#records+1]=r;hands[#hands+1]=r
        o:SetHiddenInGame(true,false);o:SetVisibility(false,false)
        journal()
        o:SetCollisionEnabled(0);o:SetGenerateOverlapEvents(false);o:SetMobility(2)
        o:SetCastShadow(false);o:SetOwnerNoSee(false);o:SetOnlyOwnerSee(false)
        assert(o:GetNumSections()==0,'New hand has unexpected geometry')
        assert(functions.dispatch_custom_event,'Native hand bridge unavailable')
        functions.dispatch_custom_event('boltgun.hands.v1',r.owner.address..'|'..r.item.address..'|'..hand)
        assert(o:GetNumSections()==1,'Native bridge did not submit hand geometry')
        if not texture then
            texture=load_texture(rendering,pawn)
        end
        local dmi=o:CreateDynamicMaterialInstance(0,material,fname('BoltgunHands3D'))
        assert(valid(dmi) and dmi:get_class():find_function('SetTextureParameterValue') and
            dmi:get_class():find_function('K2_GetTextureParameterValue'),'Hand material unavailable')
        dmi:SetTextureParameterValue(fname('BC'),texture)
        assert(dmi:K2_GetTextureParameterValue(fname('BC'))==texture,'Hand palette binding failed')
        attach(o,hand)
    end
    report('Gauntlets attached in weapon grip frames with BC color atlas; VR validation pending')
end
local function step()
    if not recovered then recover();if not recovered then return end end
    local engine=api:get_engine();if not valid(engine) then return end
    if not session then session=identity(engine) end
    assert(same(session),'Engine identity changed')
    refresh_settings()
    local pawn=api:get_local_pawn(0)
    if player(pawn) then last_player=identity(pawn) end
    local ready=vr.is_runtime_ready() and vr.is_hmd_active() and vr.is_using_controllers() and
        not functions.is_drawing_ui()
    update_death(pawn,ready and fs.read('hands3d.death_arms')~='off')
    local alive=player(pawn) and prop(pawn,'bPlayerFinishedLevelLoad')==true and
        pawn:get_class():find_function('IsDead') and pawn:IsDead()==false
    local show=ready and alive and vr.is_aim_allowed() and fs.read('hands3d.mode')~='off'
    if show then
        local controller=api:get_player_controller(0)
        show=valid(controller) and library('GameplayStatics'):IsGamePaused(controller)==false
        local menu=prop(prop(controller,'MyHUD'),'CurrentMenu')
        if valid(menu) and menu:IsInViewport()~=false and menu:IsVisible()~=false then show=false end
    end
    if #hands>0 and (not same(hands[1].owner) or hands[1].owner.object~=pawn) then remove_records(true) end
    for _,r in ipairs(hands) do
        if not verified(r) then remove_records(true);break end
    end
    warmup=warmup+1
    if show and #hands==0 and not hands_failed and warmup>2 then
        local ok,err=pcall(create,pawn)
        if not ok then
            hands_failed=true;remove_records(true)
            report('Gauntlets unavailable: '..tostring(err)..'; death-arm comfort remains active')
        end
    end
    for n,r in ipairs(hands) do
        attach(r.item.object,n-1)
        r.item.object:SetVisibility(show,false);r.item.object:SetHiddenInGame(not show,false)
    end
end
callbacks.on_pre_engine_tick(function()
    if stopped then return end
    local ok,err=pcall(step)
    if not ok then
        -- Attempt every known hand even when one identity has become foreign.
        for _,r in ipairs(hands) do pcall(function()
            if verified(r) then r.item.object:SetHiddenInGame(true,false);r.item.object:SetVisibility(false,false) end
        end) end
        stopped=true;report('Stopped; ownership journal retained for recovery: '..tostring(err))
    end
end)
callbacks.on_script_reset(function()
    stopped=true -- Scalars only; the next instance recovers on a known engine tick.
end)
