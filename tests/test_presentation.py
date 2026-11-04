"""UEVR script-loading boundary for the independent comfort bootstrap."""
import unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime

SCRIPT = Path(__file__).resolve().parents[1] / 'profile/scripts/boltgun_presentation.lua'


class PresentationTests(unittest.TestCase):
    def load(self, missing=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('''
            ctx={thread=false,steps=0,stops=0,loads=0,logs={}}
            fs={read=function(k)assert(ctx.thread);assert(k=='comfort.mode');return ctx.mode or '' end}
            pawn={}
            uevr={api={get_local_pawn=function(_,i)assert(ctx.thread and i==0);return pawn end},
                params={functions={log_info=function(v)ctx.logs[#ctx.logs+1]=v end},
                    sdk={callbacks={on_post_engine_tick=function(f)post=f end,
                        on_script_reset=function(f)reset=f end}}}}
            package.preload.boltgun_comfort=function()
                ctx.loads=ctx.loads+1
                return {new=function(api)
                    assert(api==uevr and not ctx.thread)
                    return {step=function(_,p,enabled)
                        assert(ctx.thread and p==pawn);ctx.steps=ctx.steps+1;ctx.enabled=enabled
                    end,stop=function()ctx.stops=ctx.stops+1 end}
                end}
            end
        ''')
        if missing:
            lua.execute("package.preload.boltgun_comfort=nil;package.path='';package.cpath=''")
        lua.execute(SCRIPT.read_text(encoding='utf-8'))
        return lua

    def test_resolves_module_during_load_and_uses_only_engine_callback(self):
        lua = self.load()
        self.assertEqual(lua.eval('ctx.loads'), 1)
        self.assertEqual(lua.eval('ctx.steps'), 0)
        lua.execute("package.path='';package.cpath='';ctx.thread=true;post();ctx.thread=false")
        self.assertEqual(lua.eval('ctx.steps'), 1)
        self.assertTrue(lua.eval('ctx.enabled'))

    def test_optional_off_and_reset_stop_future_engine_work(self):
        lua = self.load()
        lua.execute("ctx.mode='off';ctx.thread=true;post();ctx.thread=false;reset()")
        self.assertFalse(lua.eval('ctx.enabled'))
        self.assertEqual(lua.eval('ctx.stops'), 1)
        lua.execute('post()')  # Access outside engine tick would fail if reset did not stop it.
        self.assertEqual(lua.eval('ctx.steps'), 1)

    def test_missing_adapter_does_not_register_or_access_engine(self):
        lua = self.load(missing=True)
        self.assertIsNone(lua.eval('post'))
        self.assertIn('Comfort unavailable', lua.eval('ctx.logs[1]'))


if __name__ == '__main__':
    unittest.main()
