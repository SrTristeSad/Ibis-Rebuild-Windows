"""Verifica arquitetura da montagem sem alterar o repositório de interface."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent


class IntegrationLayoutTest(unittest.TestCase):
    def test_stage_uses_original_interface(self):
        stage = ROOT / "build" / "lua-app"
        upstream = ROOT / "ui" / "Ibis-Lua"
        self.assertTrue((upstream / "main.lua").is_file())
        self.assertEqual((upstream / "src" / "model.lua").read_bytes(),
                         (stage / "src" / "model.lua").read_bytes())
        self.assertTrue((stage / "assets" / "icons" / "png").is_dir())

    def test_bridge_hooks(self):
        data = (ROOT / "build" / "lua-app" / "main.lua").read_text(encoding="utf-8")
        for snippet in ("Bridge.install(Model)", "Bridge.create(state,active_artwork_id,gallery)",
                        "Bridge.open(state,id)", "Bridge.draw(state,visual)",
                        "Bridge.mousepressed(", "Bridge.mousemoved(",
                        "Bridge.mousereleased(state,rx,ry,scale)",
                        "Bridge.undo()", "Bridge.redo()",
                        "Bridge.draw_gallery_thumbnail(",
                        "Bridge.draw_layer_thumbnail("):
            self.assertIn(snippet, data)
        self.assertIn("not color_dialog and not brush_search_active", data)
        self.assertIn("not state.modal and Bridge.keypressed(", data)

    def test_no_native_project_ffi(self):
        stage = ROOT / "build" / "lua-app"
        self.assertFalse((stage / "native.lua").exists())
        self.assertFalse((stage / "rebuild_core.dll").exists())
        engine = (stage / "lua_engine.lua").read_text(encoding="utf-8")
        self.assertNotIn("require('ffi')", engine)
        self.assertNotIn('require("ffi")', engine)
        self.assertIn("love.image.newImageData", engine)
        self.assertTrue((stage / "lua_selection.lua").is_file())
        selection = (stage / "lua_selection.lua").read_text(encoding="utf-8")
        self.assertIn("function Selection.all(", selection)
        self.assertIn("function Selection.invert(", selection)
        self.assertIn("function Selection.combine(", selection)
        self.assertIn("function Selection.morph(", selection)
        self.assertIn("function Selection.feather(", selection)
        self.assertIn("function Selection.coverage(", selection)
        self.assertIn("function Selection.is_soft(", selection)
        self.assertIn("function Selection.magic_wand(", selection)
        self.assertIn("function Engine.composite_pixel_source(", engine)
        self.assertIn("local source = Engine.composite_pixel_source(project, model, false).pixels", engine)
        self.assertIn("tolerance / 255 + TOLERANCE", selection)
        self.assertIn("x, y, tolerance, global_mode)", selection)
        self.assertIn('global_mode and "magic_wand_global"', selection)
        self.assertIn("lua_selection", engine)
        self.assertIn("function Engine.affine_selection(", engine)
        self.assertIn("Selection.coverage(selection, px, py)", engine)
        self.assertIn("Selection.coverage(selected, x, y)", engine)
        self.assertIn('operation == "flip_horizontal"', engine)
        self.assertIn('operation == "flip_vertical"', engine)
        self.assertIn("function Engine.preview_affine(", engine)
        self.assertIn("function Engine.begin_move_preview(", engine)
        self.assertIn("function Engine.update_move_preview(", engine)
        self.assertIn("function Engine.begin_affine_gpu_preview(", engine)
        self.assertIn("function Engine.update_affine_gpu_preview(", engine)
        self.assertTrue((stage / "lua_history.lua").is_file())
        self.assertTrue((stage / "lua_selection_history.lua").is_file())
        selection_history = (stage / "lua_selection_history.lua").read_text(encoding="utf-8")
        self.assertIn("function SelectionHistory.save(", selection_history)
        self.assertIn("function SelectionHistory.load(", selection_history)
        self.assertIn("function SelectionHistory.cleanup(", selection_history)
        self.assertIn("selection_history.tsv", selection_history)
        bridge = (stage / "lua_bridge.lua").read_text(encoding="utf-8")
        self.assertIn("Bridge.selection_command(", bridge)
        self.assertIn("rotate_cw", bridge)
        self.assertIn("scale_half", bridge)
        self.assertIn('"flip_horizontal"', bridge)
        self.assertIn('"flip_vertical"', bridge)
        self.assertIn('"invert_selection"', bridge)
        self.assertIn('"select_all"', bridge)
        self.assertIn('"expand_selection"', bridge)
        self.assertIn('"contract_selection"', bridge)
        self.assertIn('"feather_selection"', bridge)
        self.assertIn("function Bridge.wand_tolerance(", bridge)
        self.assertIn("function Bridge.adjust_wand_tolerance(", bridge)
        self.assertIn("function Bridge.wand_global(", bridge)
        self.assertIn("function Bridge.toggle_wand_global(", bridge)
        self.assertIn("function Bridge.wand_sample_all(", bridge)
        self.assertIn("function Bridge.toggle_wand_sample_all(", bridge)
        self.assertIn("Engine.composite_pixel_source(p, model, true)", bridge)
        self.assertIn('key == "t"', bridge)
        self.assertIn("p.wand_tolerance or 0", bridge)
        self.assertIn("p.wand_global or false", bridge)
        self.assertIn('project.wand_global and "1" or "0"', bridge)
        self.assertIn('project.wand_sample_all and "1" or "0"', bridge)
        self.assertIn("local stored_tolerance, stored_global, stored_sample_all = metadata:match(", bridge)
        self.assertIn("p.wand_global = stored_global ==", bridge)
        self.assertIn("p.wand_sample_all = stored_sample_all ==", bridge)
        self.assertIn("function Bridge.selection_undo(", bridge)
        self.assertIn("function Bridge.selection_redo(", bridge)
        self.assertIn("function Bridge.selection_history_snapshot(", bridge)
        self.assertIn("local MASK_HISTORY_STEPS = 8", bridge)
        self.assertIn("push_mask_state(mask_undo, before)", bridge)
        self.assertIn("Selection.feather(selection, 2)", bridge)
        self.assertIn("Selection.morph(selection,", bridge)
        self.assertIn("selection_merge_mode()", bridge)
        self.assertIn('Selection.combine(selection, mask,', bridge)
        self.assertIn("clipboard", bridge)
        self.assertIn("rotate_free", bridge)
        self.assertIn("scale_free", bridge)
        self.assertIn("Bridge.preview_snapshot", bridge)
        self.assertNotIn("Engine.preview_affine(", bridge)
        self.assertIn("Engine.begin_move_preview(", bridge)
        self.assertIn("Engine.update_move_preview(", bridge)
        self.assertIn("Engine.begin_affine_gpu_preview(", bridge)
        self.assertIn("Engine.update_affine_gpu_preview(", bridge)
        self.assertIn("History.load(", bridge)
        self.assertIn("History.save(", bridge)
        self.assertIn("SelectionHistory.load(", bridge)
        self.assertIn("SelectionHistory.save(", bridge)
        workflow = (ROOT / ".github" / "workflows" / "windows-x64.yml").read_text(
            encoding="utf-8")
        self.assertIn(
            "Copy-Item bridge/lua_selection_history.lua tests/lua_paint/",
            workflow)
        self.assertIn(
            "Copy-Item bridge/lua_selection_history.lua tests/lua_syntax/",
            workflow)



if __name__ == "__main__":
    unittest.main()
