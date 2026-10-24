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
            layer_root = (output / ('layer-storage-' + str(time.time_ns()))).as_posix()
            layer_program = ("return require('json').encode(require('tests.test_layers').run("
                             + json.dumps(layer_root) + "))")
            layers = json.loads(native_state.execute(layer_program))
            assert layers.get('passed') and layers.get('roundtrip') and layers.get('composite_native')
            editing_root = (output / ('edit-history-' + str(time.time_ns()))).as_posix()
            editing_program = ("return require('json').encode(require('tests.test_edit_history').run("
                               + json.dumps(editing_root) + "))")
            editing = json.loads(native_state.execute(editing_program))
            assert editing.get('passed') and editing.get('history_bounded')
            select_root=(output / ('selection-' + str(time.time_ns()))).as_posix()
            select_program=("return require('json').encode(require('tests.test_selection').run("
                            +json.dumps(select_root)+"))")
            selection=json.loads(native_state.execute(select_program))
            assert selection.get('passed') and selection.get('move_native') and selection.get('reopen')
            fill_root=(output / ('bucket-fill-' + str(time.time_ns()))).as_posix()
            fill_program=("return require('json').encode(require('tests.test_fill').run("
                          +json.dumps(fill_root)+"))")
            fill=json.loads(native_state.execute(fill_program))
            assert fill.get('passed') and fill.get('undo_redo') and fill.get('rbd2_roundtrip')
            shape_root=(output / ('native-shapes-' + str(time.time_ns()))).as_posix()
            shape_program=("return require('json').encode(require('tests.test_shapes').run("
                           +json.dumps(shape_root)+"))")
            shapes=json.loads(native_state.execute(shape_program))
            assert shapes.get('passed') and shapes.get('rectangle') and shapes.get('ellipse')
            colors_root=(output / ('colors-lines-' + str(time.time_ns()))).as_posix()
            colors_program=("return require('json').encode(require('tests.test_colors_lines').run("
                            +json.dumps(colors_root)+"))")
            color_lines=json.loads(native_state.execute(colors_program))
            assert color_lines.get('passed') and color_lines.get('line_cpp') and color_lines.get('hex_rgba')
            feather_root=(output / ('feather-brush-' + str(time.time_ns()))).as_posix()
            feather_program=("return require('json').encode(require('tests.test_soft_brush').run("
                             +json.dumps(feather_root)+"))")
            feather=json.loads(native_state.execute(feather_program))
            assert feather.get('passed') and feather.get('soft_edge') and feather.get('rbd2_roundtrip')
            stabilizer_root=(output / ('stroke-stabilizer-' + str(time.time_ns()))).as_posix()
            stabilizer_program=("return require('json').encode(require('tests.test_stabilizer').run("
                                +json.dumps(stabilizer_root)+"))")
            stabilizer=json.loads(native_state.execute(stabilizer_program))
            assert stabilizer.get('passed') and stabilizer.get('endpoint_exact') and stabilizer.get('rbd2_roundtrip')
            pressure_root=(output / ('touch-pressure-' + str(time.time_ns()))).as_posix()
            pressure_program=("return require('json').encode(require('tests.test_touch_pressure').run("
                              +json.dumps(pressure_root)+"))")
            pressure_result=json.loads(native_state.execute(pressure_program))
            assert pressure_result.get('passed') and pressure_result.get('touch_width') and pressure_result.get('rbd2_roundtrip')
            tilt_root=(output / ('tilt-brush-' + str(time.time_ns()))).as_posix()
            tilt_program=("return require('json').encode(require('tests.test_tilt_brush').run("
                          +json.dumps(tilt_root)+"))")
            tilt_brush=json.loads(native_state.execute(tilt_program))
            assert tilt_brush.get('passed') and tilt_brush.get('ellipse_orientation') and tilt_brush.get('rbd2_roundtrip')
            view_program="return require('json').encode(require('tests.test_canvas_view').run())"
            viewport=json.loads(native_state.execute(view_program))
            assert viewport.get('passed') and viewport.get('cursor_anchor') and viewport.get('bounds')
            tool_program="return require('json').encode(require('tests.test_editor_tools').run())"
            tool_registry=json.loads(native_state.execute(tool_program))
            assert tool_registry.get('passed') and tool_registry.get('ordered_shortcuts') and tool_registry.get('no_reserved_shortcut_collision')
            thumbnail_program="return require('json').encode(require('tests.test_layer_thumbnails').run())"
            thumbs=json.loads(native_state.execute(thumbnail_program))
            assert thumbs.get('passed') and thumbs.get('rgba_sampled') and thumbs.get('paged_layer_windows')
            properties_root=(output / ('layer-properties-' + str(time.time_ns()))).as_posix()
            properties_program=("return require('json').encode(require('tests.test_layer_properties').run("
                                +json.dumps(properties_root)+"))")
            properties=json.loads(native_state.execute(properties_program))
            assert properties.get('passed') and properties.get('utf8_name') and properties.get('rbd2_roundtrip')
            duplicate_root=(output / ('layer-duplicate-' + str(time.time_ns()))).as_posix()
            duplicate_program=("return require('json').encode(require('tests.test_layer_duplicate').run("
                               +json.dumps(duplicate_root)+"))")
            duplicate_result=json.loads(native_state.execute(duplicate_program))
            assert duplicate_result.get('passed') and duplicate_result.get('deep_rgba_copy') and duplicate_result.get('rbd2_roundtrip')
            structural_root=(output / ('mixed-history-' + str(time.time_ns()))).as_posix()
            structural_program=("return require('json').encode(require('tests.test_structural_history').run("
                                +json.dumps(structural_root)+"))")
            structural=json.loads(native_state.execute(structural_program))
            assert structural.get('passed') and structural.get('chronological_undo_redo') and structural.get('rbd2_roundtrip')
            property_root=(output / ('property-history-' + str(time.time_ns()))).as_posix()
            property_program=("return require('json').encode(require('tests.test_layer_property_history').run("
                              +json.dumps(property_root)+"))")
            property_history=json.loads(native_state.execute(property_program))
            assert property_history.get('passed') and property_history.get('mixed_chronology') and property_history.get('rbd2_roundtrip')

        assert native_state.close_succeeded
        report['native_layers'] = layers
        report['native_edit_history'] = editing
        report['native_selection'] = selection
        report['native_fill'] = fill
        report['native_shapes'] = shapes
        report['native_colors_lines'] = color_lines
        report['native_feather_brush'] = feather
        report['mouse_stabilizer'] = stabilizer
        report['touch_pressure'] = pressure_result
        report['native_tilt_brush'] = tilt_brush
        report['canvas_view'] = viewport
        report['editor_tool_registry'] = tool_registry
        report['native_layer_thumbnails'] = thumbs
        report['layer_metadata_properties'] = properties
        report['layer_duplicate'] = duplicate_result
        report['mixed_structural_history'] = structural
        report['mixed_property_history'] = property_history
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
