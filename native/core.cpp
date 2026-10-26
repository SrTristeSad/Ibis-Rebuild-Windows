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


/* Partial normal composition. Identical math/rounding to rb_compose_normal;
   only the clipped rectangle is processed, with atomic validation. */
rb_i32 rb_clear_rect_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, rb_u32 x, rb_u32 y,
    rb_u32 rw, rb_u32 rh) {
    if (!plane(dst,capacity,width,height) || !rw || !rh ||
        x>=width || y>=height || rw>width-x || rh>height-y) return -1;
    volatile rb_u8* write=dst;
    for (rb_u32 yy=y;yy<y+rh;++yy) {
        const rb_u64 start=(static_cast<rb_u64>(yy)*width+x)*4u;
        for (rb_u32 i=0;i<rw*4u;++i) write[start+i]=0;
    }
    return 0;
}
rb_i32 rb_compose_normal_rect(rb_u8* dst, rb_u64 dst_capacity,
    const rb_u8* src, rb_u64 src_capacity,
    rb_u32 width, rb_u32 height, float opacity,
    rb_u32 x, rb_u32 y, rb_u32 rw, rb_u32 rh) {
    if (!plane(dst,dst_capacity,width,height) ||
        !plane(src,src_capacity,width,height) ||
        !(opacity>=0.0f && opacity<=1.0f) ||
        !rw || !rh || x>=width || y>=height ||
        rw>width-x || rh>height-y) return -1;
    const rb_u64 bytes=static_cast<rb_u64>(width)*height*4u;
    Range d,s;
    if (!range(dst,bytes,1,d) || !range(src,bytes,1,s) ||
        !disjoint(d,s)) return -1;
    if (opacity==0.0f) return 0;
    for (rb_u32 yy=y;yy<y+rh;++yy) {
        const rb_u64 start=(static_cast<rb_u64>(yy)*width+x)*4u;
        const rb_u64 stop=start+static_cast<rb_u64>(rw)*4u;
        for (rb_u64 i=start;i<stop;i+=4u) {
            const float sa=(static_cast<float>(src[i+3])/255.0f)*opacity;
            if (sa==0.0f) continue;
            const float da=static_cast<float>(dst[i+3])/255.0f;
            const float remaining=da*(1.0f-sa);
            const float oa=sa+remaining;
            if (oa==0.0f) continue;
            const float inv=1.0f/oa;
            for (rb_u32 k=0;k<3u;++k) {
                float c=(static_cast<float>(src[i+k])*sa+
                    static_cast<float>(dst[i+k])*remaining)*inv;
                if (c>255.0f)c=255.0f;
                if (c<0.0f)c=0.0f;
                dst[i+k]=static_cast<rb_u8>(c+0.5f);
            }
            dst[i+3]=static_cast<rb_u8>(oa*255.0f+0.5f);
        }
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
            for (rb_u32 c = 0; c < 3; ++c) {
                float component = (static_cast<float>(src[c])*sa+
                    static_cast<float>(p[c])*rest)*inv;
                if (component > 255.0f) component=255.0f;
                if (component < 0.0f) component=0.0f;
                p[c]=static_cast<rb_u8>(component+0.5f);
            }
            p[3]=static_cast<rb_u8>(oa*255.0f+0.5f);
        }
    }
    return 0;
}


/* Independent four-connected bucket fill. Caller provides work buffers.
   No heap, CRT, callbacks or file I/O. Matches the original seed RGBA
   against a fixed per-channel absolute tolerance before each replacement. */
