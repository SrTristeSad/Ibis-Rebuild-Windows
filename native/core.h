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


/* Desktop-only RGBA8 "source over" on two distinct caller-owned planes.
   Applied to each layer from bottom to top. Normal blend mode only;
   clipping, group isolation and Android's compositor remain unknown.
   0 success, -1 validation failure; no writes on invalid inputs.
   Alpha is straight, pixels are RGBA, opacity must be finite [0,1].
   Source and destination ranges must not overlap. ABI v1 is extended. */
RB_API rb_i32 rb_compose_normal(rb_u8* dst, rb_u64 dst_capacity,
    const rb_u8* src, rb_u64 src_capacity,
    rb_u32 width, rb_u32 height, float opacity);


/* Desktop hard-round eraser: destination-out alpha, NOT Android equivalence.
   Same segment geometry/coordinate contract as rb_draw_basic_stroke.
   opacity [0,1] decreases alpha once per covered pixel; zero-alpha pixels
   are canonicalized to transparent black. Invalid calls modify no bytes. */
RB_API rb_i32 rb_erase_basic_stroke(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, float x0, float y0, float x1, float y1,
    float diameter, float opacity);


/* Native rectangle translation on disjoint scratch and selected raster. */
RB_API rb_i32 rb_move_rect_rgba(rb_u8* dst, rb_u64 capacity, rb_u32 width, rb_u32 height, rb_i32 sx, rb_i32 sy, rb_u32 rw, rb_u32 rh, rb_i32 tx, rb_i32 ty, rb_u8* scratch, rb_u64 scratch_capacity);


/* Independent, 90-degree-step rotated and nearest-neighbor resized RGBA8
   rectangular selection. source and destination are entirely on canvas.
   quarter_turns: 0, 1 (clockwise 90), 2, 3 (counterclockwise 90).
   Scratch: disjoint sourceWidth*sourceHeight*4 bytes; caller owns memory.
   On invalid input, writes nothing. Snapshot precedes clearing. */
RB_API rb_i32 rb_transform_rect_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height,
    rb_i32 sx, rb_i32 sy, rb_u32 sw, rb_u32 sh,
    rb_i32 tx, rb_i32 ty, rb_u32 tw, rb_u32 th,
    rb_u32 quarter_turns, rb_u8* scratch, rb_u64 scratch_capacity);


/* Independent contiguous RGBA8 bucket fill using 4-neighbor connectivity.
   tolerance 0..255: each RGBA channel must differ from seed by <= tolerance.
   Writes replacement RGBA exactly, including alpha. No blending.
   queue has >= width*height 32-bit entries; visited has >= width*height bytes,
   is initialized by C++, and must be disjoint from queue, plane and changed.
   Validations fail atomically before writing. changed receives pixel count. */
RB_API rb_i32 rb_flood_fill_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, rb_i32 x, rb_i32 y, rb_u32 rgba,
    rb_u32 tolerance, rb_u32* queue, rb_u64 queue_capacity,
    rb_u8* visited, rb_u64 visited_capacity, rb_u32* changed);


/* Independent RGBA8 rectangle/ellipse rasterizer.
   shape 0=rectangle, 1=ellipse; filled 0=inner outline, 1=solid.
   x0,y0,x1,y1 are inclusive integer pixel coordinates (drag corners),
   may be reversed, and may lie outside canvas within [-16384,16384].
   width in [1,128] is inward-facing outline thickness. Colors blend as
   straight-alpha source-over, with each target pixel covered once.
   0 success, -1 invalid arguments, no writes on invalid input. */
RB_API rb_i32 rb_draw_shape_rgba(rb_u8* dst, rb_u64 capacity,
    rb_u32 width, rb_u32 height, rb_i32 x0, rb_i32 y0,
    rb_i32 x1, rb_i32 y1, rb_u32 shape, rb_u32 filled,
    rb_u32 stroke_width, rb_u32 rgba);

#endif
