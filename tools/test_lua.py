"""Headless API/storage worker: no love.dll, SDL, window or graphics load."""
import argparse
import json
import pathlib
import sys
import time
from build import ROOT, BUILD, runtime
from lua_runtime import API, FORBIDDEN_GRAPHICS_ENTRYPOINTS, LuaState

def run_tests(runtime_path, output):
    report = {'ok': False, 'suite': 'headless-luajit', 'graphics_initialized': False,
              'android_runtime_compared': False}
    lifecycle = 0
    for _ in range(100):
        with LuaState(runtime_path) as state:
            assert state.execute("return tostring(6*7)") == '42'
            try:
                state.execute("error('intentional protected error')")
            except RuntimeError as error:
                assert 'intentional protected error' in str(error)
            else:
                raise AssertionError('Lua pcall failure was hidden')
            assert state.execute("return tostring(7*8)") == '56'
        assert state.close_succeeded and state.closed
        try:
            _ = state.pointer
        except RuntimeError:
            pass
        else:
            raise AssertionError('Use-after-close was not rejected')
        try:
            state.close()
        except RuntimeError:
            pass
        else:
            raise AssertionError('Double close was not rejected')
        lifecycle += 1
    with LuaState(runtime_path) as state:
        identity = state.execute("return _VERSION..'|'..jit.version..'|'..jit.arch..'|'..require('ffi').sizeof('void*')")
        assert identity.startswith('Lua 5.1|LuaJIT') and identity.endswith('|x64|8'), identity
        sources = sorted((ROOT / 'app').rglob('*.lua')) + sorted((ROOT / 'tests').glob('*.lua'))
        for source in sources:
            state.check_syntax(source)
        paths = (ROOT / 'app/?.lua').as_posix() + ';' + (ROOT / '?.lua').as_posix()
        program = ('package.path=' + json.dumps(paths) + "..';'..package.path; "
                   "return require('json').encode(require('tests.test_store').run("
                   + json.dumps((output / ('storage-' + str(time.time_ns()))).as_posix()) + '))')
        storage = json.loads(state.execute(program))
        assert storage.get('passed') and storage.get('assertions') == 52
    assert state.close_succeeded
    native_ffi = {'status': 'not-run', 'reason': 'compiled DLL absent; separate native suite must fail'}
    if (ROOT / 'build/rebuild_core.dll').is_file():
        with LuaState(runtime_path) as native_state:
            bridge = ("package.path=" + json.dumps(paths) + "..';'..package.path; "
                      "local n=require('native'); assert(n.load(" + json.dumps(ROOT.as_posix()) + "), table.concat(n.errors, '; ')); "
                      "local b=n.buffer(3,2); n.clear(b,0); n.pixel(b,2,1,0x123456FF); "
                      "assert(n.readPixel(b,2,1)==0x123456FF); "
                      "assert(n.pressure(0.5,true,0,1)==0.5); "
                      "local p=n.pack({{id=4,info=7,x=2,y=1,pressure=0.5,time=9,stylus=false}}); "
                      "assert(#p.ints==2 and #p.floats==7 and #p.times==1); "
                      "return require('json').encode({status='passed',abi=1,"
                      "pixel_roundtrip=true,sample_packing=true,ffi_path=n.path})")
            native_ffi = json.loads(native_state.execute(bridge))
        assert native_state.close_succeeded
    report['native_luajit_ffi'] = native_ffi
    report.update(ok=True, lua_identity=identity, lifecycle_cycles=lifecycle,
                  close_succeeded=True, syntax_checked=len(sources), storage=storage,
                  prototypes={name: {'result': getattr(result, '__name__', 'void') if result else 'void',
                                    'arguments': [getattr(a, '__name__', str(a)) for a in arguments]}
                              for name, (result, arguments) in API.items()},
                  graphics_entrypoints_not_called=FORBIDDEN_GRAPHICS_ENTRYPOINTS)
    return report

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime')
    parser.add_argument('--output')
    args = parser.parse_args()
    output = pathlib.Path(args.output) if args.output else BUILD / ('lua-' + str(time.time_ns()))
    output.mkdir(parents=True, exist_ok=True)
    try:
        report = run_tests(runtime(args.runtime), output)
    except Exception as error:
        report = {'ok': False, 'suite': 'headless-luajit', 'error': str(error),
                  'close_success_not_assumed': True}
    # Written after closing every VM. A close exception cannot leave ok:true.
    (output / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 0 if report['ok'] else 1

if __name__ == '__main__':
    sys.exit(main())