rb_i32 rb_flood_fill_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, rb_i32 x, rb_i32 y, rb_u32 rgba,
    rb_u32 tolerance, rb_u32* queue, rb_u64 queue_capacity,
    rb_u8* visited, rb_u64 visited_capacity, rb_u32* changed) {
    if (!plane(dst,capacity,width,height) ||
        !coordinate(width,height,x,y) || tolerance > 255u ||
        !queue || !visited || !changed) return -1;
    const rb_u64 pixels=static_cast<rb_u64>(width)*height;
    if (queue_capacity < pixels || visited_capacity < pixels) return -1;
    Range planeRange, queueRange, maskRange, countRange;
    if (!range(dst,pixels*4u,1,planeRange) ||
        !range(queue,pixels*sizeof(rb_u32),4,queueRange) ||
        !range(visited,pixels,1,maskRange) ||
        !range(changed,sizeof(rb_u32),4,countRange) ||
        !disjoint(planeRange,queueRange) ||
        !disjoint(planeRange,maskRange) ||
        !disjoint(planeRange,countRange) ||
        !disjoint(queueRange,maskRange) ||
        !disjoint(queueRange,countRange) ||
        !disjoint(maskRange,countRange)) return -1;
    const rb_u32 seed=static_cast<rb_u32>(y)*width+static_cast<rb_u32>(x);
    rb_u8 seedColor[4];
    for (rb_u32 k=0;k<4;++k) seedColor[k]=dst[static_cast<rb_u64>(seed)*4u+k];
    const rb_u32 replacement[4]={rgba>>24,(rgba>>16)&255u,(rgba>>8)&255u,rgba&255u};
    if (tolerance==0 && seedColor[0]==replacement[0] &&
        seedColor[1]==replacement[1] && seedColor[2]==replacement[2] &&
        seedColor[3]==replacement[3]) { *changed=0; return 0; }
    volatile rb_u8* cleared=visited;
    for (rb_u64 k=0;k<pixels;++k) cleared[k]=0;
    rb_u64 head=0,tail=1;
    queue[0]=seed;
    visited[seed]=1;
    rb_u32 changedCount=0;
    while (head<tail) {
        const rb_u32 at=queue[head++];
        rb_u8* target=dst+static_cast<rb_u64>(at)*4u;
        for (rb_u32 k=0;k<4;++k)
            target[k]=static_cast<rb_u8>(replacement[k]);
        ++changedCount;
        const rb_u32 xx=at%width, yy=at/width;
        for (rb_u32 side=0;side<4;++side) {
            if (side==0 && xx==0) continue;
            if (side==1 && xx+1==width) continue;
            if (side==2 && yy==0) continue;
            if (side==3 && yy+1==height) continue;
            const rb_u32 neighbor=(side==0?at-1u:
                side==1?at+1u:side==2?at-width:at+width);
            if (visited[neighbor]) continue;
            const rb_u8* nearPixel=dst+static_cast<rb_u64>(neighbor)*4u;
            bool similar=true;
            for (rb_u32 k=0;k<4;++k) {
                const rb_u32 a=nearPixel[k],b=seedColor[k];
                const rb_u32 delta=a>b?a-b:b-a;
                if (delta>tolerance) { similar=false;break; }
            }
            if (!similar) continue;
            visited[neighbor]=1;
            queue[tail++]=neighbor;
        }
    }
    *changed=changedCount;
    return 0;
}


/* Desktop-only rectangle/ellipse primitive; unlike ibisPaint's brush engine.
   Numeric ranges are validated before any pixel writes. */
rb_i32 rb_draw_shape_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, rb_i32 x0, rb_i32 y0,
    rb_i32 x1, rb_i32 y1, rb_u32 shape, rb_u32 filled,
    rb_u32 stroke_width, rb_u32 rgba) {
    if (!plane(dst,capacity,width,height) || shape>1u ||
        filled>1u || stroke_width<1u || stroke_width>128u ||
        x0 < -16384 || x0 > 16384 || y0 < -16384 || y0 > 16384 ||
        x1 < -16384 || x1 > 16384 || y1 < -16384 || y1 > 16384) return -1;
    const rb_i32 left = x0 < x1 ? x0 : x1;
    const rb_i32 right = x0 > x1 ? x0 : x1;
    const rb_i32 top = y0 < y1 ? y0 : y1;
    const rb_i32 bottom = y0 > y1 ? y0 : y1;
    if (right<0 || bottom<0 || left>=static_cast<rb_i32>(width) ||
        top>=static_cast<rb_i32>(height) || (rgba&255u)==0u) return 0;
    const rb_i32 clipL = left<0?0:left;
    const rb_i32 clipT = top<0?0:top;
    const rb_i32 clipR = right>=static_cast<rb_i32>(width)?
        static_cast<rb_i32>(width)-1:right;
    const rb_i32 clipB = bottom>=static_cast<rb_i32>(height)?
        static_cast<rb_i32>(height)-1:bottom;
    const float cx=(static_cast<float>(left)+static_cast<float>(right)+1.0f)*0.5f;
    const float cy=(static_cast<float>(top)+static_cast<float>(bottom)+1.0f)*0.5f;
    const float rx=static_cast<float>(right-left+1)*0.5f;
    const float ry=static_cast<float>(bottom-top+1)*0.5f;
    const float innerRx=rx-static_cast<float>(stroke_width);
    const float innerRy=ry-static_cast<float>(stroke_width);
    const float sourceAlpha=static_cast<float>(rgba&255u)/255.0f;
    const float oneMinusSource=1.0f-sourceAlpha;
    for (rb_i32 y=clipT;y<=clipB;++y) {
        for (rb_i32 x=clipL;x<=clipR;++x) {
            bool cover=false;
            if (shape==0u) {
                cover=filled!=0u || x-left<static_cast<rb_i32>(stroke_width) ||
                    right-x<static_cast<rb_i32>(stroke_width) ||
                    y-top<static_cast<rb_i32>(stroke_width) ||
                    bottom-y<static_cast<rb_i32>(stroke_width);
            } else {
                const float dx=static_cast<float>(x)+0.5f-cx;
                const float dy=static_cast<float>(y)+0.5f-cy;
                const float outer=dx*dx/(rx*rx)+dy*dy/(ry*ry);
                if (outer<=1.0f) {
                    cover=filled!=0u || innerRx<=0.0f || innerRy<=0.0f ||
                        dx*dx/(innerRx*innerRx)+dy*dy/(innerRy*innerRy)>=1.0f;
                }
            }
            if (!cover) continue;
            rb_u8* pixel=dst+(static_cast<rb_u64>(y)*width+x)*4u;
            const float dstAlpha=static_cast<float>(pixel[3])/255.0f;
            const float remainder=dstAlpha*oneMinusSource;
            const float outAlpha=sourceAlpha+remainder;
            const float inv=1.0f/outAlpha;
            for (rb_u32 channel=0;channel<3u;++channel) {
                const float src=static_cast<float>((rgba>>(24u-channel*8u))&255u);
                float component=(src*sourceAlpha+
                    static_cast<float>(pixel[channel])*remainder)*inv;
                if (component>255.0f) component=255.0f;
                if (component<0.0f) component=0.0f;
                pixel[channel]=static_cast<rb_u8>(component+0.5f);
            }
            pixel[3]=static_cast<rb_u8>(outAlpha*255.0f+0.5f);
        }
    }
    return 0;
}


