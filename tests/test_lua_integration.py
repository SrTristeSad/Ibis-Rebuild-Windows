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

    def test_no_native_project_ffi(self):
        stage = ROOT / "build" / "lua-app"
        self.assertFalse((stage / "native.lua").exists())
        self.assertFalse((stage / "rebuild_core.dll").exists())
        engine = (stage / "lua_engine.lua").read_text(encoding="utf-8")
        self.assertNotIn("require('ffi')", engine)
        self.assertNotIn('require("ffi")', engine)
        self.assertIn("love.image.newImageData", engine)
        self.assertTrue((stage / "lua_selection.lua").is_file())
        self.assertIn("lua_selection", engine)
        self.assertIn("function Engine.affine_selection(", engine)
        self.assertIn("function Engine.preview_affine(", engine)
        self.assertTrue((stage / "lua_history.lua").is_file())
        bridge = (stage / "lua_bridge.lua").read_text(encoding="utf-8")
        self.assertIn("Bridge.selection_command(", bridge)
        self.assertIn("rotate_cw", bridge)
        self.assertIn("scale_half", bridge)
        self.assertIn("clipboard", bridge)
        self.assertIn("rotate_free", bridge)
        self.assertIn("scale_free", bridge)
        self.assertIn("Bridge.preview_snapshot", bridge)
        self.assertIn("Engine.preview_affine(", bridge)
        self.assertIn("History.load(", bridge)
        self.assertIn("History.save(", bridge)



if __name__ == "__main__":
    unittest.main()
