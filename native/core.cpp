#include "core.h"

static_assert(sizeof(rb_u8) == 1, "byte ABI");
static_assert(sizeof(rb_u32) == 4 && sizeof(rb_i32) == 4, "integer ABI");
static_assert(sizeof(rb_u64) == 8 && sizeof(rb_i64) == 8, "long ABI");
static_assert(sizeof(float) == 4 && sizeof(void*) == 8, "Windows x64 ABI");
static_assert(sizeof(RBSample) == 56, "sample layout ABI");

#if defined(_WIN32) && defined(_MSC_VER)
/* COFF floating-point-use marker required by the MSVC target without CRT.
   Constant data only; it is not application state or a runtime dependency. */
extern "C" { extern const int _fltused = 0; }
#endif

namespace {
union FloatBits { float value; rb_u32 bits; };
static float zero_with_sign(rb_u32 sign) {
    FloatBits b; b.bits = sign & 0x80000000u; return b.value;
}
/* Java Math.min/max propagate NaN and distinguish signed zero. These local
   primitives express the observed numeric contract, not recovered source. */
static float min_java(float a, float b) {
    if (a != a) return a;
    if (b != b) return b;
    if (a == 0.0f && b == 0.0f) {
        FloatBits x, y; x.value = a; y.value = b;
        return zero_with_sign(x.bits | y.bits);
    }
    return a < b ? a : b;
}
static float max_java(float a, float b) {
    if (a != a) return a;
    if (b != b) return b;
    if (a == 0.0f && b == 0.0f) {
        FloatBits x, y; x.value = a; y.value = b;
        return zero_with_sign(x.bits & y.bits);
    }
    return a > b ? a : b;
}
static bool plane(const void* ptr, rb_u64 capacity, rb_u32 w, rb_u32 h) {
    if (!ptr || w == 0 || h == 0 || w > 8192 || h > 8192) return false;
    const rb_u64 required = static_cast<rb_u64>(w) * h * 4u;
    return capacity >= required;
}
static bool coordinate(rb_u32 w, rb_u32 h, rb_i32 x, rb_i32 y) {
    return x >= 0 && y >= 0 && static_cast<rb_u32>(x) < w &&
        static_cast<rb_u32>(y) < h;
}
static void put(rb_u8* p, rb_u32 c) {
    p[0] = static_cast<rb_u8>(c >> 24); p[1] = static_cast<rb_u8>(c >> 16);
    p[2] = static_cast<rb_u8>(c >> 8); p[3] = static_cast<rb_u8>(c);
}
struct Range { rb_u64 first, end; };
static bool range(const void* p, rb_u64 bytes, rb_u64 alignment, Range& r) {
    const rb_u64 address = reinterpret_cast<rb_u64>(p);
    if (!address || (address & (alignment - 1u)) || bytes > ~rb_u64(0) - address)
        return false;
    r.first = address; r.end = address + bytes; return true;
}
static bool disjoint(const Range& a, const Range& b) {
    return a.end <= b.first || b.end <= a.first;
}
}

rb_u32 rb_version(void) { return 1; }
rb_u32 rb_sample_size(void) { return sizeof(RBSample); }

float rb_normalize_pressure(float raw, rb_i32 enabled, float low, float high) {
    if (!enabled) return 1.0f;
    /* Explicit intermediates retain float rounding. Build with precise FP,
       without fast-math; the target Java method has no high==low guard. */
    const float numerator = raw - low;
    const float denominator = high - low;
    const float normalized = numerator / denominator;
    return max_java(0.0f, min_java(normalized, 1.0f));
}

rb_i32 rb_thickness_update(float* current, float proposed) {
    if (!current) return -1;
    /* fabs(value) <= 2 including negative values, but excluding NaN/inf.
       No clamping: rejected proposals preserve the previous state. */
    if (!(proposed >= -2.0f && proposed <= 2.0f)) return 0;
    *current = proposed; return 1;
}