/* Original desktop feather brush. Per-pixel coverage computed once per segment.
   Does not try to reproduce pressure/texture/stabilization of ibisPaint. */
rb_i32 rb_draw_feather_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter, rb_u32 rgba, float opacity, float hardness) {
    if (!plane(dst,capacity,width,height) ||
        !(diameter>=1.0f && diameter<=256.0f) ||
        !(opacity>=0.0f && opacity<=1.0f) ||
        !(hardness>=0.0f && hardness<=1.0f) ||
        !(x0>=-16384.0f && x0<=16384.0f) ||
        !(y0>=-16384.0f && y0<=16384.0f) ||
        !(x1>=-16384.0f && x1<=16384.0f) ||
        !(y1>=-16384.0f && y1<=16384.0f)) return -1;
    if (hardness==1.0f)
        return rb_draw_basic_stroke(dst,capacity,width,height,
            x0,y0,x1,y1,diameter,rgba,opacity);
    const float baseAlpha=(static_cast<float>(rgba&255u)/255.0f)*opacity;
    if (baseAlpha<=0.0f) return 0;
    const float radius=diameter*0.5f;
    const float outer2=radius*radius,inner=radius*hardness;
    const float inner2=inner*inner;
    const float dx=x1-x0,dy=y1-y0,len2=dx*dx+dy*dy;
    const float minX=(x0<x1?x0:x1)-radius-1.0f;
    const float maxX=(x0>x1?x0:x1)+radius+1.0f;
    const float minY=(y0<y1?y0:y1)-radius-1.0f;
    const float maxY=(y0>y1?y0:y1)+radius+1.0f;
    if (maxX<0.0f || maxY<0.0f ||
        minX>static_cast<float>(width) ||
        minY>static_cast<float>(height)) return 0;
    rb_i32 left=static_cast<rb_i32>(minX);
    rb_i32 right=static_cast<rb_i32>(maxX);
    rb_i32 top=static_cast<rb_i32>(minY);
    rb_i32 bottom=static_cast<rb_i32>(maxY);
    if (left<0) left=0;
    if (top<0) top=0;
    if (right>=static_cast<rb_i32>(width)) right=static_cast<rb_i32>(width)-1;
    if (bottom>=static_cast<rb_i32>(height)) bottom=static_cast<rb_i32>(height)-1;
    const float src[3]={
        static_cast<float>((rgba>>24)&255u),
        static_cast<float>((rgba>>16)&255u),
        static_cast<float>((rgba>>8)&255u)};
    for (rb_i32 y=top;y<=bottom;++y) {
        for (rb_i32 x=left;x<=right;++x) {
            const float cx=static_cast<float>(x)+0.5f;
            const float cy=static_cast<float>(y)+0.5f;
            float t=0.0f;
            if (len2>0.0f) {
                t=((cx-x0)*dx+(cy-y0)*dy)/len2;
                if (t<0.0f) t=0.0f;
                if (t>1.0f) t=1.0f;
            }
            const float px=cx-(x0+t*dx);
            const float py=cy-(y0+t*dy);
            const float dist2=px*px+py*py;
            if (dist2>=outer2) continue;
            const float coverage=dist2<=inner2?1.0f:
                (outer2-dist2)/(outer2-inner2);
            const float sa=baseAlpha*coverage;
            if (sa<=0.0f) continue;
            rb_u8* pixel=dst+(static_cast<rb_u64>(y)*width+x)*4u;
            const float da=static_cast<float>(pixel[3])/255.0f;
            const float remain=da*(1.0f-sa);
            const float oa=sa+remain;
            if (oa<=0.0f) continue;
            const float inv=1.0f/oa;
            for (rb_u32 channel=0;channel<3u;++channel) {
                float result=(src[channel]*sa+
                    static_cast<float>(pixel[channel])*remain)*inv;
                if (result>255.0f) result=255.0f;
                if (result<0.0f) result=0.0f;
                pixel[channel]=static_cast<rb_u8>(result+0.5f);
            }
            pixel[3]=static_cast<rb_u8>(oa*255.0f+0.5f);
        }
    }
    return 0;
}


