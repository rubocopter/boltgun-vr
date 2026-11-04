-- Comfort presentation has an independent lifecycle from the firearm preview.
-- Resolve the profile dependency now: UEVR restores package.path after loading.
local callbacks=uevr.params.sdk.callbacks
local loaded,module=pcall(require,'boltgun_comfort')
local adapter
if loaded then
    local ok,result=pcall(module.new,uevr)
    if ok then adapter=result else module=result end
end
if not adapter then
    uevr.params.functions.log_info('[Boltgun presentation] Comfort unavailable: '..tostring(module))
    return
end
local stopped=false
callbacks.on_post_engine_tick(function()
    if stopped then return end
    local ok,err=pcall(function()
        adapter:step(uevr.api:get_local_pawn(0),fs.read('comfort.mode')~='off')
    end)
    if not ok then
        stopped=true;adapter:stop()
        uevr.params.functions.log_info('[Boltgun presentation] Comfort stopped: '..tostring(err))
    end
end)
callbacks.on_script_reset(function()
    stopped=true;adapter:stop() -- No UObject access on the reset/UI thread.
end)