rb_i32 rb_pack_samples(const RBSample* samples, rb_u64 count,
    rb_i32* ints, rb_u64 int_capacity, float* floats, rb_u64 float_capacity,
    rb_i64* times, rb_u64 time_capacity) {
    if (count == 0) return 0;
    if (count > ~rb_u64(0) / sizeof(RBSample)) return -1;
    if (int_capacity < count * 2u || float_capacity < count * 7u ||
        time_capacity < count) return -1;
    Range ranges[4];
    if (!range(samples, count * sizeof(RBSample), 8, ranges[0]) ||
        !range(ints, count * 8u, 4, ranges[1]) ||
        !range(floats, count * 28u, 4, ranges[2]) ||
        !range(times, count * 8u, 8, ranges[3])) return -1;
    for (rb_u32 a = 0; a < 4; ++a)
        for (rb_u32 b = a + 1; b < 4; ++b)
            if (!disjoint(ranges[a], ranges[b])) return -1;
    for (rb_u64 i = 0; i < count; ++i) {
        const RBSample& s = samples[i];
        ints[i * 2] = s.pointer_id; ints[i * 2 + 1] = s.pointer_info;
        float* f = floats + i * 7;
        f[0] = s.x; f[1] = s.y; f[2] = s.previous_x; f[3] = s.previous_y;
        f[4] = s.pressure;
        f[5] = s.is_stylus ? s.altitude : 0.0f;
        f[6] = s.is_stylus ? s.azimuth : 0.0f;
        times[i] = s.time;
    }
    return 0;
}

rb_i32 rb_clear(rb_u8* dst, rb_u64 capacity, rb_u32 width,
    rb_u32 height, rb_u32 rgba) {
    if (!plane(dst, capacity, width, height)) return -1;
    const rb_u64 bytes = static_cast<rb_u64>(width) * height * 4u;
    for (rb_u64 i = 0; i < bytes; i += 4) put(dst + i, rgba);
    return 0;
}

rb_i32 rb_set_pixel(rb_u8* dst, rb_u64 capacity, rb_u32 width,
    rb_u32 height, rb_i32 x, rb_i32 y, rb_u32 rgba) {
    if (!plane(dst, capacity, width, height) || !coordinate(width, height, x, y))
        return -1;
    const rb_u64 at = (static_cast<rb_u64>(y) * width + x) * 4u;
    put(dst + at, rgba); return 0;
}

rb_i32 rb_get_pixel(const rb_u8* src, rb_u64 capacity, rb_u32 width,
    rb_u32 height, rb_i32 x, rb_i32 y, rb_u32* rgba) {
    if (!rgba || !plane(src, capacity, width, height) ||
        !coordinate(width, height, x, y)) return -1;
    const rb_u64 at = (static_cast<rb_u64>(y) * width + x) * 4u;
    const rb_u8* p = src + at;
    *rgba = (static_cast<rb_u32>(p[0]) << 24) |
        (static_cast<rb_u32>(p[1]) << 16) |
        (static_cast<rb_u32>(p[2]) << 8) | p[3];
    return 0;
}


/* Deterministic desktop canvas primitive, NOT recovered Android brush code.
   Pixel coverage is a continuous line segment with round caps; one source-over
   blend per affected pixel. No CRT, heap allocations, callbacks or global state. */