/* Normalized anisotropic capsule: pixel-to-segment squared distance in a
   two-axis ellipse metric. Squared projections avoid sqrt/CRT dependencies. */
rb_i32 rb_draw_tilt_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter, rb_u32 rgba, float opacity, float hardness,
    float tilt_x, float tilt_y) {
    if (!plane(dst,capacity,width,height) ||
        !(diameter>=1.0f && diameter<=256.0f) ||
        !(opacity>=0.0f && opacity<=1.0f) ||
        !(hardness>=0.0f && hardness<=1.0f) ||
        !(tilt_x>=-90.0f && tilt_x<=90.0f) ||
        !(tilt_y>=-90.0f && tilt_y<=90.0f) ||
        !(x0>=-16384.0f && x0<=16384.0f) ||
        !(y0>=-16384.0f && y0<=16384.0f) ||
        !(x1>=-16384.0f && x1<=16384.0f) ||
        !(y1>=-16384.0f && y1<=16384.0f)) return -1;
    if (tilt_x==0.0f && tilt_y==0.0f) {
        if (hardness==1.0f)
            return rb_draw_basic_stroke(dst,capacity,width,height,
                x0,y0,x1,y1,diameter,rgba,opacity);
        return rb_draw_feather_stroke(dst,capacity,width,height,
            x0,y0,x1,y1,diameter,rgba,opacity,hardness);
    }
    const float srcAlpha=static_cast<float>(rgba&255u)/255.0f*opacity;
    if (srcAlpha<=0.0f) return 0;
    const float xt=tilt_x, yt=tilt_y;
    const float length2=xt*xt+yt*yt;
    const float tiltMax=(xt<0?-xt:xt)>(yt<0?-yt:yt)?
        (xt<0?-xt:xt):(yt<0?-yt:yt);
    const float strength=tiltMax/90.0f;
    const float radius=diameter*0.5f;
    const float major=radius*(1.0f+0.75f*strength);
    const float minor=radius*(1.0f-0.15f*strength);
    const float alongFactor=1.0f/(length2*major*major);
    const float acrossFactor=1.0f/(length2*minor*minor);
    const float segX=x1-x0,segY=y1-y0;
    const float alongSeg=segX*xt+segY*yt;
    const float acrossSeg=segY*xt-segX*yt;
    const float segMetric=alongSeg*alongSeg*alongFactor+
                          acrossSeg*acrossSeg*acrossFactor;
    const float minX=(x0<x1?x0:x1)-major-1.0f;
    const float minY=(y0<y1?y0:y1)-major-1.0f;
    const float maxX=(x0>x1?x0:x1)+major+1.0f;
    const float maxY=(y0>y1?y0:y1)+major+1.0f;
    if (maxX<0.0f || maxY<0.0f ||
        minX>=static_cast<float>(width) ||
        minY>=static_cast<float>(height)) return 0;
    rb_i32 left=static_cast<rb_i32>(minX),top=static_cast<rb_i32>(minY);
    rb_i32 right=static_cast<rb_i32>(maxX),bottom=static_cast<rb_i32>(maxY);
    if (left<0) left=0;
    if (top<0) top=0;
    if (right>=static_cast<rb_i32>(width)) right=static_cast<rb_i32>(width)-1;
    if (bottom>=static_cast<rb_i32>(height)) bottom=static_cast<rb_i32>(height)-1;
    const float inner2=hardness*hardness;
    const float src[3]={static_cast<float>((rgba>>24)&255u),
                        static_cast<float>((rgba>>16)&255u),
                        static_cast<float>((rgba>>8)&255u)};
    for (rb_i32 y=top;y<=bottom;++y) {
        for (rb_i32 x=left;x<=right;++x) {
            const float px=static_cast<float>(x)+0.5f-x0;
            const float py=static_cast<float>(y)+0.5f-y0;
            const float along=px*xt+py*yt;
            const float across=py*xt-px*yt;
            float t=0.0f;
            if (segMetric>0.0f) {
                t=(along*alongSeg*alongFactor+
                    across*acrossSeg*acrossFactor)/segMetric;
                if (t<0.0f)t=0.0f;
                if (t>1.0f)t=1.0f;
            }
            const float alongOffset=along-t*alongSeg;
            const float acrossOffset=across-t*acrossSeg;
            const float distance2=alongOffset*alongOffset*alongFactor+
                                  acrossOffset*acrossOffset*acrossFactor;
            if (distance2>=1.0f) continue;
            const float coverage=(hardness>=1.0f || distance2<=inner2)?1.0f:
                (1.0f-distance2)/(1.0f-inner2);
            const float sa=srcAlpha*coverage;
            if (sa<=0.0f) continue;
            rb_u8* pixel=dst+(static_cast<rb_u64>(y)*width+x)*4u;
            const float da=static_cast<float>(pixel[3])/255.0f;
            const float remain=da*(1.0f-sa),outA=sa+remain;
            if (outA<=0.0f) continue;
            const float inverse=1.0f/outA;
            for (rb_u32 channel=0;channel<3u;++channel) {
                float result=(src[channel]*sa+
                    static_cast<float>(pixel[channel])*remain)*inverse;
                if (result>255.0f) result=255.0f;
                if (result<0.0f) result=0.0f;
                pixel[channel]=static_cast<rb_u8>(result+0.5f);
            }
            pixel[3]=static_cast<rb_u8>(outA*255.0f+0.5f);
        }
    }
    return 0;
}


