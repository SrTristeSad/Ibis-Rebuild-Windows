-- Ponte experimental para o motor C libmypaint 1.6.x pelo LuaJIT FFI.
-- O frontend Ibis-Lua não é modificado. A DLL oficial de terceiros é
-- opcional; sem ela, o motor Lua existente permanece funcional.
local MyPaint = {}
local tried, native, ffi, load_error = false, nil, nil, nil

local function library()
    if tried then return native, load_error end
    tried = true
    local ok, ffi_module = pcall(require, "ffi")
    if not ok then
        load_error = "LuaJIT FFI indisponível"
        return nil, load_error
    end
    ffi = ffi_module
    ffi.cdef[[
        typedef struct MyPaintBrush MyPaintBrush;
        typedef struct MyPaintSurface MyPaintSurface;
        typedef int (*MyPaintDrawDab)(MyPaintSurface *, float, float, float,
            float, float, float, float, float, float, float, float, float, float);
        typedef void (*MyPaintGetColor)(MyPaintSurface *, float, float, float,
            float *, float *, float *, float *);
        typedef void (*MyPaintBeginAtomic)(MyPaintSurface *);
        typedef void (*MyPaintEndAtomic)(MyPaintSurface *, void *);
        typedef void (*MyPaintDestroy)(MyPaintSurface *);
        typedef void (*MyPaintSavePng)(MyPaintSurface *, const char *,
            int, int, int, int);
        struct MyPaintSurface {
            MyPaintDrawDab draw_dab;
            MyPaintGetColor get_color;
            MyPaintBeginAtomic begin_atomic;
            MyPaintEndAtomic end_atomic;
            MyPaintDestroy destroy;
            MyPaintSavePng save_png;
            int refcount;
        };
        MyPaintBrush *mypaint_brush_new(void);
        void mypaint_brush_unref(MyPaintBrush *);
        void mypaint_brush_from_defaults(MyPaintBrush *);
        void mypaint_brush_new_stroke(MyPaintBrush *);
        void mypaint_brush_set_base_value(MyPaintBrush *, int, float);
        int mypaint_brush_setting_from_cname(const char *);
        int mypaint_brush_stroke_to(MyPaintBrush *, MyPaintSurface *,
            float, float, float, float, float, double);
    ]]
    local opened, handle = pcall(ffi.load, "libmypaint-0")
    if not opened then
        load_error = "libmypaint-0.dll indisponível: " .. tostring(handle)
        return nil, load_error
    end
    native = handle
    return native
end

function MyPaint.available()
    local handle, reason = library()
    return handle ~= nil, reason
end

local function clamp(x) return math.max(0, math.min(1, x)) end

local function rgb_to_hsv(r, g, b)
    local hi = math.max(r, g, b)
    local lo = math.min(r, g, b)
    local delta = hi - lo
    local hue = 0
    if delta > 0 then
        if hi == r then hue = ((g - b) / delta) % 6
        elseif hi == g then hue = (b - r) / delta + 2
        else hue = (r - g) / delta + 4 end
    end
    return hue / 6, hi == 0 and 0 or delta / hi, hi
end

local function set(brush, name, value)
    local id = native.mypaint_brush_setting_from_cname(name)
    if id < 0 then return false, "Configuração MyPaint ausente: " .. name end
    native.mypaint_brush_set_base_value(brush, id, value)
    return true
end

-- Cada sessão guarda callbacks vivos: jamais liberar callbacks FFI
-- enquanto a biblioteca nativa ainda pode chamá-los.
function MyPaint.begin(rgb, diameter, opacity, data)
    local handle, reason = library()
    if not handle then return nil, reason end
    if not data or not data.getPixel then
        return nil, "Camada inválida para o MyPaint"
    end
    local brush = handle.mypaint_brush_new()
    if brush == nil then return nil, "Falha ao criar pincel MyPaint" end
    ffi.gc(brush, handle.mypaint_brush_unref)
    handle.mypaint_brush_from_defaults(brush)
    local h, s, v = rgb_to_hsv(clamp(rgb[1]), clamp(rgb[2]), clamp(rgb[3]))
    for _, option in ipairs({
        {"color_h", h}, {"color_s", s}, {"color_v", v},
        {"radius_logarithmic", math.log(math.max(0.75, math.min(256, diameter) / 2))},
        {"opaque", clamp(opacity)}, {"hardness", 0.65}
    }) do
        local ok, err = set(brush, option[1], option[2])
        if not ok then return nil, err end
    end
    handle.mypaint_brush_new_stroke(brush)

    local session = {brush = brush, dabs = {}, count = 0}
    session.surface = ffi.new("MyPaintSurface[1]")
    session.on_dab = ffi.cast("MyPaintDrawDab",
        function(_, x, y, radius, r, g, b, alpha, hardness,
                 eraser, aspect, angle, lock_alpha, colorize)
            if #session.dabs >= 4096 then return 0 end
            session.dabs[#session.dabs + 1] = {
                x = x, y = y, radius = radius,
                color = {r, g, b}, alpha = alpha,
                hardness = hardness, aspect = aspect, angle = angle,
                eraser = eraser, lock_alpha = lock_alpha,
                colorize = colorize
            }
            return 1
        end)
    session.on_color = ffi.cast("MyPaintGetColor",
        function(_, x, y, radius, red, green, blue, alpha)
            local w, h = data:getDimensions()
            local px = math.max(0, math.min(w - 1, math.floor(x)))
            local py = math.max(0, math.min(h - 1, math.floor(y)))
            local r, g, b, a = data:getPixel(px, py)
            red[0], green[0], blue[0], alpha[0] = r, g, b, a
        end)
    session.surface[0].draw_dab = session.on_dab
    session.surface[0].get_color = session.on_color
    session.surface[0].refcount = 1

    function session:stroke(x, y, pressure, dt)
        self.dabs = {}
        self.count = self.count + 1
        local dtime = dt or 1 / 60
        handle.mypaint_brush_stroke_to(self.brush, self.surface,
            x, y, pressure or 1, 0, 0, dtime)
        return self.dabs
    end
    return session
end

return MyPaint
