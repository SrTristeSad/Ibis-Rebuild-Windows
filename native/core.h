#ifndef RB_CORE_H
#define RB_CORE_H

/* Original desktop reconstruction kernel. ABI v1, fixed-width, caller-owned memory.
   No Android/ibisPaint/Inkora source, headers, or binary code is linked here. */
typedef unsigned char rb_u8;
typedef unsigned int rb_u32;
typedef int rb_i32;
typedef unsigned long long rb_u64;
typedef long long rb_i64;

#ifdef _WIN32
# define RB_EXPORT __declspec(dllexport)
#else
# define RB_EXPORT __attribute__((visibility("default")))
#endif
#ifdef __cplusplus
# define RB_EXTERN extern "C"
#else
# define RB_EXTERN extern
#endif
#define RB_API RB_EXTERN RB_EXPORT

/* Natural x64 layout: seven floats, padding before time, trailing padding.
   sizeof=56, time offset=40, is_stylus offset=48. Query rb_sample_size(). */
typedef struct RBSample {
    rb_i32 pointer_id;
    rb_i32 pointer_info;
    float x, y, previous_x, previous_y;
    float pressure, altitude, azimuth;
    rb_i64 time;
    rb_u32 is_stylus;
} RBSample;

/* Unless stated otherwise: 0 success, -1 invalid argument/capacity/dimension.
   No ownership transfer, allocation, file I/O, global mutable state or network.
   Pixel buffers contain bytewise RGBA, while scalar rgba means 0xRRGGBBAA.
   Dimensions 1..8192 are an explicit desktop engineering bound, not an
   observed Android limit. Capacity counts bytes, except pack element counts.
   Buffers must point to valid memory of the advertised size. */
RB_API rb_u32 rb_version(void);
RB_API rb_u32 rb_sample_size(void);
RB_API float rb_normalize_pressure(float raw, rb_i32 enabled, float low, float high);
/* 1 accepted, 0 rejected, -1 null state. Accepted signed value is unchanged. */
RB_API rb_i32 rb_thickness_update(float* current, float proposed);
/* All buffers must be naturally aligned and mutually disjoint. Validation
   failure writes nothing. Empty count permits null pointers. Array layouts:
   ints[2i]=id, ints[2i+1]=info;
   floats[7i..+6]=x,y,previous_x,previous_y,pressure,altitude,azimuth;
   times[i]=time. Non-stylus angle slots are positive zero. */
RB_API rb_i32 rb_pack_samples(const RBSample* samples, rb_u64 count,
    rb_i32* ints, rb_u64 int_capacity, float* floats, rb_u64 float_capacity,
    rb_i64* times, rb_u64 time_capacity);
RB_API rb_i32 rb_clear(rb_u8* dst, rb_u64 capacity, rb_u32 width,
    rb_u32 height, rb_u32 rgba);
RB_API rb_i32 rb_set_pixel(rb_u8* dst, rb_u64 capacity, rb_u32 width,
    rb_u32 height, rb_i32 x, rb_i32 y, rb_u32 rgba);
RB_API rb_i32 rb_get_pixel(const rb_u8* src, rb_u64 capacity, rb_u32 width,
    rb_u32 height, rb_i32 x, rb_i32 y, rb_u32* rgba);


/* Desktop-only, explicitly non-equivalent basic continuous round brush.
   Renders one hard-edged capsule segment to the caller-owned RGBA8 plane
   using straight-alpha source-over. Coordinates denote pixel centers
   at (i+0.5, j+0.5). Diameter 1..256, opacity 0..1, bounded finite
   coordinates are required. One segment covers each pixel at most once.
   This is not the recovered ibisPaint brush algorithm. */
RB_API rb_i32 rb_draw_basic_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter, rb_u32 rgba, float opacity);

#endif