/* Stage 45: interpolate pressure-derived diameter/opacity across one
   segment, compositing each pixel only once. Existing primitives are
   called unchanged for constant endpoints. Not recovered Android code.
   style: 0 hard, 1 feather, 2 eraser, 3 tilted pen. */
rb_i32 rb_draw_pressure_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter0, float diameter1, rb_u32 rgba,
    float opacity0, float opacity1, float hardness,
    float tilt_x, float tilt_y, rb_u32 style) {
    if (!plane(dst,capacity,width,height) ||
        !(diameter0>=1.0f && diameter0<=256.0f) ||
        !(diameter1>=1.0f && diameter1<=256.0f) ||
        !(opacity0>=0.0f && opacity0<=1.0f) ||
        !(opacity1>=0.0f && opacity1<=1.0f) ||
        !(hardness>=0.0f && hardness<=1.0f) ||
        !(tilt_x>=-90.0f && tilt_x<=90.0f) ||
        !(tilt_y>=-90.0f && tilt_y<=90.0f) ||
        !(x0>=-16384.0f && x0<=16384.0f) ||
        !(y0>=-16384.0f && y0<=16384.0f) ||
        !(x1>=-16384.0f && x1<=16384.0f) ||
        !(y1>=-16384.0f && y1<=16384.0f) ||
        style>3u) return -1;
    if (diameter0==diameter1 && opacity0==opacity1) {
        if (style==2u) return rb_erase_basic_stroke(dst,capacity,
            width,height,x0,y0,x1,y1,diameter0,opacity0);
        if (style==3u) return rb_draw_tilt_stroke(dst,capacity,
            width,height,x0,y0,x1,y1,diameter0,rgba,opacity0,
            hardness,tilt_x,tilt_y);
        if (style==1u) return rb_draw_feather_stroke(dst,capacity,
            width,height,x0,y0,x1,y1,diameter0,rgba,opacity0,hardness);
        return rb_draw_basic_stroke(dst,capacity,
            width,height,x0,y0,x1,y1,diameter0,rgba,opacity0);
    }
    const bool oriented=style==3u && (tilt_x!=0.0f || tilt_y!=0.0f);
    const float maxD=diameter0>diameter1?diameter0:diameter1;
    const float absX=tilt_x<0?-tilt_x:tilt_x;
    const float absY=tilt_y<0?-tilt_y:tilt_y;
    const float strength=oriented?(absX>absY?absX:absY)/90.0f:0.0f;
    const float majorScale=1.0f+0.75f*strength;
    const float minorScale=1.0f-0.15f*strength;
    const float border=maxD*0.5f*majorScale+1.0f;
    const float minX=(x0<x1?x0:x1)-border;
    const float minY=(y0<y1?y0:y1)-border;
    const float maxX=(x0>x1?x0:x1)+border;
    const float maxY=(y0>y1?y0:y1)+border;
    if (maxX<0.0f || maxY<0.0f ||
        minX>=static_cast<float>(width) ||
        minY>=static_cast<float>(height)) return 0;
    rb_i32 left=static_cast<rb_i32>(minX);
    rb_i32 top=static_cast<rb_i32>(minY);
    rb_i32 right=static_cast<rb_i32>(maxX);
    rb_i32 bottom=static_cast<rb_i32>(maxY);
    if (left<0)left=0;
    if (top<0)top=0;
    if (right>=static_cast<rb_i32>(width))right=static_cast<rb_i32>(width)-1;
    if (bottom>=static_cast<rb_i32>(height))bottom=static_cast<rb_i32>(height)-1;
    const float dx=x1-x0,dy=y1-y0,seg2=dx*dx+dy*dy;
    const float tilt2=tilt_x*tilt_x+tilt_y*tilt_y;
    const float alongScale=oriented?1.0f/(tilt2*majorScale*majorScale):0.0f;
    const float acrossScale=oriented?1.0f/(tilt2*minorScale*minorScale):0.0f;
    const float segAlong=dx*tilt_x+dy*tilt_y;
    const float segAcross=dy*tilt_x-dx*tilt_y;
    const float metric2=segAlong*segAlong*alongScale+
        segAcross*segAcross*acrossScale;
    const float colorAlpha=static_cast<float>(rgba&255u)/255.0f;
    const float src[3]={
        static_cast<float>((rgba>>24)&255u),
        static_cast<float>((rgba>>16)&255u),
        static_cast<float>((rgba>>8)&255u)
    };
    for (rb_i32 y=top;y<=bottom;++y) {
        for (rb_i32 x=left;x<=right;++x) {
            const float px=static_cast<float>(x)+0.5f-x0;
            const float py=static_cast<float>(y)+0.5f-y0;
            float t=0.0f;
            if (oriented && metric2>0.0f) {
                const float along=px*tilt_x+py*tilt_y;
                const float across=py*tilt_x-px*tilt_y;
                t=(along*segAlong*alongScale+
                    across*segAcross*acrossScale)/metric2;
            } else if (seg2>0.0f) {
                t=(px*dx+py*dy)/seg2;
            }
            if (t<0.0f)t=0.0f;
            if (t>1.0f)t=1.0f;
            const float diameter=diameter0+(diameter1-diameter0)*t;
            const float radius2=diameter*diameter*0.25f;
            const float ex=px-t*dx,ey=py-t*dy;
            float distance2=ex*ex+ey*ey;
            if (oriented) {
                const float along=ex*tilt_x+ey*tilt_y;
                const float across=ey*tilt_x-ex*tilt_y;
                distance2=along*along*alongScale+
                    across*across*acrossScale;
            }
            const bool hard=style==0u || style==2u || hardness==1.0f;
            if (hard ? distance2>radius2 : distance2>=radius2)continue;
            float coverage=1.0f;
            if (!hard) {
                const float inner2=radius2*hardness*hardness;
                if (distance2>inner2)
                    coverage=(radius2-distance2)/(radius2-inner2);
            }
            const float alpha=(opacity0+(opacity1-opacity0)*t)*
                coverage*(style==2u?1.0f:colorAlpha);
            if (alpha<=0.0f)continue;
            rb_u8* pixel=dst+(static_cast<rb_u64>(y)*width+x)*4u;
            if (style==2u) {
                const rb_u8 a=static_cast<rb_u8>(
                    static_cast<float>(pixel[3])*(1.0f-alpha)+0.5f);
                pixel[3]=a;
                if (!a)pixel[0]=pixel[1]=pixel[2]=0;
                continue;
            }
            const float da=static_cast<float>(pixel[3])/255.0f;
            const float remain=da*(1.0f-alpha);
            const float outA=alpha+remain;
            if (outA<=0.0f)continue;
            const float inv=1.0f/outA;
            for (rb_u32 channel=0;channel<3u;++channel) {
                float c=(src[channel]*alpha+
                    static_cast<float>(pixel[channel])*remain)*inv;
                if (c<0.0f)c=0.0f;
                if (c>255.0f)c=255.0f;
                pixel[channel]=static_cast<rb_u8>(c+0.5f);
            }
            pixel[3]=static_cast<rb_u8>(outA*255.0f+0.5f);
        }
    }
    return 0;
}


