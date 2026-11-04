"""Monta o aplicativo Windows com a interface original Ibis-Lua (submódulo fixado).

Sem baixar arquivos em tempo de execução e sem duplicar a interface no repositório.
Mudanças no main.lua da interface são SOMENTE ganchos de integração, no staging.
"""
from pathlib import Path
import argparse
import shutil

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "ui" / "Ibis-Lua"
STAGE = ROOT / "build" / "lua-app"


def replace_once(text: str, old: str, new: str) -> str:
    hits = text.count(old)
    if hits != 1:
        raise RuntimeError(f"Âncora incompatível com Ibis-Lua (ocorrências={hits}): {old[:90]!r}")
    return text.replace(old, new, 1)


def assemble() -> Path:
    if not (UPSTREAM / "main.lua").is_file():
        raise RuntimeError("Submódulo ui/Ibis-Lua ausente. Execute git submodule update --init.")
    if STAGE.exists():
        shutil.rmtree(STAGE)
    shutil.copytree(UPSTREAM, STAGE, ignore=shutil.ignore_patterns(".git", ".github", "tests", "tools", "docs"))
    for src in sorted((ROOT / "bridge").glob("*.lua")):
        shutil.copy2(src, STAGE / src.name)
    original = (STAGE / "main.lua").read_text(encoding="utf-8")
    patches = [
        ('local Model = require("src.model")\n',
         'local Model = require("src.model")\n'
         'local Bridge = require("lua_bridge")\nBridge.install(Model)\n'),
        ('    active_artwork_id=gallery:add_artwork(\n'
         '        wi,he,"Untitled "..tostring(gallery:total_artworks()+1))\n'
         '    view:reset()\n',
         '    active_artwork_id=gallery:add_artwork(\n'
         '        wi,he,"Untitled "..tostring(gallery:total_artworks()+1))\n'
         '    Bridge.create(state,active_artwork_id,gallery)\n'
         '    view:reset()\n'),
        ('    state:create_canvas(wi,he)\n'
         '    active_artwork_id=gallery:add_artwork(',
         '    local supported,reason=Bridge.supports(wi,he)\n'
         '    if not supported then notice(reason);return end\n'
         '    state:create_canvas(wi,he)\n'
         '    active_artwork_id=gallery:add_artwork('),
        ('                active_artwork_id=id\n                view:reset()\n',
         '                active_artwork_id=id\n                Bridge.open(state,id)\n'
         '                view:reset()\n'),
        ('        rectangle(px,py,cw,ch,C.white,1,4)\n'
         '        stroke(px,py,cw,ch,C.card_border,0.95)\n',
         '        rectangle(px,py,cw,ch,C.white,1,4)\n'
         '        Bridge.draw_gallery_thumbnail(item.id,px,py,cw,ch)\n'
         '        stroke(px,py,cw,ch,C.card_border,0.95)\n'),
        ('            stroke(bx+4,yy+5,40,40,C.soft,0.7)\n',
         '            Bridge.draw_layer_thumbnail(state,layer.id,bx+4,yy+5,40,40)\n'
         '            stroke(bx+4,yy+5,40,40,C.soft,0.7)\n'),
        ('    draw_view_guides(dw,dh,actual_scale)\n',
         '    Bridge.draw(state,visual)\n    draw_view_guides(dw,dh,actual_scale)\n'),
        ('    if state.screen=="editor" and not panel and love.keyboard.isDown("space") then\n',
         '    if state.screen=="editor" and not panel and\n'
         '       Bridge.mousepressed(state,active_artwork_id,x,y,W,H,view,preferences,\n'
         '           colors.current,state.brush_size,opacity,colors,notice) then return end\n'
         '    if state.screen=="editor" and not panel and love.keyboard.isDown("space") then\n'),
        ('function love.mousemoved(rx,ry,dx,dy)\n',
         'function love.mousemoved(rx,ry,dx,dy)\n'
         '    if Bridge.mousemoved(state,rx,ry,scale) then return end\n'),
        ('function love.mousereleased(rx,ry,button)\n    if button~=1 then return end\n',
         'function love.mousereleased(rx,ry,button)\n    if button~=1 then return end\n'
         '    Bridge.mousereleased(state,rx,ry,scale)\n'),
        ('function love.keypressed(key)\n',
         'function love.keypressed(key)\n'
         '    -- Evitar capturar atalhos nos campos de texto da interface.\n'
         '    if not color_dialog and not brush_search_active and\n'
         '       not state.modal and Bridge.keypressed(key,state,notice) then return end\n'),
        ('    IconPack.load()\n',
         '    IconPack.load()\n'
         '    if not (smoke or e2e or settings_e2e or gallery_e2e or color_e2e) then\n'
         '        Bridge.restore_gallery(gallery)\n    end\n'),
        ('{"undo",function()\n'
         '            if preferences.show_undo_message then\n'
         '                notice("Nenhuma alteração de pintura para desfazer.")\n'
         '            end\n'
         '        end},',
         '{"undo",function() Bridge.undo() end},'),
        ('{"redo",function()\n'
         '            if preferences.show_undo_message then\n'
         '                notice("Nenhuma alteração de pintura para refazer.")\n'
         '            end\n'
         '        end},',
         '{"redo",function() Bridge.redo() end},'),
    ]
    for old, new in patches:
        original = replace_once(original, old, new)
    (STAGE / "main.lua").write_text(original, encoding="utf-8")
    # Artefato independente não utiliza DLL, native.lua ou o código C++ legado.
    return STAGE


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stage = assemble()
    assert (stage / "src" / "model.lua").is_file()
    assert (stage / "assets" / "icons" / "png").is_dir()
    assert (stage / "lua_engine.lua").is_file()
    print(f"Lua/LÖVE pronto: {stage} (Ibis-Lua preservado no submódulo)")