rb_i32 rb_draw_basic_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter, rb_u32 rgba, float opacity) {
    if (!plane(dst, capacity, width, height)) return -1;
    // Comparisons intentionally reject NaN and infinities.
    if (!(diameter >= 1.0f && diameter <= 256.0f) ||
        !(opacity >= 0.0f && opacity <= 1.0f) ||
        !(x0 >= -16384.0f && x0 <= 16384.0f) ||
        !(y0 >= -16384.0f && y0 <= 16384.0f) ||
        !(x1 >= -16384.0f && x1 <= 16384.0f) ||
        !(y1 >= -16384.0f && y1 <= 16384.0f))
        return -1;
    const float srcAlpha = static_cast<float>(rgba & 255u) * (opacity / 255.0f);
    if (srcAlpha <= 0.0f) return 0;
    const float oneMinusSrc = 1.0f - srcAlpha;
    const float radius = diameter * 0.5f;
    const float radiusSquared = radius * radius;
    const float dx = x1 - x0, dy = y1 - y0;
    const float squaredLength = dx * dx + dy * dy;
    const float minX = (x0 < x1 ? x0 : x1) - radius - 1.0f;
    const float maxX = (x0 > x1 ? x0 : x1) + radius + 1.0f;
    const float minY = (y0 < y1 ? y0 : y1) - radius - 1.0f;
    const float maxY = (y0 > y1 ? y0 : y1) + radius + 1.0f;
    if (maxX < 0.0f || maxY < 0.0f ||
        minX > static_cast<float>(width) ||
        minY > static_cast<float>(height))
        return 0;
    rb_i32 left = static_cast<rb_i32>(minX);
    rb_i32 right = static_cast<rb_i32>(maxX);
    rb_i32 top = static_cast<rb_i32>(minY);
    rb_i32 bottom = static_cast<rb_i32>(maxY);
    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (right >= static_cast<rb_i32>(width)) right = static_cast<rb_i32>(width) - 1;
    if (bottom >= static_cast<rb_i32>(height)) bottom = static_cast<rb_i32>(height) - 1;
    const float srcR = static_cast<float>((rgba >> 24) & 255u);
    const float srcG = static_cast<float>((rgba >> 16) & 255u);
    const float srcB = static_cast<float>((rgba >> 8) & 255u);
    for (rb_i32 y = top; y <= bottom; ++y) {
        for (rb_i32 x = left; x <= right; ++x) {
            const float cx = static_cast<float>(x) + 0.5f;
            const float cy = static_cast<float>(y) + 0.5f;
            float t = 0.0f;
            if (squaredLength > 0.0f) {
                t = ((cx - x0) * dx + (cy - y0) * dy) / squaredLength;
                if (t < 0.0f) t = 0.0f;
                if (t > 1.0f) t = 1.0f;
            }
            const float ex = cx - (x0 + t * dx);
            const float ey = cy - (y0 + t * dy);
            if (ex * ex + ey * ey > radiusSquared) continue;
            rb_u8* pixel = dst + (static_cast<rb_u64>(y) * width + x) * 4u;
            const float dstAlpha = static_cast<float>(pixel[3]) / 255.0f;
            const float outAlpha = srcAlpha + dstAlpha * oneMinusSrc;
            const rb_u32 outA = static_cast<rb_u32>(outAlpha * 255.0f + 0.5f);
            if (outA == 0) { pixel[0]=0;pixel[1]=0;pixel[2]=0;pixel[3]=0;continue; }
            const float dstWeight = dstAlpha * oneMinusSrc;
            const float srcWeight = srcAlpha;
            const float invAlpha = 1.0f / outAlpha;
            float channels[3] = {
                (srcR * srcWeight + pixel[0] * dstWeight) * invAlpha,
                (srcG * srcWeight + pixel[1] * dstWeight) * invAlpha,
                (srcB * srcWeight + pixel[2] * dstWeight) * invAlpha
            };
            for (rb_u32 c = 0; c < 3; ++c) {
                float value = channels[c];
                if (value > 255.0f) value = 255.0f;
                if (value < 0.0f) value = 0.0f;
                pixel[c] = static_cast<rb_u8>(value + 0.5f);
            }
            pixel[3] = static_cast<rb_u8>(outA);
        }
    }
    return 0;
}


/* Independent desktop normal-mode, straight-alpha source-over compositor.
   Each layer is opaque to the algorithm except its RGBA bytes and opacity.
   The caller is responsible for visibility, ordering and group semantics. */
rb_i32 rb_compose_normal(rb_u8* dst, rb_u64 dst_capacity,
    const rb_u8* src, rb_u64 src_capacity,
    rb_u32 width, rb_u32 height, float opacity) {
    if (!plane(dst, dst_capacity, width, height) ||
        !plane(src, src_capacity, width, height) ||
        !(opacity >= 0.0f && opacity <= 1.0f)) return -1;
    const rb_u64 bytes = static_cast<rb_u64>(width) * height * 4u;
    Range d,s;
    if (!range(dst, bytes, 1, d) || !range(src, bytes, 1, s) ||
        !disjoint(d,s)) return -1;
    if (opacity == 0.0f) return 0;
    for (rb_u64 i = 0; i < bytes; i += 4) {
        const float sa = (static_cast<float>(src[i+3]) / 255.0f) * opacity;
        if (sa == 0.0f) continue;
        const float da = static_cast<float>(dst[i+3]) / 255.0f;
        const float remaining = da * (1.0f - sa);
        const float oa = sa + remaining;
        if (oa == 0.0f) continue;
        const float inv = 1.0f / oa;
        for (rb_u32 k = 0; k < 3; ++k) {
            float c = (static_cast<float>(src[i+k]) * sa +
                       static_cast<float>(dst[i+k]) * remaining) * inv;
            if (c > 255.0f) c = 255.0f;
            if (c < 0.0f) c = 0.0f;
            dst[i+k] = static_cast<rb_u8>(c + 0.5f);
        }
        dst[i+3] = static_cast<rb_u8>(oa * 255.0f + 0.5f);
    }
    return 0;
}


/* Desktop-only round eraser. This is destination-out rather than an Android
   recovered eraser. Coverage is a hard-edged continuous capsule; each pixel
   is affected at most once per invocation. No heap, callbacks or I/O. */
