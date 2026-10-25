local Gallery=require('gallery_thumbnails')
local TextFit=require('text_fit')
local Icons=require('ui_icons')
local Native=require('native')
local Test={}
function Test.run()
    assert(Native.available,'Native DLL required for actual gallery previews')
    local count=0
    local function check(v,msg)count=count+1;assert(v,msg)end
    local dims={{512,512,74,74},{2048,1024,148,74},
        {1024,2048,37,74},{32,32,74,74},
        {2048,1,176,1}}
    for _,d in ipairs(dims) do
        local w,h=Gallery.size(d[1],d[2],176,74)
        check(w==d[3] and h==d[4],
            'Gallery preview aspect ratio or fit is incorrect')
    end
    local source=Native.buffer(8,8)
    Native.clear(source,0)
    Native.pixel(source,0,0,0xff330080)
    Native.pixel(source,7,7,0x112233ff)
    local bytes=Native.bytes(source)
    local samples={}
    Gallery.sample(bytes,8,8,8,8,function(r,g,b,a,x,y)
        samples[y*8+x]={r,g,b,a}
    end)
    check(#samples==64,'RGBA sampler must produce every target pixel')
    check(samples[0][1]==255 and samples[0][2]==51 and
        samples[0][3]==0 and samples[0][4]==128,
        'Transparent RGBA thumb colors changed')
    check(samples[63][1]==17 and samples[63][2]==34 and
        samples[63][3]==51 and samples[63][4]==255,
        'Opaque RGBA thumb colors changed')
    check(samples[1][4]==0 and Native.bytes(source)==bytes,
        'Preview changed transparent/native source pixels')
    local smaller={}
    Gallery.sample(bytes,8,8,4,4,function(r,g,b,a,x,y)
        smaller[y*4+x]={r,g,b,a}
    end)
    check(smaller[15][1]==17 and smaller[15][4]==255,
        'Downsample must reach bottom-right source pixel')
    check(not pcall(Gallery.sample,bytes:sub(1,-2),8,8,8,8,
        function()end),'Must reject truncated RGBA bytes')
    check(not pcall(Gallery.size,4096,2048,176,74),
        'Must reject unsupported huge native buffer')
    check(Gallery.key({id='project-foo',revision=2})=='project-foo:2' and
        Gallery.key({id='project-foo',revision=3})~=
        Gallery.key({id='project-foo',revision=2}),
        'Cache key must invalidate after saving a new revision')
    local function width(s)
        local i,n=1,0
        while i<=#s do
            local v=s:byte(i)
            i=i+(v<128 and 1 or v<224 and 2 or v<240 and 3 or 4)
            n=n+1
        end
        return n*8
    end
    local title='Demonstração longa de pincéis'
    check(TextFit.truncate(title,100,width)=='Demonstraç...',
        'Title should truncate at a valid UTF-8 character boundary')
    check(TextFit.truncate(title,1000,width)==title,
        'Short title must remain unchanged')
    check(TextFit.truncate(title,0,width)=='',
        'Zero-width text must be empty')
    check(TextFit.truncate(title,24,width)=='...',
        'Narrow text must contain only an ASCII ellipsis')
    for _,name in ipairs({'undo','redo','rotate-left','rotate-right',
        'visible','hidden'}) do
        local cmds=Icons.commands(name)
        check(type(cmds)=='table' and #cmds>=2,
            'Toolbar icon missing vector commands: '..name)
    end
    return {suite='stage37-gallery-visual-polish',passed=true,
        assertions=count,composite_rgba=true,
        thumbnail_alpha=true,source_immutable=true,
        cache_invalidation=true,unicode_safe=true,
        vector_icons=true}
end
return Test
