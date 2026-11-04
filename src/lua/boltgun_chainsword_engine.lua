-- Reflected UE4 collision -> original Boltgun chainsword damage. Engine thread only.
-- Never manufacture a HitResult or write an enemy's health/death state.
local M = {}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
M.finite = finite
function M.new(uevr)
    local api,hook=uevr.api,uevr.types.UObjectHook
    local function valid(o) return o~=nil and hook.exists(o) end
    local function prop(o,k)
        if valid(o) and o:get_class():find_property(k) then return o:get_property(k) end
    end
    local function identity(o) return o:get_full_name()..':'..tostring(o:get_address()) end
    local function library(name)
        local c=api:find_uobject('Class /Script/Engine.'..name)
        assert(valid(c),'Missing '..name)
        local o=c:get_class_default_object();assert(valid(o),'Missing default '..name);return o
    end
    local gs,system=library('GameplayStatics'),library('KismetSystemLibrary')
    local enemy_class=api:find_uobject('Class /Script/Boltgun.BGNonPlayableCharacterBase')
    local vector=api:find_uobject('ScriptStruct /Script/CoreUObject.Vector')
    assert(valid(enemy_class) and valid(vector),'Missing collision descriptors')
    vector=vector:as_struct();assert(valid(vector),'Missing vector struct')
    local trace=assert(system:get_class():find_function('SphereTraceSingle'))
    local breaker=assert(gs:get_class():find_function('BreakHitResult'))
    local trace_fields={WorldContextObject=true,Start=true,End=true,Radius=true,TraceChannel=true,
        bTraceComplex=true,ActorsToIgnore=true,DrawDebugType=true,OutHit=true,bIgnoreSelf=true,
        TraceColor=true,TraceHitColor=true,DrawTime=true}
    local function params(fn,allowed)
        local names,seen={},{};local f=fn:get_child_properties()
        while f do
            local n=f:get_fname():to_string();local p=fn:find_property(n)
            if p and p:is_param() and not p:is_return_param() then
                assert(not seen[n] and (not allowed or allowed[n]),'Unsupported parameter '..n)
                if not allowed then assert(n=='Hit' or p:is_out_param(),'Unsupported hit input') end
                seen[n]=true;names[#names+1]=n
            end
            f=f:get_next()
        end
        if allowed then for n in pairs(allowed) do assert(seen[n],'Missing trace parameter '..n) end end
        return names,seen
    end
    local trace_names=params(trace,trace_fields)
    local break_names,break_fields=params(breaker)
    for _,k in ipairs({'Hit','HitActor','bBlockingHit','Time','ImpactPoint'}) do
        assert(break_fields[k],'Missing hit output '..k)
    end
    local s={}
    function s:context(pawn,component)
        if not valid(pawn) or api:get_local_pawn(0)~=pawn or not valid(component) or
            component:get_outer()~=pawn or prop(component,'bVisible')~=true or
            prop(component,'bHiddenInGame')~=false or not pawn:get_full_name():match(
            '^BP_PlayerCharacter_Sternguard_C /Game/Maps/[^ ]+%.PersistentLevel%.BP_PlayerCharacter_Sternguard_C_%d+$') or
            prop(pawn,'bPlayerFinishedLevelLoad')~=true or pawn:IsDead()~=false then return nil end
        local controller=api:get_player_controller(0)
        if not valid(controller) or gs:IsGamePaused(controller)~=false then return nil end
        local menu=prop(prop(controller,'MyHUD'),'CurrentMenu')
        if valid(menu) and (menu:IsInViewport()~=false and menu:IsVisible()~=false) then return nil end
        local handler=prop(pawn,'WeaponHandlerComponent')
        local weapon=prop(handler,'EquippedMeleeWeapon')
        if not valid(handler) or handler:get_outer()~=pawn or not valid(weapon) or
            not weapon:get_full_name():match('^BP_Chainsword_C ') or weapon:GetOwner()~=pawn or
            prop(weapon,'ChainswordCuttingTarget')~=nil then return nil end
        local engine=api:get_engine();if not valid(engine) then return nil end
        local damage_key=identity(engine)..'|'..identity(pawn)..'|'..identity(weapon)
        return {pawn=pawn,weapon=weapon,component=component,damage_key=damage_key,remaining_queries=512,
            key=damage_key..'|'..identity(component)}
    end
    local function decode(hit)
        local args,outs={},{}
        for _,n in ipairs(break_names) do
            if n=='Hit' then args[#args+1]=hit else local out={};args[#args+1]=out;outs[n]=out end
        end
        breaker(gs,table.unpack(args))
        local d={};for n,out in pairs(outs) do d[n]=out.result end;return d
    end
    local function vec(p)
        assert(finite(p.x) and finite(p.y) and finite(p.z),'Invalid trace vector')
        local v=StructObject.new(vector)
        v:set_property('X',p.x);v:set_property('Y',p.y);v:set_property('Z',p.z);return v
    end
    function s:cast(c,a,b,radius)
        -- Enumerate enemies only to discover blocking world geometry behind them.
        -- Missing actors, malformed hits or an exhausted budget reject the frame.
        local ignore={c.pawn,c.weapon};local hits={}
        if math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z)<.01 then
            b={x=b.x+.01,y=b.y,z=b.z}
        end
        for _=1,16 do
            assert(c.remaining_queries>0,'Blade trace budget exhausted')
            c.remaining_queries=c.remaining_queries-1
            local out={}
            local values={WorldContextObject=c.pawn,Start=vec(a),End=vec(b),Radius=radius,
                TraceChannel=0,bTraceComplex=false,ActorsToIgnore=ignore,DrawDebugType=0,OutHit=out,
                bIgnoreSelf=true,TraceColor={R=0,G=0,B=0,A=0},TraceHitColor={R=0,G=0,B=0,A=0},DrawTime=0}
            local args={};for _,n in ipairs(trace_names) do args[#args+1]=values[n] end
            if trace(system,table.unpack(args))~=true then return hits end
            local hit=assert(out.result,'Missing real HitResult');local d=decode(hit)
            local actor=d.HitActor
            assert(valid(actor) and actor~=c.pawn and actor~=c.weapon,'Invalid collision actor')
            assert(finite(d.Time) and d.Time>=0 and d.Time<=1,'Invalid collision time')
            local p=d.ImpactPoint
            assert(p and finite(p.X) and finite(p.Y) and finite(p.Z),'Invalid impact point')
            local enemy=actor:is_a(enemy_class)
            if d.bBlockingHit==true then
                hits[#hits+1]={actor=actor,key=identity(actor),wall=not enemy,hit=hit,
                    point={x=p.X,y=p.Y,z=p.Z},time=d.Time}
            end
            if not enemy then return hits end
            for _,o in ipairs(ignore) do assert(o~=actor,'Trace ignored actor returned again') end
            ignore[#ignore+1]=actor
        end
        error('Collision actor budget exhausted')
    end
    function s:apply(c,contact)
        local live=self:context(c.pawn,c.component)
        if not live or live.key~=c.key then return false end
        -- Re-decode the engine result at the mutation boundary. Caller flags cannot authorize damage.
        local d=decode(contact.hit);local target=d.HitActor
        if d.bBlockingHit~=true or not valid(target) or target~=contact.actor or
            identity(target)~=contact.key or not target:is_a(enemy_class) or target:IsDead()~=false then return false end
        local w=c.weapon;local wid=identity(w);local cls=w:get_class()
        for _,k in ipairs({'ChainswordCuttingTarget','ChainswordHit','CuttingDamage','StrikeDamage'}) do
            assert(cls:find_property(k),'Missing chainsword property '..k)
        end
        local tp=cls:find_property('ChainswordCuttingTarget')
        assert(tp:get_class():get_name()=='ObjectProperty','Unsupported target property')
        local deal=assert(cls:find_function('DealCuttingDamage'),'Missing original chainsword damage')
        assert(#params(deal,{})==0,'Unsupported damage parameters')
        local old_target=w:get_property('ChainswordCuttingTarget')
        local old_hit=w:get_property('ChainswordHit');local desc=old_hit:get_struct()
        assert(desc:get_full_name()=='ScriptStruct /Script/Engine.HitResult','Unsupported hit struct')
        local size=desc:get_properties_size()
        assert(finite(size) and size>0 and size<=256 and size%1==0,'Unsupported hit size')
        assert(contact.hit:get_struct()==desc,'Mismatched real hit struct')
        local saved=StructObject.new(desc)
        for i=0,size-1 do saved:write_byte(i,old_hit:read_byte(i)) end
        local original,strike=w:get_property('CuttingDamage'),w:get_property('StrikeDamage')
        assert(finite(original) and finite(strike) and strike>0 and strike<=original and original<=1000000,
            'Unsupported original damage')
        local ok,err=pcall(function()
            w:set_property('ChainswordHit',contact.hit)
            w:set_property('ChainswordCuttingTarget',target)
            w:set_property('CuttingDamage',strike)
            assert(w:get_property('ChainswordCuttingTarget')==target and w:get_property('CuttingDamage')==strike,
                'Temporary chainsword state rejected')
            w:DealCuttingDamage()
        end)
        -- Attempt EVERY restore even if another setter fails. Never touch a recycled UObject.
        assert(valid(w) and identity(w)==wid,'Weapon expired during damage; restoration unavailable')
        local failures={}
        for _,entry in ipairs({{'CuttingDamage',original},{'ChainswordCuttingTarget',old_target},{'ChainswordHit',saved}}) do
            local restored,detail=pcall(function() w:set_property(entry[1],entry[2]) end)
            if not restored then failures[#failures+1]=tostring(detail) end
        end
        assert(#failures==0,'Weapon restoration failed: '..table.concat(failures,'; '))
        assert(w:get_property('CuttingDamage')==original and w:get_property('ChainswordCuttingTarget')==old_target,
            'Weapon restoration rejected')
        local restored_hit=w:get_property('ChainswordHit')
        for i=0,size-1 do assert(restored_hit:read_byte(i)==saved:read_byte(i),'Hit restoration rejected') end
        if not ok then error(err) end
        return true
    end
    return s
end
return M
