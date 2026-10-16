-- External Kaiser-E chainsword. All Unreal mutations occur on the engine tick.
-- Requires the procedural bridge and data/chainsword3d assets. Sprite fallback
-- stays intact until geometry, material and controller attachment are verified.
local api, hook, vr = uevr.api, uevr.types.UObjectHook, uevr.params.vr
local MODE, SETTINGS, JOURNAL = 'chainsword3d.mode', 'chainsword3d.settings', 'chainsword3d.owned'
local CLASS = 'Class /Script/ProceduralMeshComponent.ProceduralMeshComponent'
local PLANE_CLASS = 'Class /Script/Engine.StaticMeshComponent'
local MATERIAL = 'MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun'
local function texture_path()
    -- The native bridge resolves the active profile with the UEVR C API and
    -- writes this hint into the same persistent data folder used by fs.read.
    -- UEVR's Lua functions table does not expose get_persistent_dir.
    local path = fs.read('chainsword3d.texture_path')
    assert(type(path) == 'string', 'Native texture path unavailable')
    path = path:gsub('\\', '/')
    assert(path:match('^%a:/') and
        path:sub(-#'/data/chainsword3d/chainsword_color.png') == '/data/chainsword3d/chainsword_color.png' and
        not path:find('[\r\n]'), 'Native texture path unavailable')
    return path
end
local required = {'SetHiddenInGame','SetVisibility','SetCollisionEnabled','SetGenerateOverlapEvents',
    'SetMobility','SetCastShadow','SetOwnerNoSee','SetOnlyOwnerSee','CreateDynamicMaterialInstance',
    'SetRelativeScale3D','K2_DestroyComponent','GetNumSections','GetMaterial'}
local defaults = {scale=1,x=0,y=0,z=0,pitch=0,yaw=0,roll=0,book_scale=.65,book_enabled=1}
local limits = {scale={.3,1.5},x={-30,30},y={-30,30},z={-30,30},
    pitch={-180,180},yaw={-180,180},roll={-180,180},book_scale={.35,1},book_enabled={0,1}}
local owned, owner, applied, sprite_state
local owner_name, owner_address, component_identity
local waiting_for_pawn = {} -- Private sentinel for a recoverable travel interval.
local suppressed, stopped, recovered = false, false, false
local mode, settings_text, settings, timer, retry_timer = 'off','',{},0,1
local last_report
local name_cache = {}
local warmup_ticks = 0
local BOOK_JOURNAL = 'chainsword3d.book'
local book_state, book_recovered = nil, false
local function report(text)
    if text == last_report then return end
    last_report = text
    uevr.params.functions.log_info('[Boltgun Chainsword 3D] ' .. text)
end
local function valid(object) return object ~= nil and hook.exists(object) end

local function reference(object, field)
    if not valid(object) then return nil end
    local class = object:get_class()
    if not valid(class) or class:find_property(field) == nil then return nil end
    return object:get_property(field)
end

local function clear_journal()
    fs.write(JOURNAL, '')
    assert(fs.read(JOURNAL) == '', 'Ownership journal could not be cleared')
end

local function snapshot_sprite(pawn)
    local renderer = reference(pawn, 'WeaponRenderer')
    assert(valid(renderer) and renderer:get_outer() == pawn, 'Weapon renderer ownership unavailable')
    local plane = reference(renderer, 'SecondaryRenderPlane')
    assert(valid(plane) and plane:get_outer() == renderer, 'Secondary sprite ownership unavailable')
    assert(plane:get_short_name() == 'Secondary Render Plane' and
        plane:get_class():get_full_name() == PLANE_CLASS, 'Unexpected primary sprite component')
    local hidden, visible = reference(plane, 'bHiddenInGame'), reference(plane, 'bVisible')
    assert(type(hidden) == 'boolean' and type(visible) == 'boolean', 'Sprite visibility unavailable')
    return {plane=plane,renderer=renderer,hidden=hidden,visible=visible,
        name=plane:get_full_name(),address=tostring(plane:get_address())}
end

local function check_sprite()
    local s = sprite_state
    if not s or not valid(s.plane) then return false end
    if s.plane:get_full_name() ~= s.name or tostring(s.plane:get_address()) ~= s.address then
        return false -- Map travel can rename still-valid objects awaiting teardown.
    end
    if reference(owner, 'WeaponRenderer') ~= s.renderer or
        reference(s.renderer, 'SecondaryRenderPlane') ~= s.plane then return false end
    assert(valid(s.renderer) and s.plane:get_outer() == s.renderer and
        s.renderer:get_outer() == owner, 'Secondary sprite owner changed')
    return true
end

local function hide_sprite()
    assert(check_sprite(), 'Secondary sprite expired')
    local plane = sprite_state.plane
    if reference(plane, 'bHiddenInGame') ~= true then plane:SetHiddenInGame(true, false) end
    if reference(plane, 'bVisible') ~= false then plane:SetVisibility(false, false) end
end

local function restore_sprite()
    if check_sprite() and valid(owner) then
        sprite_state.plane:SetHiddenInGame(sprite_state.hidden, false)
        sprite_state.plane:SetVisibility(sprite_state.visible, false)
    end
end

local function plane_scale(plane)
    local value = reference(plane,'RelativeScale3D')
    if value == nil then return nil end
    -- FVector bindings use x/y/z; reflected fallback structs expose X/Y/Z.
    local ok,x,y,z = pcall(function() return value.x,value.y,value.z end)
    if not ok or type(x) ~= 'number' then
        ok,x,y,z = pcall(function() return value:get_property('X'),value:get_property('Y'),value:get_property('Z') end)
    end
    if not ok then return nil end
    for _,n in ipairs({x,y,z}) do
        if type(n) ~= 'number' or n ~= n or math.abs(n) < .00001 or math.abs(n) > 10000 then return nil end
    end
    if x == nil or y == nil or z == nil then return nil end
    return {x,y,z}
end
local function same_scale(a,b)
    if a == nil or b == nil then return false end
    -- Unreal stores FVector as float32; large sprite scales round on write.
    -- Use a relative tolerance so that rounding is never a new authored size.
    for n=1,3 do
        if math.abs(a[n]-b[n])>math.max(.00001,math.abs(b[n])*.000001) then return false end
    end
    return true
end
local function set_plane_scale(plane,scale)
    plane:SetRelativeScale3D({X=scale[1],Y=scale[2],Z=scale[3]})
end
local function clear_book()
    fs.write(BOOK_JOURNAL,'')
    assert(fs.read(BOOK_JOURNAL)=='','Book journal could not be cleared')
    book_state=nil
end
local function restore_book()
    if not book_state then return end
    if check_sprite() and valid(owner) and same_scale(plane_scale(sprite_state.plane),book_state.applied) then
        set_plane_scale(sprite_state.plane,book_state.original)
    end
    clear_book()
end
local function recover_book()
    local text=fs.read(BOOK_JOURNAL)
    if text=='' then book_recovered=true;return end
    local f={};for value in text:gmatch('[^\r\n]+') do f[#f+1]=value end
    assert(#f==13 and f[1]=='v1','Invalid book scale journal')
    local engine=api:get_engine()
    if not valid(engine) then return end
    if tostring(engine:get_address())~=f[2] then clear_book();book_recovered=true;return end
    local pawn=api:find_uobject(f[4])
    if not valid(pawn) then clear_book();book_recovered=true;return end
    assert(tostring(pawn:get_address())==f[3],'Book pawn identity changed')
    local s=snapshot_sprite(pawn)
    assert(s.address==f[5] and s.name==f[6] and tostring(s.renderer:get_address())==f[7],
        'Book plane identity changed')
    local original,applied={},{}
    for n=1,3 do
        original[n],applied[n]=tonumber(f[7+n]),tonumber(f[10+n])
        for _,v in ipairs({original[n],applied[n]}) do
            assert(v and v==v and math.abs(v)>.00001 and math.abs(v)<=10000,'Invalid book scale')
        end
        assert(original[n] and applied[n],'Missing book scale')
    end
    if same_scale(plane_scale(s.plane),applied) then set_plane_scale(s.plane,original) end
    clear_book();book_recovered=true
end
local function update_book(is_book)
    if not is_book or settings.book_enabled~=1 or settings.book_scale==1 then restore_book();return end
    if not check_sprite() or not sprite_state.plane:get_class():find_function('SetRelativeScale3D') then return end
    local current=plane_scale(sprite_state.plane)
    if not current then restore_book();return end
    local original=book_state and same_scale(current,book_state.applied) and book_state.original or current
    local applied={original[1]*settings.book_scale,original[2]*settings.book_scale,original[3]*settings.book_scale}
    if same_scale(current,applied) then return end
    if not book_state or not same_scale(original,book_state.original) or not same_scale(applied,book_state.applied) then
        local engine=api:get_engine();assert(valid(engine),'Book engine unavailable')
        local f={'v1',tostring(engine:get_address()),tostring(owner:get_address()),owner:get_full_name(),
            sprite_state.address,sprite_state.name,tostring(sprite_state.renderer:get_address())}
        for _,v in ipairs(original) do f[#f+1]=string.format('%.9g',v) end
        for _,v in ipairs(applied) do f[#f+1]=string.format('%.9g',v) end
        local text=table.concat(f,'\n')
        fs.write(BOOK_JOURNAL,text);assert(fs.read(BOOK_JOURNAL)==text,'Book journal unavailable')
        book_state={original=original,applied=applied}
    end
    set_plane_scale(sprite_state.plane,applied)
end

local function remember_component()
    if valid(owned) then
        component_identity = {name=owned:get_full_name(),address=tostring(owned:get_address())}
    end
end

local function current_component()
    if not valid(owned) then return false end
    if component_identity == nil then return true end -- Partial allocation; cleanup checks ownership.
    local class = owned:get_class()
    return valid(class) and class:get_full_name() == CLASS and
        owned:get_full_name() == component_identity.name and
        tostring(owned:get_address()) == component_identity.address
end

local function cleanup()
    -- Live wrappers can now refer to renamed/reused objects after travel.
    -- Never mutate them through the previous ownership snapshot.
    local owner_replaced = valid(owner) and owner_name ~= nil and
        (owner:get_full_name() ~= owner_name or tostring(owner:get_address()) ~= owner_address)
    if not owner_replaced then restore_book()
    elseif book_state then clear_book() end
    local foreign_retained = false
    if not owner_replaced and current_component() then
        local actual_owner = owned:get_outer()
        if not valid(actual_owner) or actual_owner == owner then
            owned:SetHiddenInGame(true, false)
            owned:SetVisibility(false, false)
            hook.remove_motion_controller_state(owned)
        else
            foreign_retained = true
            report('Preview owner changed; foreign component retained')
        end
    end
    if suppressed then
        if not owner_replaced then restore_sprite() end
        suppressed = false
    end
    if not owner_replaced and current_component() then
        if valid(owner) and owned:get_outer() == owner then
            owned:K2_DestroyComponent(owner)
        else
            -- Actor destruction owns its component teardown. Never call a stale owner.
            report('Owner expired; detached visual awaits actor teardown')
        end
    end
    if foreign_retained then
        local next_pawn = api:get_local_pawn(0)
        if valid(next_pawn) and next_pawn ~= owner then
            -- A distinct live pawn starts a new ownership scope. Retain the old
            -- record for diagnostics without touching the foreign component.
            local previous = fs.read(JOURNAL)
            fs.write('chainsword3d.retired', previous)
            assert(fs.read('chainsword3d.retired') == previous, 'Previous ownership record could not be retained')
            report('Previous pawn replaced; stale ownership retired, rebuilding chainsword')
        elseif not valid(owner) then
            report('Waiting for new pawn before retiring previous chainsword ownership')
            error(waiting_for_pawn)
        else
            error('Foreign component retained; ownership journal preserved')
        end
    end
    owned, owner, applied = nil, nil, nil
    sprite_state = nil
    owner_name, owner_address, component_identity = nil, nil, nil
    clear_journal()
end

local function recover()
    local text = fs.read(JOURNAL)
    if text == '' then recovered = true; return end
    local fields = {}
    for value in text:gmatch('[^\r\n]+') do fields[#fields+1] = value end
    local v1 = #fields == 6 and fields[1] == 'v1'
    local v2 = #fields == 11 and fields[1] == 'v2'
    assert(v1 or v2, 'Invalid ownership journal; refusing a duplicate visual')
    if v2 then
        assert((fields[10] == 'true' or fields[10] == 'false') and
            (fields[11] == 'true' or fields[11] == 'false'), 'Invalid sprite visibility journal')
    end
    local engine = api:get_engine()
    if not valid(engine) then return end -- Wait for a live engine before resolving ownership.
    if tostring(engine:get_address()) ~= fields[2] then
        clear_journal(); recovered = true; return -- Previous process/session: never touch its named objects.
    end
    local candidate = api:find_uobject(fields[6])
    local candidate_owner
    if valid(candidate) then
        assert(tostring(candidate:get_address()) == fields[4], 'Component identity changed')
        candidate_owner = candidate:get_outer()
        local class = candidate:get_class()
        assert(valid(class) and class:get_full_name() == CLASS, 'Journal is not a preview mesh component')
    elseif v2 then
        -- The preview may have been destroyed independently. Restore a hidden
        -- sprite only on the exact surviving pawn recorded in this session.
        candidate_owner = api:find_uobject(fields[5])
        if not valid(candidate_owner) then clear_journal(); recovered = true; return end
        candidate = nil
    else
        clear_journal(); recovered = true; return
    end
    assert(valid(candidate_owner) and tostring(candidate_owner:get_address()) == fields[3]
        and candidate_owner:get_full_name() == fields[5], 'Component owner identity changed')
    local recovered_sprite
    if v2 then
        recovered_sprite = snapshot_sprite(candidate_owner)
        assert(recovered_sprite.address == fields[7] and recovered_sprite.name == fields[8] and
            tostring(recovered_sprite.renderer:get_address()) == fields[9], 'Sprite recovery identity changed')
        recovered_sprite.hidden, recovered_sprite.visible = fields[10] == 'true', fields[11] == 'true'
    end
    owned, owner = candidate, candidate_owner
    owner_name, owner_address = fields[5], fields[3]
    remember_component()
    sprite_state = recovered_sprite
    suppressed = recovered_sprite ~= nil
    cleanup(); recovered = true
    report('Previous preview removed on engine tick')
end

local function load_material()
    local profile = {id="chainsword material",mesh=MATERIAL}
    local ok, result, reason = pcall(function()
        local class = api:find_uobject('Class /Script/AssetRegistry.AssetRegistryHelpers')
        local strings_class = api:find_uobject('Class /Script/Engine.KismetStringLibrary')
        local descriptor = api:find_uobject('ScriptStruct /Script/CoreUObject.AssetData')
        if not valid(class) or not valid(strings_class) or not valid(descriptor) then
            return nil, 'AssetRegistryHelpers, KismetStringLibrary or AssetData unavailable'
        end
        -- find_uobject auto-casts UClass only. ScriptStruct descriptors arrive
        -- as generic UObjects, which do not expose find_property in Lua.
        local desc = descriptor:as_struct()
        if not valid(desc) then return nil, 'AssetData descriptor could not be cast to UStruct' end
        if class:find_function('GetAsset') == nil or class:find_function('IsValid') == nil or
            strings_class:find_function('Conv_StringToName') == nil then
            return nil, 'AssetRegistry/FName functions unavailable'
        end
        -- Restrict this loader to the reflected UE4 AssetData layout. Do not
        -- guess offsets or synthesize UE5 AssetClassPath fields.
        local fields = {'ObjectPath','PackageName','PackagePath','AssetName','AssetClass'}
        for _, field in ipairs(fields) do
            if desc:find_property(field) == nil then
                return nil, 'UE4 AssetData field unavailable: ' .. field
            end
        end
        if StructObject == nil then return nil, 'StructObject API unavailable' end
        local helpers = class:get_class_default_object()
        local strings = strings_class:get_class_default_object()
        if not valid(helpers) or not valid(strings) then return nil, 'AssetRegistry/FName default object unavailable' end
        local path = profile.mesh:match('^MaterialInstanceConstant (.+)$')
        local package, name = path:match('^(.+)%.([^%.]+)$')
        assert(package ~= nil and name ~= nil, 'Invalid fixed mesh path')
        local data = StructObject.new(desc)
        assert(data ~= nil, 'AssetData allocation unavailable')
        local values = {ObjectPath=path,PackageName=package,
            PackagePath=package:match('^(.+)/[^/]+$'),AssetName=name,AssetClass='MaterialInstanceConstant'}
        -- Only FNames are populated. No dynamic strings, tags or asset arrays
        -- are shallow-copied between Lua and Unreal allocators.
        for _, field in ipairs(fields) do
            local fname = strings:Conv_StringToName(values[field])
            assert(fname ~= nil, 'FName conversion failed: ' .. field)
            data:set_property(field, fname)
        end
        if not helpers:IsValid(data) then return nil, 'AssetRegistry rejected AssetData' end
        report('AssetRegistry GetAsset requested: ' .. profile.id)
        local loaded = helpers:GetAsset(data)
        if not valid(loaded) then return nil, 'AssetRegistry GetAsset returned no mesh' end
        if loaded:get_full_name() ~= profile.mesh then
            return nil, 'Loader returned an unexpected object'
        end
        return loaded
    end)
    if not ok then
        report('Original mesh load raised a Lua/API error: ' .. tostring(result))
        return nil
    end
    if not valid(result) then
        report('Original mesh load unavailable: ' .. tostring(reason))
        return nil
    end
    report('Original mesh loaded via AssetRegistry GetAsset: ' .. profile.id)
    return result
end

local function refresh_settings()
    mode = fs.read(MODE):match('^%s*(.-)%s*$') == 'preview' and 'preview' or 'off'
    settings_text = fs.read(SETTINGS)
    for key, fallback in pairs(defaults) do
        local token = ('\n' .. settings_text):match('\n' .. key .. '=([^\r\n]+)')
        local value = tonumber(token)
        local range = limits[key]
        settings[key] = value and value == value and value >= range[1] and value <= range[2] and value or fallback
    end
end

local function apply_settings()
    owned:SetRelativeScale3D({X=settings.scale,Y=settings.scale,Z=settings.scale})
    local state = hook.get_or_add_motion_controller_state(owned)
    assert(state ~= nil, 'Left controller attachment unavailable')
    local location = UEVR_Vector3f.new()
    location.x,location.y,location.z = settings.x,settings.y,settings.z
    local pitch,yaw,roll = settings.pitch*math.pi/180,-settings.yaw*math.pi/180,-settings.roll*math.pi/180
    local cp,sp,cy,sy,cr,sr = math.cos(pitch/2),math.sin(pitch/2),math.cos(yaw/2),math.sin(yaw/2),math.cos(roll/2),math.sin(roll/2)
    local rotation = UEVR_Quaternionf.new()
    rotation.w,rotation.x = cy*cp*cr+sy*sp*sr,cy*sp*cr+sy*cp*sr
    rotation.y,rotation.z = sy*cp*cr-cy*sp*sr,cy*cp*sr-sy*sp*cr
    state:set_hand(0)
    state:set_permanent(false)
    state:set_location_offset(location)
    state:set_rotation_offset(rotation)
    applied = settings_text
end

local function fname(value)
    if name_cache[value] ~= nil then return name_cache[value] end
    local class = api:find_uobject('Class /Script/Engine.KismetStringLibrary')
    assert(valid(class) and class:find_function('Conv_StringToName'), 'FName library unavailable')
    local name = class:get_class_default_object():Conv_StringToName(value)
    assert(name ~= nil,'FName conversion unavailable')
    name_cache[value] = name
    return name
end

local function codex_material(name)
    for _,phase in ipairs({'Opening','Reading','PageTurn'}) do
        if name:find('/Game/Art/Animations/Player/Codex/'..phase..'/',1,true) then return true end
    end
    return false
end
local function sprite_kind()
    if not check_sprite() then return nil end
    local mat = sprite_state.plane:GetMaterial(0)
    for _=1,4 do
        if not valid(mat) then return nil end
        local name = mat:get_full_name()
        if name:find('/Game/Art/Animations/Weapons/Chainsword/',1,true) then return 'sword' end
        if codex_material(name) then return 'book' end
        local cls = mat:get_class()
        if cls:find_function('K2_GetTextureParameterValue') then
            local texture = mat:K2_GetTextureParameterValue(fname('BC'))
            if valid(texture) and texture:get_full_name():find('/Game/Art/Animations/Weapons/Chainsword/',1,true) then
                return 'sword'
            end
            if valid(texture) and codex_material(texture:get_full_name()) then return 'book' end
        end
        mat = reference(mat,'Parent')
    end
    return nil
end

local function update_visual()
    local kind=sprite_kind()
    local is_sword = kind=='sword'
    update_book(kind=='book')
    if is_sword then
        hide_sprite(); suppressed = true
    elseif suppressed then
        -- A new animation may already have set its own visibility this tick.
        -- Restore only while both flags still match our suppression values.
        if reference(sprite_state.plane,'bHiddenInGame') == true and reference(sprite_state.plane,'bVisible') == false then
            restore_sprite()
        end
        suppressed = false
    end
    local plane = sprite_state.plane
    local other_visible = not is_sword and reference(plane,'bHiddenInGame') == false and reference(plane,'bVisible') == true
    owned:SetVisibility(not other_visible,false)
    owned:SetHiddenInGame(other_visible,false)
end

local function create(pawn)
    local class = api:find_uobject(CLASS)
    assert(valid(class), 'ProceduralMeshComponent unavailable')
    for _, name in ipairs(required) do assert(class:find_function(name), 'Required function missing: '..name) end
    local engine = api:get_engine(); assert(valid(engine),'Engine unavailable')
    owner = pawn
    owner_name, owner_address = pawn:get_full_name(), tostring(pawn:get_address())
    sprite_state = snapshot_sprite(pawn)
    owned = api:add_component_by_class(pawn,class,false)
    remember_component()
    assert(valid(owned) and owned:get_outer()==pawn, 'Chainsword ownership failed')
    owned:SetHiddenInGame(true,false); owned:SetVisibility(false,false)
    owned:SetCollisionEnabled(0); owned:SetGenerateOverlapEvents(false)
    owned:SetMobility(2); owned:SetCastShadow(false)
    owned:SetOwnerNoSee(false); owned:SetOnlyOwnerSee(false)
    local journal = table.concat({'v2',tostring(engine:get_address()),tostring(pawn:get_address()),
        tostring(owned:get_address()),pawn:get_full_name(),owned:get_full_name(),
        sprite_state.address,sprite_state.name,tostring(sprite_state.renderer:get_address()),
        tostring(sprite_state.hidden),tostring(sprite_state.visible)},'\n')
    fs.write(JOURNAL,journal); assert(fs.read(JOURNAL)==journal,'Ownership journal unavailable')
    assert(owned:GetNumSections()==0,'New component contains unexpected sections')
    local dispatch = uevr.params.functions.dispatch_custom_event
    assert(dispatch ~= nil,'Procedural bridge event API unavailable')
    dispatch('boltgun.chainsword.v1',tostring(pawn:get_address())..'|'..tostring(owned:get_address()))
    assert(owned:GetNumSections()==1,'Procedural bridge did not create geometry; keeping original sword')
    local material = api:find_uobject(MATERIAL)
    if not valid(material) then material = load_material() end
    assert(valid(material) and material:get_full_name()==MATERIAL,'Original unlit material unavailable')
    local rendering_class = api:find_uobject('Class /Script/Engine.KismetRenderingLibrary')
    assert(valid(rendering_class) and rendering_class:find_function('ImportFileAsTexture2D'), 'Texture import unavailable')
    local rendering = rendering_class:get_class_default_object();assert(valid(rendering),'Texture library unavailable')
    local texture = rendering:ImportFileAsTexture2D(pawn,texture_path())
    assert(valid(texture),'Chainsword color texture failed to load')
    local dmi = owned:CreateDynamicMaterialInstance(0,material,fname('BoltgunChainsword3D'))
    assert(valid(dmi),'Owned material creation failed')
    dmi:SetTextureParameterValue(fname('BC'),texture)
    assert(dmi:K2_GetTextureParameterValue(fname('BC'))==texture,'Chainsword texture binding failed')
    apply_settings();update_visual()
    report('Kaiser-E chainsword attached to left controller; matching secondary sprites suppressed')
end

local function step(delta)
    if not book_recovered then recover_book();if not book_recovered then return end end
    if not recovered then recover(); if not recovered then return end end
    -- Let the native bridge observe two complete engine ticks before the first
    -- synchronous request, regardless of plugin/Lua callback registration order.
    if warmup_ticks < 2 then warmup_ticks=warmup_ticks+1;return end
    timer=timer+math.max(0,delta or 0);retry_timer=math.min(1,retry_timer+math.max(0,delta or 0))
    if timer>=.25 then refresh_settings();timer=0 end
    if mode~='preview' then if owned~=nil then cleanup() end;return end
    if not vr.is_hmd_active() or not vr.is_using_controllers() or uevr.params.functions.is_drawing_ui() then
        if owned~=nil then cleanup() end;return
    end
    local pawn=api:get_local_pawn(0)
    if not valid(pawn) then if owned~=nil then cleanup() end;return end
    if owned~=nil and (not current_component() or not valid(owner) or owner~=pawn) then cleanup() end
    if owned~=nil and valid(owner) and
        (owner:get_full_name()~=owner_name or tostring(owner:get_address())~=owner_address) then cleanup() end
    if owned~=nil and not check_sprite() then cleanup() end
    if owned~=nil and owned:get_outer()~=owner then
        cleanup()
        error('Preview owner changed; module disabled after restoring owned components')
    end
    if owned~=nil then
        if applied~=settings_text then apply_settings() end
        update_visual();return
    end
    if retry_timer<1 then return end
    retry_timer=0
    -- A live pawn can precede its renderer/secondary plane during loading.
    -- Wait for a complete ownership snapshot before allocating or importing.
    local sprite_ready = pcall(snapshot_sprite, pawn)
    if not sprite_ready then report('Waiting for new pawn weapon renderer');return end
    create(pawn)
end
uevr.params.sdk.callbacks.on_pre_engine_tick(function(engine,delta)
    if stopped then return end
    local ok,error=pcall(step,delta)
    if not ok then
        if error==waiting_for_pawn then return end
        local clean,detail=true,nil
        if owned~=nil then clean,detail=pcall(cleanup) end
        stopped=true
        report('Disabled after API error: '..tostring(error)..(clean and '' or ' | Cleanup pending: '..tostring(detail)))
    end
end)
uevr.params.sdk.callbacks.on_script_reset(function()
    stopped=true -- Next instance recovers verified journal on the engine tick.
end)