rb_i32 rb_erase_basic_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter, float opacity) {
    if (!plane(dst, capacity, width, height) ||
        !(diameter >= 1.0f && diameter <= 256.0f) ||
        !(opacity >= 0.0f && opacity <= 1.0f) ||
        !(x0 >= -16384.0f && x0 <= 16384.0f) ||
        !(y0 >= -16384.0f && y0 <= 16384.0f) ||
        !(x1 >= -16384.0f && x1 <= 16384.0f) ||
        !(y1 >= -16384.0f && y1 <= 16384.0f)) return -1;
    if (opacity == 0.0f) return 0;
    const float radius = diameter * 0.5f;
    const float radiusSquared = radius * radius;
    const float dx = x1 - x0, dy = y1 - y0;
    const float lenSquared = dx * dx + dy * dy;
    const float minX = (x0 < x1 ? x0 : x1) - radius - 1.0f;
    const float minY = (y0 < y1 ? y0 : y1) - radius - 1.0f;
    const float maxX = (x0 > x1 ? x0 : x1) + radius + 1.0f;
    const float maxY = (y0 > y1 ? y0 : y1) + radius + 1.0f;
    if (maxX < 0.0f || maxY < 0.0f ||
        minX > static_cast<float>(width) || minY > static_cast<float>(height))
        return 0;
    rb_i32 left = static_cast<rb_i32>(minX);
    rb_i32 right = static_cast<rb_i32>(maxX);
    rb_i32 top = static_cast<rb_i32>(minY);
    rb_i32 bottom = static_cast<rb_i32>(maxY);
    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (right >= static_cast<rb_i32>(width)) right = static_cast<rb_i32>(width)-1;
    if (bottom >= static_cast<rb_i32>(height)) bottom = static_cast<rb_i32>(height)-1;
    const float retention = 1.0f-opacity;
    for (rb_i32 y=top; y<=bottom; ++y) {
        for (rb_i32 x=left; x<=right; ++x) {
            const float px=static_cast<float>(x)+0.5f;
            const float py=static_cast<float>(y)+0.5f;
            float t=0.0f;
            if (lenSquared>0.0f) {
                t=((px-x0)*dx+(py-y0)*dy)/lenSquared;
                if (t<0.0f) t=0.0f;
                if (t>1.0f) t=1.0f;
            }
            const float ax=px-(x0+t*dx), ay=py-(y0+t*dy);
            if (ax*ax+ay*ay>radiusSquared) continue;
            rb_u8* pixel=dst+(static_cast<rb_u64>(y)*width+x)*4u;
            const rb_u32 alpha=static_cast<rb_u32>(
                static_cast<float>(pixel[3])*retention+0.5f);
            pixel[3]=static_cast<rb_u8>(alpha);
            if (alpha==0) pixel[0]=pixel[1]=pixel[2]=0;
        }
    }
    return 0;
}

/* Rectangle translation implementation follows. */

rb_i32 rb_move_rect_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, rb_i32 sx, rb_i32 sy,
    rb_u32 rw, rb_u32 rh, rb_i32 tx, rb_i32 ty,
    rb_u8* scratch, rb_u64 scratch_capacity) {
    if (!plane(dst, capacity, width, height) || sx < 0 || sy < 0 ||
        rw == 0 || rh == 0 || rw > width || rh > height ||
        static_cast<rb_u32>(sx) > width - rw ||
        static_cast<rb_u32>(sy) > height - rh) return -1;
    const rb_u64 count = static_cast<rb_u64>(rw) * rh * 4u;
    if (!scratch || scratch_capacity < count) return -1;
    Range d,s;
    if (!range(dst, static_cast<rb_u64>(width)*height*4u, 1, d) ||
        !range(scratch, count, 1, s) || !disjoint(d,s)) return -1;
    if (sx == tx && sy == ty) return 0;
    // Volatile byte access prevents MSVC /O2 from synthesizing CRT memcpy.
    volatile rb_u8* snapshot=scratch;
    const volatile rb_u8* original=dst;
    volatile rb_u8* output=dst;
    for (rb_u32 y=0;y<rh;++y) {
        const rb_u64 source=(static_cast<rb_u64>(sy)+y)*width+sx;
        const rb_u64 dest=static_cast<rb_u64>(y)*rw;
        for (rb_u32 b=0;b<rw*4u;++b)
            snapshot[dest*4u+b]=original[source*4u+b];
    }
    for (rb_u32 y=0;y<rh;++y) {
        const rb_u64 source=(static_cast<rb_u64>(sy)+y)*width+sx;
        for (rb_u32 b=0;b<rw*4u;++b) output[source*4u+b]=0;
    }
    for (rb_u32 y=0;y<rh;++y) {
        const rb_i64 cy=static_cast<rb_i64>(ty)+y;
        if (cy<0 || cy>=height) continue;
        for (rb_u32 x=0;x<rw;++x) {
            const rb_i64 cx=static_cast<rb_i64>(tx)+x;
            if (cx<0 || cx>=width) continue;
            const rb_u8* src=scratch+(static_cast<rb_u64>(y)*rw+x)*4u;
            rb_u8* p=dst+(static_cast<rb_u64>(cy)*width+
                static_cast<rb_u64>(cx))*4u;
            const float sa=static_cast<float>(src[3])/255.0f;
            if (sa<=0.0f) continue;
            const float da=static_cast<float>(p[3])/255.0f;
            const float rest=da*(1.0f-sa);
            const float oa=sa+rest;
            const float inv=1.0f/oa;
            for (rb_u32 ch=0;ch<3;++ch) {
                float color=(src[ch]*sa+p[ch]*rest)*inv;
                if (color>255.0f) color=255.0f;
                if (color<0.0f) color=0.0f;
                p[ch]=static_cast<rb_u8>(color+0.5f);
            }
            p[3]=static_cast<rb_u8>(oa*255.0f+0.5f);
        }
    }
    return 0;
}


