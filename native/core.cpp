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
