local Visual=require('visual_hierarchy')
local Thumb=require('gallery_thumbnails')
local TextFit=require('text_fit')
local T={}
function T.run()
    local checks=0
    local function verify(cond,message)
        checks=checks+1
        assert(cond,message)
    end
    local expected={
        inspect='Ver',pixel='Pixel',brush='Pincel',erase='Borracha',
        fill='Balde',select='Seleção',shape='Formas',picker='Pipeta'
    }
    for id,name in pairs(expected) do
        verify(Visual.toolLabel(id)==name,'Incorrect accessible toolbar label')
        verify(#name<=10,'Short glyph labels must fit legacy hit targets')
    end
    verify(not pcall(Visual.toolLabel,'unknown'),
        'Unknown tool should fail explicitly')
    for _,resolution in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=resolution[1],resolution[2]
        local columns=Visual.galleryColumns(w)
        verify(columns==math.floor((w-88)/230),
            'Gallery columns must match visual grid')
        for index=1,columns*3 do
            local card=Visual.galleryCard(w,h,index)
            verify(card.x>=44 and card.x+card.w<=w and card.y>=266,
                'Card must stay in viewport horizontally')
            verify(card.preview.x>=card.x and
                card.preview.y>=card.y and
                card.preview.x+card.preview.w<=card.x+card.w and
                card.preview.y+card.preview.h<card.titleY,
                'Artwork preview must never overlap project title')
            verify(card.titleY<card.metaY and
                card.metaY+16<=card.y+card.h,
                'Title and metadata must be readable within card')
            verify(card.visible==(card.y+card.h<=h-66),
                'Gallery bounds must account for footer')
        end
        local first=Visual.galleryCard(w,h,1)
        verify(first.x==44 and first.y==266 and
            first.w==212 and first.h==210,
            'First project hit geometry must preserve legacy click location')
    end
    verify(Visual.galleryCard(1220,800,2).x==274,
        'Second gallery card should retain original column stride')
    verify(Visual.galleryCard(1220,800,6).y==502,
        'Second gallery row should use expanded card height')
    verify(Visual.headerNameWidth(1220)==320 and
        Visual.headerNameWidth(1120)==220,
        'Contextual header must not overlap command buttons')
    verify(Visual.clampTextWidth(82)==72 and
        Visual.clampTextWidth(4)==0,
        'Button title labels must leave padding')
    verify(not pcall(Visual.galleryCard,800,600,1),
        'Below-minimum viewport cannot receive gallery card')
    local tw,th=Thumb.size(512,512,176,126)
    verify(tw==126 and th==126,
        'Square artwork must fill enlarged gallery preview')
    local w2,h2=Thumb.size(2048,1024,176,126)
    verify(w2==176 and h2==88,
        'Wide artwork should preserve ratio')
    local hits=0
    local rgba=string.rep(string.char(50,90,120,170),tw*th)
    Thumb.sample(rgba,tw,th,tw,th,function(r,g,b,a,x,y)
        if x==0 and y==0 then
            verify(r==50 and g==90 and b==120 and a==170,
                'Expanded thumbnail must retain exact RGBA channels')
        end
        hits=hits+1
    end)
    verify(hits==tw*th,'Every pixel in the new thumbnail must be sampled')
    local long='Uma demonstração muito longa'
    local function measure(s) return #s*7 end
    verify(measure(TextFit.truncate(long,80,measure))<=80,
        'Long header/button labels must not extend outside their region')
    return {suite='stage38-visual-hierarchy',passed=true,
        assertions=checks,layout_safe=true,
        native_preview_area=true,tool_labels_readable=true,
        header_no_overlap=true,text_clamped=true}
end
return T
