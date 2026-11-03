-- Paleta visual inicial do seletor de cores. Cores RGBA próprias, não
-- assets nem dados extraídos do APK. A paleta pessoal segue em Store.
local M={}
M.standard={
    0x000000ff,0xffffffff,0x333333ff,0x777777ff,0xbdbdbdff,
    0xef2637ff,0xff7729ff,0xffd635ff,0xa9e136ff,
    0x20b665ff,0x42dbbfff,0x37d5f5ff,0x36a4ffff,
    0x2565e7ff,0x4038baff,0x8653deff,0xd64de5ff,0xff4c9fff,
    0x8c223aff,0xa8462aff,0xc98453ff,0xb68d31ff,
    0x67753aff,0x23796aff,0x1f375dff,0x81668eff,0xe9a09bff,
    0x633a29ff,0x997255ff,0xcbb69fff,0xf2e2c5ff,
    0xb4e5baff,0xa5dcf2ff,0xbcb7f4ff,0xf1b8d2ff,0xf7d8c7ff
}
M.COLUMNS=9
function M.validTab(tab)
    return tab=='standard' or tab=='personal'
end
function M.entries(tab,saved)
    assert(M.validTab(tab) and type(saved)=='table',
        'Grupo de cores inválido')
    return tab=='standard' and M.standard or saved
end
function M.swatch(panel,index)
    assert(type(panel)=='table' and type(panel.x)=='number' and
        type(panel.y)=='number' and type(index)=='number'
        and index%1==0 and index>=1 and index<=36,
        'Célula da paleta inválida')
    local col=(index-1)%M.COLUMNS
    local row=math.floor((index-1)/M.COLUMNS)
    return {x=panel.x+22+col*40,y=panel.y+213+row*35,w=34,h=29}
end
return M