/* Stage 47: per-gesture maximum opacity coverage, composited against
   the immutable pre-stroke snapshot. No heap allocation or full-plane
   iteration; each packet visits only the segment's bounded raster ROI. */
rb_i32 rb_draw_accumulated_stroke(rb_u8* dst, rb_u64 capacity,
    const rb_u8* baseline, rb_u64 baseline_capacity,
    rb_u8* coverage, rb_u64 coverage_capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter0, float diameter1, rb_u32 rgba,
    float opacity0, float opacity1, float hardness,
    float tilt_x, float tilt_y, rb_u32 style) {
    if (!plane(dst,capacity,width,height) ||
        !plane(baseline,baseline_capacity,width,height) ||
        !coverage ||
        coverage_capacity<static_cast<rb_u64>(width)*height ||
        !(diameter0>=1.0f && diameter0<=256.0f) ||
        !(diameter1>=1.0f && diameter1<=256.0f) ||
        !(opacity0>=0.0f && opacity0<=1.0f) ||
        !(opacity1>=0.0f && opacity1<=1.0f) ||
        !(hardness>=0.0f && hardness<=1.0f) ||
        !(tilt_x>=-90.0f && tilt_x<=90.0f) ||
        !(tilt_y>=-90.0f && tilt_y<=90.0f) ||
        !(x0>=-16384.0f && x0<=16384.0f) ||
        !(y0>=-16384.0f && y0<=16384.0f) ||
        !(x1>=-16384.0f && x1<=16384.0f) ||
        !(y1>=-16384.0f && y1<=16384.0f) ||
        style>3u) return -1;
    const rb_u64 pixel_count=static_cast<rb_u64>(width)*height;
    const rb_u64 plane_bytes=pixel_count*4u;
    Range rd,rb,rm;
    if (!range(dst,plane_bytes,1,rd) ||
        !range(baseline,plane_bytes,1,rb) ||
        !range(coverage,pixel_count,1,rm) ||
        !disjoint(rd,rb) || !disjoint(rd,rm) || !disjoint(rb,rm))
        return -1;
    const bool oriented=style==3u && (tilt_x!=0.0f || tilt_y!=0.0f);
    const float maxD=diameter0>diameter1?diameter0:diameter1;
    const float absX=tilt_x<0?-tilt_x:tilt_x;
    const float absY=tilt_y<0?-tilt_y:tilt_y;
    const float strength=oriented?(absX>absY?absX:absY)/90.0f:0.0f;
    const float majorScale=1.0f+0.75f*strength;
    const float minorScale=1.0f-0.15f*strength;
    const float border=maxD*0.5f*majorScale+1.0f;
    const float minX=(x0<x1?x0:x1)-border;
    const float minY=(y0<y1?y0:y1)-border;
    const float maxX=(x0>x1?x0:x1)+border;
    const float maxY=(y0>y1?y0:y1)+border;
    if (maxX<0.0f || maxY<0.0f ||
        minX>=static_cast<float>(width) ||
        minY>=static_cast<float>(height)) return 0;
    rb_i32 left=static_cast<rb_i32>(minX);
    rb_i32 top=static_cast<rb_i32>(minY);
    rb_i32 right=static_cast<rb_i32>(maxX);
    rb_i32 bottom=static_cast<rb_i32>(maxY);
    if (left<0)left=0;
    if (top<0)top=0;
    if (right>=static_cast<rb_i32>(width))right=static_cast<rb_i32>(width)-1;
    if (bottom>=static_cast<rb_i32>(height))bottom=static_cast<rb_i32>(height)-1;
    const float dx=x1-x0,dy=y1-y0,seg2=dx*dx+dy*dy;
    const float tilt2=tilt_x*tilt_x+tilt_y*tilt_y;
    const float alongScale=oriented?1.0f/(tilt2*majorScale*majorScale):0.0f;
    const float acrossScale=oriented?1.0f/(tilt2*minorScale*minorScale):0.0f;
    const float segAlong=dx*tilt_x+dy*tilt_y;
    const float segAcross=dy*tilt_x-dx*tilt_y;
    const float metric2=segAlong*segAlong*alongScale+
        segAcross*segAcross*acrossScale;
    const float colorAlpha=static_cast<float>(rgba&255u)/255.0f;
    const float src[3]={
        static_cast<float>((rgba>>24)&255u),
        static_cast<float>((rgba>>16)&255u),
        static_cast<float>((rgba>>8)&255u)
    };
    for (rb_i32 y=top;y<=bottom;++y) {
        for (rb_i32 x=left;x<=right;++x) {
            const float px=static_cast<float>(x)+0.5f-x0;
            const float py=static_cast<float>(y)+0.5f-y0;
            float t=0.0f;
            if (oriented && metric2>0.0f) {
                const float along=px*tilt_x+py*tilt_y;
                const float across=py*tilt_x-px*tilt_y;
                t=(along*segAlong*alongScale+
                    across*segAcross*acrossScale)/metric2;
            } else if (seg2>0.0f) {
                t=(px*dx+py*dy)/seg2;
            }
            if (t<0.0f)t=0.0f;
            if (t>1.0f)t=1.0f;
            const float diameter=diameter0+(diameter1-diameter0)*t;
            const float radius2=diameter*diameter*0.25f;
            const float ex=px-t*dx,ey=py-t*dy;
            float distance2=ex*ex+ey*ey;
            if (oriented) {
                const float along=ex*tilt_x+ey*tilt_y;
                const float across=ey*tilt_x-ex*tilt_y;
                distance2=along*along*alongScale+
                    across*across*acrossScale;
            }
            const bool hard=style==0u || style==2u || hardness==1.0f;
            if (hard ? distance2>radius2 : distance2>=radius2)continue;
            float featherCoverage=1.0f;
            if (!hard) {
                const float inner2=radius2*hardness*hardness;
                if (distance2>inner2)
                    featherCoverage=(radius2-distance2)/(radius2-inner2);
            }
            const float alpha=(opacity0+(opacity1-opacity0)*t)*
                featherCoverage*(style==2u?1.0f:colorAlpha);
            if (alpha<=0.0f)continue;
            const rb_u64 index=static_cast<rb_u64>(y)*width+x;
            const rb_u8 weight=static_cast<rb_u8>(alpha*255.0f+0.5f);
            if (weight<=coverage[index]) continue;
            coverage[index]=weight;
            const float new_alpha=static_cast<float>(weight)/255.0f;
            const rb_u8* original=baseline+index*4u;
            rb_u8* pixel=dst+index*4u;
            if (style==2u) {
                const rb_u8 a=static_cast<rb_u8>(
                    static_cast<float>(original[3])*(1.0f-new_alpha)+0.5f);
                pixel[3]=a;
                if (!a) pixel[0]=pixel[1]=pixel[2]=0;
                else for (rb_u32 channel=0;channel<3u;++channel)
                    pixel[channel]=original[channel];
                continue;
            }
            const float da=static_cast<float>(original[3])/255.0f;
            const float remain=da*(1.0f-new_alpha);
            const float outA=new_alpha+remain;
            if (outA<=0.0f)continue;
            const float inv=1.0f/outA;
            for (rb_u32 channel=0;channel<3u;++channel) {
                float c=(src[channel]*new_alpha+
                    static_cast<float>(original[channel])*remain)*inv;
                if (c<0.0f)c=0.0f;
                if (c>255.0f)c=255.0f;
                pixel[channel]=static_cast<rb_u8>(c+0.5f);
            }
            pixel[3]=static_cast<rb_u8>(outA*255.0f+0.5f);
        }
    }
    return 0;
}



