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
        keyboard_program = "return require('json').encode(require('tests.test_brush_keyboard').run())"
        keyboard = json.loads(state.execute(keyboard_program))
        assert keyboard.get('passed') and keyboard.get('assertions') >= 10
        opacity_program = "return require('json').encode(require('tests.test_layer_opacity_steps').run())"
        opacity_steps = json.loads(state.execute(opacity_program))
        assert opacity_steps.get('passed') and opacity_steps.get('assertions') == 11
        order_program = "return require('json').encode(require('tests.test_layer_order_controls').run())"
        order = json.loads(state.execute(order_program))
        assert order.get('passed') and order.get('assertions') == 10
        row_program = "return require('json').encode(require('tests.test_layer_row_visual').run())"
        row_visual = json.loads(state.execute(row_program))
        assert row_visual.get('passed') and row_visual.get('assertions') == 16
        desktop_program = "return require('json').encode(require('tests.test_desktop_layer_opacity').run())"
        desktop = json.loads(state.execute(desktop_program))
        assert desktop.get('passed') and desktop.get('assertions') >= 300
        wheel_program = "return require('json').encode(require('tests.test_layer_list_wheel').run())"
        wheel = json.loads(state.execute(wheel_program))
        assert wheel.get('passed') and wheel.get('assertions') == 37
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
            workspace_program="return require('json').encode(require('tests.test_workspace_layout').run())"
            workspace=json.loads(native_state.execute(workspace_program))
            assert workspace.get('passed') and workspace.get('expanded_canvas') and workspace.get('focus_zoom_anchor')
            tool_program="return require('json').encode(require('tests.test_editor_tools').run())"
            tool_registry=json.loads(native_state.execute(tool_program))
            assert tool_registry.get('passed') and tool_registry.get('ordered_shortcuts') and tool_registry.get('no_reserved_shortcut_collision')
            icon_program="return require('json').encode(require('tests.test_ui_icons').run())"
            icons=json.loads(native_state.execute(icon_program))
            assert icons.get('passed') and icons.get('complete_glyph_registry') and icons.get('normalized_bounds')
            menus_program="return require('json').encode(require('tests.test_context_menus').run())"
            menus=json.loads(native_state.execute(menus_program))
            assert menus.get('passed') and menus.get('layer_commands') and menus.get('tool_commands') and menus.get('bounds_safe')
            brush_root=(output / ('brush-presets-' + str(time.time_ns()))).as_posix()
            brush_program=("return require('json').encode(require('tests.test_brush_presets').run(" + json.dumps(brush_root) + "))")
            brush_presets=json.loads(native_state.execute(brush_program))
            assert brush_presets.get('passed') and brush_presets.get('local_roundtrip') and brush_presets.get('legacy_library_preserved')
            sample_program="return require('json').encode(require('tests.test_brush_samples').run())"
            brush_samples=json.loads(native_state.execute(sample_program))
            assert brush_samples.get('passed') and brush_samples.get('exact_native_rgba') and brush_samples.get('filtered_keyboard_navigation')
            lab_program="return require('json').encode(require('tests.test_brush_lab').run())"
            brush_lab=json.loads(native_state.execute(lab_program))
            assert brush_lab.get('passed') and brush_lab.get('exact_native_rgba') and brush_lab.get('original_presets_unchanged') and brush_lab.get('geometry_safe')
            gallery_program="return require('json').encode(require('tests.test_gallery_ui').run())"
            gallery_visual=json.loads(native_state.execute(gallery_program))
            assert gallery_visual.get('passed') and gallery_visual.get('thumbnail_alpha') and gallery_visual.get('unicode_safe') and gallery_visual.get('vector_icons')
            visual38_program="return require('json').encode(require('tests.test_visual_hierarchy').run())"
            stage38_visual=json.loads(native_state.execute(visual38_program))
            assert stage38_visual.get('passed') and stage38_visual.get('layout_safe') and stage38_visual.get('tool_labels_readable') and stage38_visual.get('native_preview_area')
            layer_keys_program="return require('json').encode(require('tests.test_compact_layer_keys').run())"
            layer_keys=json.loads(native_state.execute(layer_keys_program))
            assert layer_keys.get('passed') and layer_keys.get('selection_bounds')
            sidebar_program="return require('json').encode(require('tests.test_sidebar_scroll').run())"
            small_sidebar=json.loads(native_state.execute(sidebar_program))
            assert small_sidebar.get('passed') and small_sidebar.get('small_960x640_safe') and small_sidebar.get('clipped_buttons_inert') and small_sidebar.get('virtual_sliders_reachable')
            compact40_program="return require('json').encode(require('tests.test_compact_inspector').run())"
            compact40=json.loads(native_state.execute(compact40_program))
            assert compact40.get('passed') and compact40.get('native_rgba_exact') and compact40.get('preview_in_bounds') and compact40.get('layer_name_not_overlapping')
            opacity41_program="return require('json').encode(require('tests.test_compact_layer_opacity').run())"
            opacity41=json.loads(native_state.execute(opacity41_program))
            assert opacity41.get('passed') and opacity41.get('one_percent_precision') and opacity41.get('button_hits_preserved') and opacity41.get('popup_960x640_safe')
            slider_program="return require('json').encode(require('tests.test_brush_sliders').run())"
            sliders=json.loads(native_state.execute(slider_program))
            assert sliders.get('passed') and sliders.get('one_percent_opacity') and sliders.get('panel_isolation')
            cursor_program="return require('json').encode(require('tests.test_brush_cursor').run())"
            cursor=json.loads(native_state.execute(cursor_program))
            assert cursor.get('passed') and cursor.get('native_pixel_equal') and cursor.get('scratch_only')
            compact_program="return require('json').encode(require('tests.test_compact_layout').run())"
            compact=json.loads(native_state.execute(compact_program))
            assert compact.get('passed') and compact.get('official_toolbar_order') and compact.get('canvas_and_toolbar_separated')
            visual_program="return require('json').encode(require('tests.test_compact_visual').run())"
            visual=json.loads(native_state.execute(visual_program))
            assert visual.get('passed') and visual.get('vector_icons') and visual.get('safe_quick_hitboxes') and visual.get('canvas_isolation')
            color_program="return require('json').encode(require('tests.test_color_brush_windows').run())"
            color_windows=json.loads(native_state.execute(color_program))
            assert color_windows.get('passed') and color_windows.get('hsb_rgb_roundtrip') and color_windows.get('palette_capacity') and color_windows.get('brush_filters')
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
            merge_root=(output / ('merge-down-' + str(time.time_ns()))).as_posix()
            merge_program=("return require('json').encode(require('tests.test_merge_down').run("
                           +json.dumps(merge_root)+"))")
            merged=json.loads(native_state.execute(merge_program))
            assert merged.get('passed') and merged.get('restores_both_sources') and merged.get('rbd2_roundtrip')
            flip_root=(output / ('layer-flip-' + str(time.time_ns()))).as_posix()
            flip_program=("return require('json').encode(require('tests.test_layer_flip').run("
                          +json.dumps(flip_root)+"))")
            flip=json.loads(native_state.execute(flip_program))
            assert flip.get('passed') and flip.get('exact_rgba') and flip.get('rbd2_roundtrip')
            clear_root=(output / ('layer-clear-' + str(time.time_ns()))).as_posix()
            clear_program=("return require('json').encode(require('tests.test_layer_clear').run("
                           +json.dumps(clear_root)+"))")
            cleared=json.loads(native_state.execute(clear_program))
            assert cleared.get('passed') and cleared.get('exact_rgba') and cleared.get('no_op_empty') and cleared.get('rbd2_roundtrip')

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
        report['focus_workspace'] = workspace
        report['editor_tool_registry'] = tool_registry
        report['editor_vector_icons'] = icons
        report['editor_context_menus'] = menus
        report['brush_library'] = brush_presets
        report['native_brush_catalogue_samples'] = brush_samples
        report['native_brush_lab_inspector'] = brush_lab
        report['gallery_visual_polish'] = gallery_visual
        report['stage38_visual_hierarchy'] = stage38_visual
        report['stage39_adaptive_sidebar'] = small_sidebar
        report['stage42_compact_layer_keys'] = layer_keys
        report['stage40_compact_brush_inspector'] = compact40
        report['stage41_layer_opacity'] = opacity41
        report['precision_brush_sliders'] = sliders
        report['native_brush_tip_cursor'] = cursor
        report['compact_workspace_layout'] = compact
        report['compact_visual_controls'] = visual
        report['color_brush_windows'] = color_windows
        report['native_layer_thumbnails'] = thumbs
        report['layer_metadata_properties'] = properties
        report['layer_duplicate'] = duplicate_result
        report['mixed_structural_history'] = structural
        report['mixed_property_history'] = property_history
        report['layer_merge_down'] = merged
        report['native_layer_flip'] = flip
        report['native_layer_clear'] = cleared
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
