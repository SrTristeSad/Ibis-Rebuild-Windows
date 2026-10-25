-- Stage 38: geometry and readable labels for the Windows gallery/editor.
-- No drawing, I/O, document changes or Android assets.
local Visual={}
local toolNames={
    inspect='Ver',pixel='Pixel',brush='Pincel',erase='Borracha',
    fill='Balde',select='Seleção',shape='Formas',picker='Pipeta'
}
function Visual.toolLabel(id)
    return assert(toolNames[id],'Unknown editor tool label')
end
function Visual.galleryColumns(w)
    assert(type(w)=='number' and w>=960,'Unsupported gallery width')
    return math.max(1,math.floor((w-88)/230))
end
function Visual.galleryCard(w,h,index)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640 and
        type(index)=='number' and index%1==0 and index>=1,
        'Invalid gallery card layout')
    local column=(index-1)%Visual.galleryColumns(w)
    local row=math.floor((index-1)/Visual.galleryColumns(w))
    local x,y=44+column*230,266+row*236
    return {x=x,y=y,w=212,h=210,
        preview={x=x+18,y=y+15,w=176,h=126},
        titleX=x+18,titleY=y+154,
        metaX=x+18,metaY=y+181,
        visible=y+210<=h-66}
end
function Visual.clampTextWidth(w)
    assert(type(w)=='number' and w>=0,'Invalid text width')
    return math.max(0,w-10)
end
function Visual.headerNameWidth(w)
    assert(type(w)=='number' and w>=960,
        'Invalid Windows editor width')
    return math.max(0,math.min(320,w-900))
end
return Visual