/* Reversible, allocation-free flip of a native RGBA8 raster. */
rb_i32 rb_flip_rgba(rb_u8* dst,rb_u64 capacity,
    rb_u32 width,rb_u32 height,rb_u32 axis) {
    if (!plane(dst,capacity,width,height) || axis>1u) return -1;
    if (axis==0u) {
        for (rb_u32 y=0;y<height;++y) {
            for (rb_u32 x=0;x<width/2;++x) {
                rb_u8* left=dst+(static_cast<rb_u64>(y)*width+x)*4u;
                rb_u8* right=dst+(static_cast<rb_u64>(y)*width+(width-1u-x))*4u;
                for (rb_u32 c=0;c<4u;++c) {
                    const rb_u8 tmp=left[c];left[c]=right[c];right[c]=tmp;
                }
            }
        }
    } else {
        for (rb_u32 y=0;y<height/2;++y) {
            for (rb_u32 x=0;x<width;++x) {
                rb_u8* top=dst+(static_cast<rb_u64>(y)*width+x)*4u;
                rb_u8* bottom=dst+(static_cast<rb_u64>(height-1u-y)*width+x)*4u;
                for (rb_u32 c=0;c<4u;++c) {
                    const rb_u8 tmp=top[c];top[c]=bottom[c];bottom[c]=tmp;
                }
            }
        }
    }
    return 0;
}
