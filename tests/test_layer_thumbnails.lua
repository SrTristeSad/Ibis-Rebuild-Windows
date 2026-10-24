-- Samples the real caller-owned C++ raster without drawing or mutating pixels.
local Native=require('native')
local Thumbs=require('layer_thumbnails')
local T={}
function T.run()
    assert(Native.available,'Miniaturas devem usar o buffer nativo real')
    local checks=0
    local function check(ok,msg)checks=checks+1;assert(ok,msg)end
    local buffer=Native.buffer(4,2)
    Native.clear(buffer,0)
    Native.pixel(buffer,0,0,0xff1122ff)
    Native.pixel(buffer,3,0,0x2244aacc)
    Native.pixel(buffer,0,1,0x00000000)
    Native.pixel(buffer,3,1,0xabcdef77)
    local original=Native.bytes(buffer)
    local bytes,w,h=Thumbs.sample(buffer,4)
    check(w==4 and h==2,'Letterbox aspect ratio incorrect')
    check(#bytes==4*4*4,'Thumbnail RGBA byte count invalid')
    local function pixel(raw,size,x,y)
        return raw:sub((y*size+x)*4+1,(y*size+x)*4+4)
    end
    check(pixel(bytes,4,0,0)==string.rep('\0',4),
        'Upper letterbox padding not transparent')
    check(pixel(bytes,4,0,1)==string.char(0xff,0x11,0x22,0xff),
        'Top-left thumbnail sample lost RGBA')
    check(pixel(bytes,4,3,1)==string.char(0x22,0x44,0xaa,0xcc),
        'Top-right thumbnail alpha lost')
    check(pixel(bytes,4,3,2)==string.char(0xab,0xcd,0xef,0x77),
        'Bottom-right sample lost alpha')
    check(pixel(bytes,4,0,3)==string.rep('\0',4),
        'Lower letterbox padding not transparent')
    check(Native.bytes(buffer)==original,'Thumbnail sampler modified source raster')
    check(not pcall(Thumbs.sample,buffer,0),'Accepted zero thumbnail')
    check(not pcall(Thumbs.sample,buffer,65),'Accepted overlarge thumbnail')
    local thin=Native.buffer(1,4)
    Native.clear(thin,0x335577ff)
    local portrait,pw,ph=Thumbs.sample(thin,4)
    check(pw==1 and ph==4,'Portrait aspect ratio incorrect')
    check(pixel(portrait,4,1,2)==string.char(0x33,0x55,0x77,0xff),
        'Portrait raster lost color')
    check(pixel(portrait,4,0,2)==string.rep('\0',4),
        'Portrait padding should be transparent')
    check(Native.bytes(thin)==string.rep(string.char(0x33,0x55,0x77,0xff),4),
        'Portrait native buffer mutated')
    local large=Native.buffer(128,256)
    Native.clear(large,0x123456ff)
    local sampled,sw,sh=Thumbs.sample(large)
    check(#sampled==28*28*4 and sw==14 and sh==28,
        'Large-image sample scaled incorrectly')
    check(pixel(sampled,28,7,11)==string.char(0x12,0x34,0x56,0xff),
        'Large native sample lost data')
    for _,pair in ipairs({{640,1},{677,1},{800,5},{1000,5}}) do
        check(Thumbs.rows(pair[1])==pair[2],'Incorrect responsive layer row count')
    end
    local start,stop,max=Thumbs.window(8,8,5)
    check(start==4 and stop==8 and max==4,
        'Active topmost layer not initially visible')
    check(Thumbs.scroll(start,max,-1)==3,'Scroll down one layer failed')
    check(Thumbs.scroll(3,max,1)==4,'Scroll up one layer failed')
    start,stop,max=Thumbs.window(8,1,5,3)
    check(start==3 and stop==7 and max==4,
        'Manually scrolled window lost its offset')
    start,stop=Thumbs.window(2,2,5)
    check(start==1 and stop==2,'Small layer set incorrectly cropped')
    start,stop=Thumbs.window(8,8,1)
    check(start==8 and stop==8,'Minimum window must reveal active layer')
    start,stop=Thumbs.window(8,8,5,99)
    check(start==4 and stop==8,'Scroll overflow not clamped')
    check(not pcall(Thumbs.window,9,1,5),'Accepted over-limit layer set')
    check(not pcall(Thumbs.rows,600),'Accepted unsupported viewport size')
    return {suite='native-layer-thumbnails',passed=true,assertions=checks,
        rgba_sampled=true,source_unchanged=true,aspect_padding=true,
        bounded_work=true,responsive_rows=true,paged_layer_windows=true}
end
return T