/* Independent desktop raster transformation, NOT recovered Android code. */
rb_i32 rb_transform_rect_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height,
    rb_i32 sx, rb_i32 sy, rb_u32 sw, rb_u32 sh,
    rb_i32 tx, rb_i32 ty, rb_u32 tw, rb_u32 th,
    rb_u32 quarter_turns, rb_u8* scratch, rb_u64 scratch_capacity) {
    if (!plane(dst, capacity, width, height) ||
        sx < 0 || sy < 0 || tx < 0 || ty < 0 ||
        sw == 0 || sh == 0 || tw == 0 || th == 0 ||
        sw > width || sh > height || tw > width || th > height ||
        static_cast<rb_u32>(sx) > width - sw ||
        static_cast<rb_u32>(sy) > height - sh ||
        static_cast<rb_u32>(tx) > width - tw ||
        static_cast<rb_u32>(ty) > height - th ||
        quarter_turns > 3) return -1;
    const rb_u64 count = static_cast<rb_u64>(sw) * sh * 4u;
    if (!scratch || scratch_capacity < count) return -1;
    Range dstRange, tempRange;
    if (!range(dst, static_cast<rb_u64>(width)*height*4u, 1, dstRange) ||
        !range(scratch, count, 1, tempRange) ||
        !disjoint(dstRange, tempRange)) return -1;
    if (sx == tx && sy == ty && sw == tw && sh == th &&
        quarter_turns == 0) return 0;
    /* Volatile byte access prevents freestanding MSVC from emitting memcpy
       or memset imports: our DLL intentionally links without the CRT. */
    const volatile rb_u8* input = dst;
    volatile rb_u8* output = dst;
    volatile rb_u8* copied = scratch;
    for (rb_u32 y = 0; y < sh; ++y) {
        const rb_u64 inBase = (static_cast<rb_u64>(sy)+y)*width+sx;
        const rb_u64 outBase = static_cast<rb_u64>(y)*sw;
        for (rb_u32 byte = 0; byte < sw*4u; ++byte)
            copied[outBase*4u+byte] = input[inBase*4u+byte];
    }
    for (rb_u32 y = 0; y < sh; ++y) {
        const rb_u64 start = (static_cast<rb_u64>(sy)+y)*width+sx;
        for (rb_u32 byte = 0; byte < sw*4u; ++byte)
            output[start*4u+byte] = 0;
    }
    for (rb_u32 y = 0; y < th; ++y) {
        for (rb_u32 x = 0; x < tw; ++x) {
            rb_u32 ox = 0, oy = 0;
            if (quarter_turns == 0) {
                ox = x*sw/tw; oy = y*sh/th;
            } else if (quarter_turns == 1) {
                ox = y*sw/th; oy = sh-1u-x*sh/tw;
            } else if (quarter_turns == 2) {
                ox = sw-1u-x*sw/tw; oy = sh-1u-y*sh/th;
            } else {
                ox = sw-1u-y*sw/th; oy = x*sh/tw;
            }
            const rb_u8* src = scratch+(static_cast<rb_u64>(oy)*sw+ox)*4u;
            const float sa = static_cast<float>(src[3])/255.0f;
            if (sa<=0.0f) continue;
            rb_u8* p = dst+((static_cast<rb_u64>(ty)+y)*width+
                static_cast<rb_u32>(tx)+x)*4u;
            const float da = static_cast<float>(p[3])/255.0f;
            const float rest = da*(1.0f-sa);
            const float oa = sa+rest;
            const float inv = 1.0f/oa;
