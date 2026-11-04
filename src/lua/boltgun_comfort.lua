-- Exact native blood-border replacement using the game's radial postprocess.
-- Call step ONLY from post-engine tick. Construction and stop access no UObjects.
local M={runtimeVerified=false,verifiedInGame=false}
local JOURNAL='comfort.owned'
local CLASS='Class /Script/Engine.PostProcessComponent'
local MATERIAL='Material /Game/Materials/PostProcessing/PickUpMaterials/M_PP_PickUp_Flash.M_PP_PickUp_Flash'
local BLOOD_DATA='BlueprintGeneratedClass /Game/Data/UI/BP_UIScreenEffectManager_Blood_Data.BP_UIScreenEffectManager_Blood_Data_C'
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<1e9 end
function M.new(uevr)
    local api,hook,vr=uevr.api,uevr.types.UObjectHook,uevr.params.vr
    local state,recovered,gs=nil,false,nil
    local s={stopped=false}
    local function valid(o) return o~=nil and hook.exists(o) end
    local function prop(o,k)
        if valid(o) and o:get_class():find_property(k) then return o:get_property(k) end
    end
    local function record(o)
        return {object=o,name=o:get_full_name(),address=tostring(o:get_address())}
    end
    local function same(r)
        if not r or not valid(r.object) then return false end
        assert(r.object:get_full_name()==r.name and tostring(r.object:get_address())==r.address,
            'Comfort object identity changed')
        return true
    end
    local function save()
        local a={'v1',state.engine,state.owner.address,state.owner.name,state.part.address,state.part.name}
        for _,r in ipairs(state.widgets) do
            a[#a+1]=r.address;a[#a+1]=r.name;a[#a+1]=tostring(r.opacity)
        end
        local text=table.concat(a,'\n');fs.write(JOURNAL,text)
        assert(fs.read(JOURNAL)==text,'Comfort ownership journal unavailable')
    end
    local function clear()
        fs.write(JOURNAL,'');assert(fs.read(JOURNAL)=='','Comfort journal removal failed')
    end
    local function widget_class(r)
        return (r.name:match('^CanvasPanel .+%.WidgetTree%.CanvasPanel_Vignette_Low_Health$') and
                'Class /Script/UMG.CanvasPanel') or
            (r.name:match('^W_PlayerDamageScreenPulse_C .+%.WidgetTree%.W_PlayerDamageScreenPulse$') and
                'pulse') or
            (r.name:match('^W_ScreenEffect_System_C .+%.WidgetTree%.W_ScreenEffect_BloodManager$') and 'blood_system')
    end
    local function check_widgets()
        for _,r in ipairs(state.widgets) do
            if same(r) then
                local expected=assert(widget_class(r),'Unrecognized comfort widget journal')
                local data=expected=='blood_system' and prop(r.object,'ScreenEffectData') or nil
                assert(expected=='pulse' and r.object:get_full_name():match('^W_PlayerDamageScreenPulse_C ') or
                    expected=='blood_system' and r.object:get_full_name():match('^W_ScreenEffect_System_C ') and
                        valid(data) and data:get_full_name()==BLOOD_DATA or
                    r.object:get_class():get_full_name()==expected,'Comfort widget class changed')
            end
        end
    end
    local function cleanup()
        if not state then return end
        -- Validate every survivor before mutating anything; preserve the journal
        -- on name/address reuse or changed component ownership.
        if same(state.part) then
            assert(same(state.owner) and state.part.object:get_outer()==state.owner.object and
                state.part.object:get_class():get_full_name()==CLASS,'Comfort component owner changed')
        end
        check_widgets()
        if same(state.part) then state.part.object:set_property('bEnabled',false) end
        for _,r in ipairs(state.widgets) do
            if same(r) and r.object:GetRenderOpacity()==0 then r.object:SetRenderOpacity(r.opacity) end
        end
        if same(state.part) then state.part.object:K2_DestroyComponent(state.owner.object) end
        clear();state=nil
    end
    local function recover()
        local text=fs.read(JOURNAL)
        if text=='' then recovered=true;return true end
        assert(type(text)=='string','Comfort journal unavailable')
        local f={};for line in text:gmatch('[^\r\n]+') do f[#f+1]=line end
        assert(f[1]=='v1' and #f>=6 and #f<=15 and (#f-6)%3==0,'Invalid comfort journal')
        local engine=api:get_engine();if not valid(engine) then return false end
        if tostring(engine:get_address())~=f[2] then clear();recovered=true;return true end
        state={engine=f[2],owner={object=api:find_uobject(f[4]),address=f[3],name=f[4]},
            part={object=api:find_uobject(f[6]),address=f[5],name=f[6]},widgets={}}
        for i=7,#f,3 do
            local opacity=tonumber(f[i+2]);assert(finite(opacity) and opacity>=0 and opacity<=1,'Invalid comfort opacity')
            local r={object=api:find_uobject(f[i+1]),address=f[i],name=f[i+1],opacity=opacity}
            assert(widget_class(r),'Invalid comfort widget');state.widgets[#state.widgets+1]=r
        end
        cleanup();recovered=true;return true
    end
    local function library(name,package)
        local cls=api:find_uobject('Class /Script/'..(package or 'Engine')..'.'..name)
        assert(valid(cls),'Missing '..name)
        local o=cls:get_class_default_object();assert(valid(o),'Missing '..name..' default');return o
    end
    local names={}
    local function fname(text)
        if names[text]==nil then names[text]=library('KismetStringLibrary'):Conv_StringToName(text) end
        return names[text]
    end
    local function load_material()
        local material=api:find_uobject(MATERIAL)
        if valid(material) then return material end
        -- Same UE4 AssetData/FName loader as the arsenal. Never pass unsupported
        -- SoftObjectProperty inputs or copy arrays between Lua/UE allocators.
        local desc=api:find_uobject('ScriptStruct /Script/CoreUObject.AssetData')
        assert(valid(desc) and StructObject,'Missing UE4 AssetData loader');desc=desc:as_struct()
        local strings=library('KismetStringLibrary')
        local registry=library('AssetRegistryHelpers','AssetRegistry')
        local path=MATERIAL:match('^Material (.+)$')
        local package,name=path:match('^(.+)%.([^%.]+)$')
        local data=StructObject.new(desc)
        for k,v in pairs({ObjectPath=path,PackageName=package,PackagePath=package:match('^(.+)/[^/]+$'),
            AssetName=name,AssetClass='Material'}) do
            assert(desc:find_property(k),'Unsupported UE4 AssetData');data:set_property(k,strings:Conv_StringToName(v))
        end
        assert(registry:IsValid(data),'Invalid comfort AssetData')
        material=registry:GetAsset(data)
        assert(valid(material) and material:get_full_name()==MATERIAL,'Comfort material load failed')
        return material
    end
    local function effects(pc)
        local hud=pc:GetHUD()
        if not valid(hud) or not hud:get_full_name():match('^Gameplay_HUD_C ') or prop(hud,'PlayerOwner')~=pc then return nil end
        local root=prop(hud,'Player HUD Widget')
        if not valid(root) or not root:get_full_name():match('^Gameplay_HUD_UI_C ') or root:GetOwningPlayer()~=pc then return nil end
        local path=root:get_full_name():match('^[^ ]+ (.+)$')..'.WidgetTree.'
        local blood=prop(root,'CanvasPanel_Vignette_Low_Health')
        local pulse=prop(root,'W_PlayerDamageScreenPulse')
        if not valid(blood) or blood:get_class():get_full_name()~='Class /Script/UMG.CanvasPanel' or
            blood:get_full_name()~='CanvasPanel '..path..'CanvasPanel_Vignette_Low_Health' or
            not valid(pulse) or pulse:get_full_name()~='W_PlayerDamageScreenPulse_C '..path..'W_PlayerDamageScreenPulse' then return nil end
        local manager=prop(hud,'ScreenEffectInterfaceWidget')
        if not valid(manager) or not manager:get_full_name():match('^W_ScreenEffect_Manager_C ') or
            manager:GetOwningPlayer()~=pc then return nil end
        local splatter=prop(manager,'W_ScreenEffect_BloodManager')
        local manager_path=manager:get_full_name():match('^[^ ]+ (.+)$')..'.WidgetTree.W_ScreenEffect_BloodManager'
        local data=prop(splatter,'ScreenEffectData')
        if not valid(splatter) or splatter:get_full_name()~='W_ScreenEffect_System_C '..manager_path or
            not valid(data) or data:get_full_name()~=BLOOD_DATA then return nil end
        local active=false
        for _,effect in ipairs(prop(splatter,'ActiveEffects') or {}) do
            if valid(effect) and effect:get_full_name():match('^W_ScreenEffect_Element_C ') and
                prop(effect,'IsActive')==true then active=true;break end
        end
        return {blood,pulse,splatter},pulse,active
    end
    local function scalar(mid,k,v)
        mid:SetScalarParameterValue(fname(k),v)
        local actual=mid:K2_GetScalarParameterValue(fname(k))
        assert(finite(actual) and math.abs(actual-v)<.00001,'Comfort scalar rejected: '..k)
    end
    local function step(pawn,enabled)
        if not recovered and not recover() then return end
        if not enabled or not valid(pawn) or api:get_local_pawn(0)~=pawn or
            not pawn:get_full_name():match('^BP_PlayerCharacter_Sternguard_C /Game/Maps/') or
            prop(pawn,'bPlayerFinishedLevelLoad')~=true or not vr.is_runtime_ready() or not vr.is_hmd_active() or
            uevr.params.functions.is_drawing_ui() then cleanup();return end
        local pc=api:get_player_controller(0);if not valid(pc) then cleanup();return end
        if not gs then gs=library('GameplayStatics') end
        local menu=prop(prop(pc,'MyHUD'),'CurrentMenu')
        if gs:IsGamePaused(pc)~=false or valid(menu) and menu:IsInViewport() and menu:IsVisible() then cleanup();return end
        local widgets,pulse,splatter_active=effects(pc)
        local health,damage,dead=prop(pawn,'CurrentHealth'),prop(pulse,'AccruedDamage'),pawn:IsDead()
        if not widgets or not finite(health) or health<0 or not finite(damage) or damage<0 or
            type(dead)~='boolean' then cleanup();return end
        if state and (not same(state.owner) or state.owner.object~=pawn or not same(state.part) or
            #state.widgets>0 and (state.widgets[1].object~=widgets[1] or state.widgets[2].object~=widgets[2] or
                state.widgets[3].object~=widgets[3])) then cleanup() end
        -- CurrentHealth and AccruedDamage are read only. The game's pulse decay
        -- supplies timing; no synthetic damage or arbitrary elapsed-time pulse.
        local strength=dead and 0 or math.min(.08,math.max(0,(35-health)/35)*.05+
            math.min(damage/30,1)*.03+(splatter_active and .02 or 0))
        if not state then
            local engine=api:get_engine();assert(valid(engine),'Missing comfort engine')
            local material=load_material()
            assert(prop(material,'MaterialDomain')==4,'Comfort shader is not postprocess')
            local cls=api:find_uobject(CLASS);assert(valid(cls),'Missing postprocess component')
            for _,fn in ipairs({'AddOrUpdateBlendable','K2_DestroyComponent'}) do assert(cls:find_function(fn),'Missing '..fn) end
            local mid=library('KismetMaterialLibrary'):CreateDynamicMaterialInstance(pawn,material,fname('None'),0)
            assert(valid(mid) and mid:get_class():get_full_name()=='Class /Script/Engine.MaterialInstanceDynamic',
                'Comfort material instance unavailable')
            scalar(mid,'STR',0)
            for _,k in ipairs({'Distort-X','Distort-Y','Distort_speedX','Distort_speedY','FG Dist Str','FG Dist Speed','Scroll X','Scroll Y'}) do scalar(mid,k,0) end
            for _,k in ipairs({'Tile X','Tile Y','FG Dist Tile','EmissivePower'}) do scalar(mid,k,1) end
            mid:SetVectorParameterValue(fname('Color'),{R=.35,G=0,B=0,A=1})
            local color=mid:K2_GetVectorParameterValue(fname('Color'))
            assert(color and finite(color.R) and finite(color.G) and finite(color.B) and finite(color.A) and
                math.abs(color.R-.35)<.00001 and color.G==0 and color.B==0 and color.A==1,'Comfort color rejected')
            local part=api:add_component_by_class(pawn,cls,false)
            assert(valid(part) and part:get_outer()==pawn and part:get_class():get_full_name()==CLASS,'Comfort component creation failed')
            state={engine=tostring(engine:get_address()),owner=record(pawn),part=record(part),mid=mid,widgets={}}
            -- New-component defaults may be enabled but contain no blendables.
            -- Persist ownership before adding this private material or hiding UI.
            save();part:set_property('bEnabled',false)
            part:set_property('bUnbound',true);part:set_property('BlendWeight',1);part:set_property('Priority',100)
            part:AddOrUpdateBlendable(mid,1)
            scalar(mid,'STR',strength)
            part:set_property('bEnabled',true)
            assert(prop(part,'bEnabled')==true and prop(part,'bUnbound')==true and prop(part,'BlendWeight')==1,
                'Comfort postprocess rejected')
            for _,widget in ipairs(widgets) do
                local r=record(widget);r.opacity=widget:GetRenderOpacity()
                assert(finite(r.opacity) and r.opacity>=0 and r.opacity<=1,'Invalid comfort widget opacity')
                state.widgets[#state.widgets+1]=r
            end
            save()
        else scalar(state.mid,'STR',strength) end
        for _,r in ipairs(state.widgets) do
            assert(same(r),'Comfort widget expired');r.object:SetRenderOpacity(0)
            assert(r.object:GetRenderOpacity()==0,'Comfort widget suppression rejected')
        end
    end
    function s:step(pawn,enabled)
        if self.stopped then return end
        local ok,err=pcall(step,pawn,enabled)
        if not ok then
            self.stopped=true
            local restored,reason=pcall(cleanup)
            uevr.params.functions.log_info('[Boltgun comfort] Disabled: '..tostring(err)..
                (restored and '' or '; recovery pending: '..tostring(reason)))
        end
    end
    function s:stop() self.stopped=true end -- Reset/unknown thread: next instance recovers on engine tick.
    return s
end
return M
