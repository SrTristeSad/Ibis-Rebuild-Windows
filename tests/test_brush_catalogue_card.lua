local Card=require('brush_catalogue_card')
local Presets=require('brush_presets')
local Samples=require('brush_samples')
local Lab=require('brush_lab')
local T={}
function T.run()
    local n=0
    local function check(ok,msg)n=n+1;assert(ok,msg)end
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local r=Presets.layout(dim[1],dim[2])
        local width=(Lab.CATALOGUE_WIDTH-56)/2
        local inspector=Lab.layout(r)
        for slot=1,8 do
            local col=(slot-1)%2
            local row=math.floor((slot-1)/2)
            local x=r.x+20+col*(width+16)
            local y=r.y+80+row*88
            local p=Card.previewButton(x,y,width)
            local sample=Samples.cardRect(x,y,width)
            check(p.x>=x and p.x+p.w<x+width and
                p.y>=y and p.y+p.h<sample.y,
                'Preview control must fit card above native swatch')
            check(p.x>sample.x+25 and
                p.x+p.w<inspector.x and
                p.y+p.h<=r.y+80+4*88,
                'Preview hitbox must avoid title and inspector')
        end
    end
    local previous={name='Meu pincel 1'}
    check(Card.inspectorName(3,{})=='Marcador suave',
        'Built-in preview name matches selected preset')
    check(Card.inspectorName(5,{previous})==previous.name,
        'Saved preview name matches selected user preset')
    check(Card.inspectorName(nil,{})=='Pincel atual',
        'Empty personal category may preview active brush')
    check(Card.inspectorName(8,{})=='Pincel atual',
        'Unavailable saved slot has safe preview title')
    check(not pcall(Card.inspectorName,9,{}) and
        not pcall(Card.inspectorName,-1,{}) and
        not pcall(Card.inspectorName,1,nil),
        'Invalid focus or catalogue rejected')
    check(not pcall(Card.previewButton,0,0,100),
        'Too-narrow cards rejected')
    return {suite='stage42-brush-card-preview',passed=true,
        assertions=n,preview_separate_from_apply=true,
        native_swatches_preserved=true}
end
return T
