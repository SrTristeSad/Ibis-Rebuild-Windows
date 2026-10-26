"""Execute the real C++ ABI through ctypes; no Python fallback is substituted.

Run: python -m unittest discover -s tests -p test_core.py -v
RB_CORE_DLL can point to a built Windows DLL (or a host .so for contract checks).
Reference pressure arithmetic is an independent IEEE-float contract oracle,
not execution of the original Android application.
"""
import ctypes as C
import math
import os
from pathlib import Path
import random
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
U8, U32, I32, U64, I64, F32 = C.c_uint8, C.c_uint32, C.c_int32, C.c_uint64, C.c_int64, C.c_float


class Sample(C.Structure):
    _fields_ = [
        ('pointer_id', I32), ('pointer_info', I32),
        ('x', F32), ('y', F32), ('previous_x', F32), ('previous_y', F32),
        ('pressure', F32), ('altitude', F32), ('azimuth', F32),
        ('time', I64), ('is_stylus', U32),
    ]



class InkEvent(C.Structure):
    _fields_=[
        ('kind',I32),('pointer_id',U32),('x',F32),('y',F32),
        ('pressure',F32),('tilt_x',I32),('tilt_y',I32),
        ('flags',U32),('mask',U32),('client_width',U32),
        ('client_height',U32),
    ]


def float32(value):
    try:
        return struct.unpack('<f', struct.pack('<f', value))[0]
    except OverflowError:
        return math.copysign(math.inf, value)


def float_bits(value):
    return struct.unpack('<I', struct.pack('<f', value))[0]


def reference_pressure(raw, enabled, low, high):
    if not enabled:
        return 1.0
    raw, low, high = map(float32, (raw, low, high))
    numerator = float32(raw - low)
    denominator = float32(high - low)
    if denominator == 0.0:
        if numerator == 0.0 or math.isnan(numerator):
            normalized = math.nan
        else:
            normalized = math.copysign(math.inf,
                math.copysign(1.0, numerator) * math.copysign(1.0, denominator))
    else:
        normalized = float32(numerator / denominator)
    if math.isnan(normalized):
        return math.nan
    if normalized <= 0.0:
        return 0.0  # Math.max(+0, -0) is +0.
    return min(normalized, 1.0)


class KernelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(os.environ.get('RB_CORE_DLL', ROOT / 'build' / 'rebuild_core.dll'))
        if not path.exists():
            raise RuntimeError(f'Build the C++ kernel first; missing {path}. No fallback was run.')
        cls.lib = C.CDLL(str(path.resolve()))
        signatures = {
            'rb_version': (U32, []),
            'rb_sample_size': (U32, []),
            'rb_normalize_pressure': (F32, [F32, I32, F32, F32]),
            'rb_thickness_update': (I32, [C.POINTER(F32), F32]),
            'rb_pack_samples': (I32, [C.POINTER(Sample), U64, C.POINTER(I32), U64,
                C.POINTER(F32), U64, C.POINTER(I64), U64]),
            'rb_clear': (I32, [C.POINTER(U8), U64, U32, U32, U32]),
            'rb_set_pixel': (I32, [C.POINTER(U8), U64, U32, U32, I32, I32, U32]),
            'rb_get_pixel': (I32, [C.POINTER(U8), U64, U32, U32, I32, I32, C.POINTER(U32)]),
            'rb_draw_basic_stroke': (I32, [C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, U32, F32]),
            'rb_draw_feather_stroke': (I32, [C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, U32, F32, F32]),
            'rb_draw_tilt_stroke': (I32, [C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, U32, F32, F32, F32, F32]),
            'rb_draw_pressure_stroke': (I32, [C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, F32, U32, F32, F32, F32,
                F32, F32, U32]),
            'rb_draw_accumulated_stroke': (I32, [
                C.POINTER(U8), U64, C.POINTER(U8), U64,
                C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, F32, U32, F32, F32, F32,
                F32, F32, U32]),
            'rb_compose_normal': (I32, [C.POINTER(U8), U64, C.POINTER(U8), U64,
                U32, U32, F32]),
            'rb_move_rect_rgba': (I32, [C.POINTER(U8), U64, U32, U32,
                I32, I32, U32, U32, I32, I32, C.POINTER(U8), U64]),
            'rb_transform_rect_rgba': (I32, [C.POINTER(U8), U64, U32, U32,
                I32, I32, U32, U32, I32, I32, U32, U32, U32, C.POINTER(U8), U64]),
            'rb_flood_fill_rgba': (I32, [C.POINTER(U8), U64, U32, U32,
                I32, I32, U32, U32, C.POINTER(U32), U64,
                C.POINTER(U8), U64, C.POINTER(U32)]),
            'rb_draw_shape_rgba': (I32, [C.POINTER(U8), U64, U32, U32,
                I32, I32, I32, I32, U32, U32, U32, U32]),
            'rb_erase_basic_stroke': (I32, [C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, F32]),

            'rb_ink_attach': (I32, []),
            'rb_ink_detach': (I32, []),
            'rb_ink_is_attached': (I32, []),
            'rb_ink_mouse_guard': (I32, []),
            'rb_ink_poll': (I32, [C.POINTER(InkEvent), U32]),
            'rb_ink_dropped': (U32, []),
            'rb_ink_pressure': (F32, [U32,U32]),
        }
        for name, (result, args) in signatures.items():
            method = getattr(cls.lib, name)
            method.restype, method.argtypes = result, args

    def assertFloatSame(self, actual, expected):
        if math.isnan(expected):
            self.assertTrue(math.isnan(actual))
        else:
            self.assertEqual(float_bits(actual), float_bits(expected))

    def test_abi_layout(self):
        self.assertEqual(self.lib.rb_version(), 1)
        self.assertEqual(C.sizeof(Sample), 56)
        self.assertEqual(self.lib.rb_sample_size(), C.sizeof(Sample))
        self.assertEqual(Sample.time.offset, 40)
        self.assertEqual(Sample.is_stylus.offset, 48)
        self.assertEqual(Sample.pressure.offset, 24)

    def test_pressure_finite_range(self):
        for raw, low, high in [(0.5, 0, 1), (2, 0, 1), (-2, 0, 1),
                (4, 2, 6), (2, 6, 2), (5, 6, 2), (8, 6, 2)]:
            with self.subTest(raw=raw, low=low, high=high):
                self.assertFloatSame(self.lib.rb_normalize_pressure(raw, 1, low, high),
                    reference_pressure(raw, True, low, high))

    def test_disabled_pressure_always_one(self):
        for raw in [math.nan, math.inf, -math.inf, -0.0, 0, 0.5, 10]:
            self.assertFloatSame(self.lib.rb_normalize_pressure(raw, 0, math.nan, math.nan), 1)

    def test_pressure_nan_in_each_input(self):
        for args in [(math.nan, 1, 0, 1), (0.5, 1, math.nan, 1), (0.5, 1, 0, math.nan)]:
            self.assertTrue(math.isnan(self.lib.rb_normalize_pressure(*args)))

    def test_pressure_zero_denominator_is_not_replaced_by_default(self):
        for raw, low, high in [(0, 0, 0), (1, 0, 0), (-1, 0, 0),
                (2, 2, 2), (-1, 0.0, -0.0), (1, 0.0, -0.0)]:
            with self.subTest(raw=raw, low=low, high=high):
                self.assertFloatSame(self.lib.rb_normalize_pressure(raw, 1, low, high),
                    reference_pressure(raw, True, low, high))

    def test_pressure_infinities_and_signed_zero(self):
        for raw, low, high in [(math.inf, 0, 1), (-math.inf, 0, 1),
                (1, 0, math.inf), (math.inf, 0, math.inf),
                (1, -math.inf, math.inf), (-0.0, 0, 1), (0, -0.0, 1)]:
            self.assertFloatSame(self.lib.rb_normalize_pressure(raw, -1, low, high),
                reference_pressure(raw, True, low, high))

    def test_pressure_float_rounding_random_contract(self):
        rng = random.Random(1412)
        for _ in range(1000):
            raw, low, high = [struct.unpack('<f', rng.getrandbits(32).to_bytes(4, 'little'))[0]
                for _ in range(3)]
            self.assertFloatSame(self.lib.rb_normalize_pressure(raw, 1, low, high),
                reference_pressure(raw, True, low, high))

    def test_thickness_accepts_negative_and_exact_boundaries(self):
        state = F32(0.125)
        for value in [-2.0, -1.75, -0.0, 0.0, 0.125, 2.0]:
            self.assertEqual(self.lib.rb_thickness_update(C.byref(state), value), 1)
            self.assertFloatSame(state.value, value)

    def test_thickness_rejection_preserves_state(self):
        state = F32(-0.25)
        for value in [math.nan, math.inf, -math.inf, 2.000001, -2.000001, 100]:
            self.assertEqual(self.lib.rb_thickness_update(C.byref(state), value), 0)
            self.assertFloatSame(state.value, -0.25)
        self.assertEqual(self.lib.rb_thickness_update(None, 0), -1)

    def sample_buffers(self):
        samples = (Sample * 2)(
            Sample(17, -4, 12, 13, 10, 11, 0.25, 0.75, 1.25, 2**45 + 17, 1),
            Sample(-2, 0x7fffffff, 20, 21, 18, 19, 1, 999, -999, -123456789, 0))
        return samples, (I32 * 4)(*([99] * 4)), (F32 * 14)(*([99] * 14)), (I64 * 2)(99, 99)

    def test_pack_exact_layout_and_nonstylus_zero_angles(self):
        samples, ints, floats, times = self.sample_buffers()
        self.assertEqual(self.lib.rb_pack_samples(samples, 2, ints, 4, floats, 14, times, 2), 0)
        self.assertEqual(list(ints), [17, -4, -2, 0x7fffffff])
        self.assertEqual(list(floats), [12, 13, 10, 11, .25, .75, 1.25,
            20, 21, 18, 19, 1, 0, 0])
        self.assertEqual(list(times), [2**45 + 17, -123456789])
        self.assertEqual(float_bits(floats[12]), 0)
        self.assertEqual(float_bits(floats[13]), 0)

    def test_pack_pressure_and_angles_are_not_implicitly_normalized(self):
        samples, ints, floats, times = self.sample_buffers()
        samples[0].pressure = math.nan
        samples[0].altitude = -100.25
        self.assertEqual(self.lib.rb_pack_samples(samples, 1, ints, 4, floats, 14, times, 2), 0)
        self.assertTrue(math.isnan(floats[4]))
        self.assertEqual(floats[5], -100.25)
        self.assertEqual(ints[2], 99)
        self.assertEqual(times[1], 99)

    def test_pack_short_capacity_failure_is_atomic(self):
        for icap, fcap, tcap in [(3, 14, 2), (4, 13, 2), (4, 14, 1)]:
            samples, ints, floats, times = self.sample_buffers()
            self.assertEqual(self.lib.rb_pack_samples(samples, 2, ints, icap, floats, fcap, times, tcap), -1)
            self.assertEqual(list(ints), [99] * 4)
            self.assertEqual(list(floats), [99] * 14)
            self.assertEqual(list(times), [99] * 2)

    def test_pack_empty_null_and_overflow(self):
        self.assertEqual(self.lib.rb_pack_samples(None, 0, None, 0, None, 0, None, 0), 0)
        self.assertEqual(self.lib.rb_pack_samples(None, 1, None, 2, None, 7, None, 1), -1)
        self.assertEqual(self.lib.rb_pack_samples(None, 2**64 - 1, None, 2**64 - 1,
            None, 2**64 - 1, None, 2**64 - 1), -1)

    def test_pack_overlapping_output_failure_is_atomic(self):
        samples, ints, floats, times = self.sample_buffers()
        storage = (U8 * 96)(*([0x53] * 96))
        ints = C.cast(storage, C.POINTER(I32))
        floats = C.cast(storage, C.POINTER(F32))
        self.assertEqual(self.lib.rb_pack_samples(samples, 2, ints, 4, floats, 14, times, 2), -1)
        self.assertEqual(bytes(storage), bytes([0x53] * 96))
        self.assertEqual(list(times), [99, 99])

    def test_pack_unaligned_pointer_failure_is_atomic(self):
        samples, ints, floats, times = self.sample_buffers()
        raw = (U8 * 32)(*([0x46] * 32))
        bad = C.cast(C.byref(raw, 1), C.POINTER(I32))
        self.assertEqual(self.lib.rb_pack_samples(samples, 2, bad, 4, floats, 14, times, 2), -1)
        self.assertEqual(bytes(raw), bytes([0x46] * 32))

    def test_pack_input_output_overlap_preserves_samples(self):
        samples, ints, floats, times = self.sample_buffers()
        before = bytes(samples)
        aliased_ints = C.cast(samples, C.POINTER(I32))
        self.assertEqual(self.lib.rb_pack_samples(samples, 2, aliased_ints, 4,
            floats, 14, times, 2), -1)
        self.assertEqual(bytes(samples), before)
        self.assertEqual(list(floats), [99] * 14)
        self.assertEqual(list(times), [99, 99])

    def test_clear_rgba_order_capacity_and_guard_bytes(self):
        raw = (U8 * 32)(*([0xA7] * 32))
        ptr = C.cast(C.byref(raw, 4), C.POINTER(U8))
        self.assertEqual(self.lib.rb_clear(ptr, 24, 3, 2, 0x12345678), 0)
        self.assertEqual(bytes(raw[:4]), bytes([0xA7] * 4))
        self.assertEqual(bytes(raw[4:28]), bytes.fromhex('12345678') * 6)
        self.assertEqual(bytes(raw[28:]), bytes([0xA7] * 4))

    def test_clear_transparent_and_opaque(self):
        pixels = (U8 * 8)()
        for color in [0, 0xffffffff, 0x000000ff, 0xff000000]:
            self.assertEqual(self.lib.rb_clear(pixels, 8, 2, 1, color), 0)
            self.assertEqual(bytes(pixels), color.to_bytes(4, 'big') * 2)

    def test_plane_invalid_arguments_do_not_write(self):
        for width, height, capacity in [(0, 1, 16), (1, 0, 16), (8193, 1, 16),
                (1, 8193, 16), (2**32 - 1, 2**32 - 1, 2**64 - 1), (2, 2, 15)]:
            pixels = (U8 * 16)(*([0x41] * 16))
            self.assertEqual(self.lib.rb_clear(pixels, capacity, width, height, 0), -1)
            self.assertEqual(bytes(pixels), bytes([0x41] * 16))
        self.assertEqual(self.lib.rb_clear(None, 4, 1, 1, 0), -1)

    def test_pixel_coordinates_and_roundtrip(self):
        w, h = 7, 3
        pixels = (U8 * (w * h * 4))()
        self.lib.rb_clear(pixels, len(pixels), w, h, 0)
        for y in range(h):
            for x in range(w):
                color = (x << 24) | (y << 16) | ((x + y) << 8) | 0x7f
                self.assertEqual(self.lib.rb_set_pixel(pixels, len(pixels), w, h, x, y, color), 0)
                out = U32(0)
                self.assertEqual(self.lib.rb_get_pixel(pixels, len(pixels), w, h, x, y, C.byref(out)), 0)
                self.assertEqual(out.value, color)
                self.assertEqual(bytes(pixels[(y*w+x)*4:(y*w+x+1)*4]), color.to_bytes(4, 'big'))

    def test_pixel_bounds_fail_without_modification(self):
        pixels = (U8 * 24)(*([0x38] * 24))
        for x, y in [(-1, 0), (0, -1), (3, 0), (0, 2), (2**31-1, 2**31-1)]:
            out = U32(0x12345678)
            self.assertEqual(self.lib.rb_set_pixel(pixels, 24, 3, 2, x, y, 0), -1)
            self.assertEqual(self.lib.rb_get_pixel(pixels, 24, 3, 2, x, y, C.byref(out)), -1)
            self.assertEqual(out.value, 0x12345678)
            self.assertEqual(bytes(pixels), bytes([0x38] * 24))
        self.assertEqual(self.lib.rb_get_pixel(pixels, 24, 3, 2, 0, 0, None), -1)


    def test_basic_stroke_continuous_line_is_not_discrete_pixels(self):
        pixels = (U8 * (7 * 7 * 4))()
        self.assertEqual(self.lib.rb_clear(pixels, len(pixels), 7, 7, 0), 0)
        result = self.lib.rb_draw_basic_stroke(pixels, len(pixels), 7, 7,
            1.5, 3.5, 5.5, 3.5, 1.0, 0xe12a04ff, 1.0)
        self.assertEqual(result, 0)
        for y in range(7):
            for x in range(7):
                at = (y * 7 + x) * 4
                expected = bytes.fromhex('e12a04ff') if y == 3 and 1 <= x <= 5 else bytes(4)
                self.assertEqual(bytes(pixels[at:at+4]), expected)

    def test_basic_stroke_alpha_blends_once_with_opaque_destination(self):
        pixels = (U8 * 64)()
        self.assertEqual(self.lib.rb_clear(pixels, 64, 4, 4, 0x0000ffff), 0)
        self.assertEqual(self.lib.rb_draw_basic_stroke(
            pixels, 64, 4, 4, 1.5, 1.5, 1.5, 1.5, 1.0, 0xff0000ff, .5), 0)
        r, g, b, a = bytes(pixels[(1*4+1)*4:(1*4+2)*4])
        self.assertIn(r, (127, 128))
        self.assertEqual(g, 0)
        self.assertIn(b, (127, 128))
        self.assertEqual(a, 255)
        self.assertEqual(bytes(pixels[:4]), bytes.fromhex('0000ffff'))

    def test_basic_stroke_clips_segment_to_document(self):
        pixels = (U8 * 32)()
        self.assertEqual(self.lib.rb_clear(pixels, 32, 4, 2, 0), 0)
        self.assertEqual(self.lib.rb_draw_basic_stroke(
            pixels, 32, 4, 2, -3.5, .5, 1.5, .5, 1.0, 0xabcdefe0, 1), 0)
        for x in range(4):
            self.assertEqual(bytes(pixels[x*4:x*4+4]),
                bytes.fromhex('abcdefe0') if x <= 1 else bytes(4))

    def test_basic_stroke_invalid_inputs_leave_plane_intact(self):
        pixels = (U8 * 64)(*([0x38] * 64))
        for diameter, opacity, x0 in [
            (0, 1, 1), (257, 1, 1), (math.nan, 1, 1),
            (1, math.inf, 1), (1, -.1, 1), (1, 1, math.nan),
            (1, 1, math.inf), (1, 1, 20000)]:
            self.assertEqual(self.lib.rb_draw_basic_stroke(
                pixels, 64, 4, 4, x0, 1, 2, 1, diameter, 0xff0000ff, opacity), -1)
            self.assertEqual(bytes(pixels), bytes([0x38] * 64))
        self.assertEqual(self.lib.rb_draw_basic_stroke(
            pixels, 63, 4, 4, 1, 1, 2, 2, 1, 0xff0000ff, 1), -1)
        self.assertEqual(bytes(pixels), bytes([0x38] * 64))
        self.assertEqual(self.lib.rb_draw_basic_stroke(
            pixels, 64, 4, 4, 1.5, 1.5, 1.5, 1.5, 1, 0xff000000, 1), 0)
        self.assertEqual(bytes(pixels), bytes([0x38] * 64))

    def test_normal_layer_composition_opaque_replaces_base(self):
        background = (U8 * 8)(*bytes.fromhex('203040ff00000000'))
        foreground = (U8 * 8)(*bytes.fromhex('a0b0c0ff33445500'))
        self.assertEqual(self.lib.rb_compose_normal(background, 8, foreground, 8, 2, 1, 1), 0)
        self.assertEqual(bytes(background), bytes.fromhex('a0b0c0ff00000000'))

    def test_normal_layer_composition_half_opacity(self):
        background = (U8 * 4)(0, 0, 255, 255)
        foreground = (U8 * 4)(255, 0, 0, 255)
        self.assertEqual(self.lib.rb_compose_normal(background, 4, foreground, 4, 1, 1, .5), 0)
        self.assertIn(background[0], (127, 128))
        self.assertEqual(background[1], 0)
        self.assertIn(background[2], (127, 128))
        self.assertEqual(background[3], 255)

    def test_normal_layer_composition_transparent_color_and_zero_opacity(self):
        background = (U8 * 8)(*bytes.fromhex('01020380060708ff'))
        untouched = bytes(background)
        invisible = (U8 * 8)(*bytes.fromhex('ffffffffffffffff'))
        self.assertEqual(self.lib.rb_compose_normal(background, 8, invisible, 8, 2, 1, 0), 0)
        self.assertEqual(bytes(background), untouched)
        transparent = (U8 * 8)(*bytes.fromhex('aabbcc00ffffff00'))
        self.assertEqual(self.lib.rb_compose_normal(background, 8, transparent, 8, 2, 1, 1), 0)
        self.assertEqual(bytes(background), untouched)

    def test_normal_layer_composition_invalid_is_atomic(self):
        background = (U8 * 16)(*([0x38] * 16))
        other = (U8 * 16)(*([0x55] * 16))
        for opacity in [-.01, 1.01, math.nan, math.inf, -math.inf]:
            self.assertEqual(self.lib.rb_compose_normal(background, 16, other, 16,
                2, 2, opacity), -1)
            self.assertEqual(bytes(background), bytes([0x38] * 16))
        self.assertEqual(self.lib.rb_compose_normal(background, 15, other, 16, 2, 2, 1), -1)
        self.assertEqual(self.lib.rb_compose_normal(background, 16, other, 15, 2, 2, 1), -1)
        self.assertEqual(self.lib.rb_compose_normal(background, 16, background, 16, 2, 2, 1), -1)
        self.assertEqual(bytes(background), bytes([0x38] * 16))


    def test_eraser_stroke_makes_hole_without_painting(self):
        pixels = (U8 * (7*3*4))()
        self.lib.rb_clear(pixels, len(pixels), 7, 3, 0x112233ff)
        self.assertEqual(self.lib.rb_erase_basic_stroke(pixels, len(pixels),
            7, 3, 1.5, 1.5, 5.5, 1.5, 1.0, 1.0), 0)
        for y in range(3):
            for x in range(7):
                at=(y*7+x)*4
                expected = b'\0\0\0\0' if y == 1 and 1 <= x <= 5 else bytes.fromhex('112233ff')
                self.assertEqual(bytes(pixels[at:at+4]), expected)

    def test_eraser_respects_partial_alpha(self):
        pixels=(U8*8)(*bytes.fromhex('aabbcc807f0000ff'))
        self.assertEqual(self.lib.rb_erase_basic_stroke(pixels,8,
            2,1,.5,.5,.5,.5,1.0,.5),0)
        self.assertEqual(bytes(pixels),bytes.fromhex('aabbcc407f0000ff'))
        self.assertEqual(self.lib.rb_erase_basic_stroke(pixels,8,
            2,1,.5,.5,.5,.5,1.0,0),0)
        self.assertEqual(bytes(pixels),bytes.fromhex('aabbcc407f0000ff'))

    def test_eraser_validates_all_args_before_writing(self):
        original=bytes([0x4e]*32)
        pixels=(U8*32).from_buffer_copy(original)
        for diameter,opacity,x0 in [(0,1,1),(257,1,1),
            (math.nan,1,1),(1,math.nan,1),(1,math.inf,1),
            (1,-.01,1),(1,1.01,1),(1,1,math.nan),
            (1,1,math.inf),(1,1,16385)]:
            self.assertEqual(self.lib.rb_erase_basic_stroke(pixels,32,4,2,
                x0,.5,2.5,.5,diameter,opacity),-1)
            self.assertEqual(bytes(pixels),original)
        self.assertEqual(self.lib.rb_erase_basic_stroke(pixels,31,4,2,
            .5,.5,2.5,.5,1.0,1),-1)
        self.assertEqual(bytes(pixels),original)

    def test_eraser_and_underlying_layer_source_over(self):
        lower=(U8*4)(255,0,0,255)
        upper=(U8*4)(0,0,255,255)
        self.assertEqual(self.lib.rb_erase_basic_stroke(upper,4,
            1,1,.5,.5,.5,.5,1,1),0)
        self.assertEqual(bytes(upper),bytes(4))
        self.assertEqual(self.lib.rb_compose_normal(lower,4,upper,4,1,1,1),0)
        self.assertEqual(bytes(lower),bytes.fromhex('ff0000ff'))


    def test_move_rect_overlapping_and_source_is_cleared(self):
        pixels=(U8*24)()
        original=[0x11,0x22,0x33,0x44]
        for i,n in enumerate(original):
            self.assertEqual(self.lib.rb_set_pixel(pixels,24,6,1,i,0,
                (n<<24)|0x000000ff),0)
        tmp=(U8*12)()
        self.assertEqual(self.lib.rb_move_rect_rgba(pixels,24,6,1,
            0,0,3,1,1,0,tmp,12),0)
        self.assertEqual(bytes(pixels),bytes.fromhex(
            '00000000 110000ff 220000ff 330000ff 00000000 00000000'))
        self.assertEqual(bytes(tmp),bytes.fromhex(
            '110000ff 220000ff 330000ff'))

    def test_move_rect_clips_and_preserves_unselected_pixels(self):
        pixels=(U8*16)(*bytes.fromhex(
            '010203ff 040506ff 070809ff 0a0b0cff'))
        tmp=(U8*8)()
        self.assertEqual(self.lib.rb_move_rect_rgba(pixels,16,4,1,
            0,0,2,1,3,0,tmp,8),0)
        self.assertEqual(bytes(pixels),bytes.fromhex(
            '00000000 00000000 070809ff 010203ff'))

    def test_move_rect_invalid_is_atomic(self):
        pixels=(U8*16)(*bytes.fromhex('112233ff 445566ff 778899ff aabbccff'))
        tmp=(U8*16)(*([0x5a]*16))
        original=bytes(pixels)
        for sx,sy,w,h,tx,ty,cap in [
            (-1,0,1,1,0,0,16),(0,-1,1,1,0,0,16),
            (1,0,4,1,0,0,16),(0,0,0,1,1,0,16),
            (0,0,2,1,1,0,7),(0,0,3,1,1,0,16)]:
            self.assertEqual(self.lib.rb_move_rect_rgba(pixels,16,2,2,
                sx,sy,w,h,tx,ty,tmp,cap),-1)
            self.assertEqual(bytes(pixels),original)
            self.assertEqual(bytes(tmp),bytes([0x5a]*16))
        self.assertEqual(self.lib.rb_move_rect_rgba(pixels,16,2,2,
            0,0,2,2,1,0,pixels,16),-1)
        self.assertEqual(bytes(pixels),original)
        self.assertEqual(self.lib.rb_move_rect_rgba(pixels,16,2,2,
            0,0,1,1,0,0,tmp,16),0)
        self.assertEqual(bytes(pixels),original)

    def test_move_rect_alpha_composes_over_destination(self):
        pixels=(U8*12)(*bytes.fromhex(
            'ff000080 0000ffff 00000000'))
        tmp=(U8*4)()
        self.assertEqual(self.lib.rb_move_rect_rgba(pixels,12,3,1,
            0,0,1,1,1,0,tmp,4),0)
        self.assertEqual(bytes(pixels[0:4]),bytes(4))
        self.assertIn(pixels[4],(127,128))
        self.assertEqual(pixels[5],0)
        self.assertIn(pixels[6],(127,128))
        self.assertEqual(pixels[7],255)


    def test_transform_quarter_clockwise_unequal_dimensions(self):
        plane=(U8*(4*4*4))()
        for x,color in [(0,0xff0000ff),(1,0x00ff00ff),(2,0x0000ffff)]:
            self.assertEqual(self.lib.rb_set_pixel(plane,len(plane),4,4,x,0,color),0)
        temp=(U8*12)()
        self.assertEqual(self.lib.rb_transform_rect_rgba(plane,len(plane),4,4,
            0,0,3,1,0,0,1,3,1,temp,12),0)
        for y,expected in enumerate((0xff0000ff,0x00ff00ff,0x0000ffff)):
            self.assertEqual(bytes(plane[(y*4)*4:(y*4+1)*4]),
                expected.to_bytes(4,'big'))
        self.assertEqual(bytes(plane[4:12]),bytes(8))
        self.assertEqual(bytes(temp),bytes.fromhex('ff0000ff 00ff00ff 0000ffff'))

    def test_transform_counterclockwise_and_halfturn(self):
        for rotation,expected in [(3,[3,2,1]),(2,[3,2,1])]:
            plane=(U8*48)()
            for x,red in enumerate([1,2,3]):
                self.lib.rb_set_pixel(plane,48,3,4,x,0,(red<<24)|0xff)
            temp=(U8*12)()
            if rotation==3:
                args=(0,0,3,1,1,0,1,3,3)
            else:
                args=(0,0,3,1,0,0,3,1,2)
            self.assertEqual(self.lib.rb_transform_rect_rgba(plane,48,3,4,
                *args,temp,12),0)
            for i,red in enumerate(expected):
                at=((i*3+1)*4 if rotation==3 else i*4)
                self.assertEqual(plane[at],red)

    def test_transform_nearest_neighbor_scaling_and_destination_overlap(self):
        plane=(U8*16)(*bytes.fromhex(
            '110000ff 220000ff 990000ff 880000ff'))
        temp=(U8*8)()
        self.assertEqual(self.lib.rb_transform_rect_rgba(plane,16,4,1,
            0,0,2,1,0,0,4,1,0,temp,8),0)
        self.assertEqual(bytes(plane),bytes.fromhex(
            '110000ff 110000ff 220000ff 220000ff'))

    def test_transform_invalid_input_no_buffer_writes(self):
        original=bytes.fromhex('112233ff 445566ff 778899ff aabbccff')
        for dims in [
            (0,0,0,1,0,0,1,1,0),
            (-1,0,1,1,0,0,1,1,0),
            (0,0,1,1,1,0,2,2,0),
            (0,0,1,1,0,0,1,1,4),
            (1,1,2,2,0,0,1,1,1),
            (0,0,1,1,0,0,0,1,0)]:
            plane=(U8*16).from_buffer_copy(original)
            temp=(U8*16)(*([0x5a]*16))
            self.assertEqual(self.lib.rb_transform_rect_rgba(plane,16,2,2,
                *dims,temp,16),-1)
            self.assertEqual(bytes(plane),original)
            self.assertEqual(bytes(temp),bytes([0x5a]*16))
        plane=(U8*16).from_buffer_copy(original)
        temp=(U8*16)(*([0x5a]*16))
        self.assertEqual(self.lib.rb_transform_rect_rgba(plane,16,2,2,
            0,0,2,2,0,0,2,2,1,temp,15),-1)
        self.assertEqual(bytes(plane),original)
        self.assertEqual(bytes(temp),bytes([0x5a]*16))
        self.assertEqual(self.lib.rb_transform_rect_rgba(plane,16,2,2,
            0,0,1,1,0,0,1,1,1,plane,16),-1)
        self.assertEqual(bytes(plane),original)


    def flood(self, rgba, width, height, x, y, color, tolerance=0):
        n=width*height
        queue=(U32*n)()
        visited=(U8*n)()
        changed=U32(999)
        result=self.lib.rb_flood_fill_rgba(rgba,len(rgba),width,height,x,y,
            color,tolerance,queue,n,visited,n,C.byref(changed))
        return result,changed.value

    def test_bucket_fill_contiguous_respects_diagonal_and_boundaries(self):
        # R=10 is the region; R=255 separates it from an isolated region.
        original=bytes.fromhex(
            '0a0000ff 0a0000ff ff0000ff 0a0000ff'
            '0a0000ff ff0000ff 0a0000ff 0a0000ff'
            'ff0000ff 0a0000ff ff0000ff 0a0000ff')
        plane=(U8*len(original)).from_buffer_copy(original)
        result,changed=self.flood(plane,4,3,0,0,0x00ff00ff)
        self.assertEqual((result,changed),(0,3))
        for at in (0,1,4):
            self.assertEqual(bytes(plane[at*4:at*4+4]),bytes.fromhex('00ff00ff'))
        self.assertEqual(bytes(plane[9*4:9*4+4]),bytes.fromhex('0a0000ff'))
        self.assertEqual(bytes(plane[3*4:3*4+4]),bytes.fromhex('0a0000ff'))

    def test_bucket_fill_rgba_alpha_and_tolerance(self):
        plane=(U8*12)(*bytes.fromhex('10101000 15151504 18181800'))
        result,changed=self.flood(plane,3,1,0,0,0xffaa00ff,5)
        self.assertEqual((result,changed),(0,2))
        self.assertEqual(bytes(plane),bytes.fromhex(
            'ffaa00ff ffaa00ff 18181800'))
        result,changed=self.flood(plane,3,1,2,0,0x001122ff,8)
        self.assertEqual((result,changed),(0,1))
        self.assertEqual(bytes(plane[8:12]),bytes.fromhex('001122ff'))

    def test_bucket_fill_noop_same_color_and_noop_count(self):
        plane=(U8*8)(*bytes.fromhex('abcdefee abcdefee'))
        self.assertEqual(self.flood(plane,2,1,0,0,0xabcdefee),(0,0))
        self.assertEqual(bytes(plane),bytes.fromhex('abcdefee abcdefee'))

    def test_bucket_fill_invalid_atomicity_and_disjoint_workspaces(self):
        plane=(U8*16)(*bytes.fromhex(
            '102030ff 304050ff 506070ff 708090ff'))
        backup=bytes(plane)
        queue=(U32*4)(*([777]*4))
        visited=(U8*4)(*([55]*4))
        changed=U32(777)
        for x,y,tol,qcap,vcap in [
            (-1,0,0,4,4),(0,2,0,4,4),(0,0,256,4,4),
            (0,0,0,3,4),(0,0,0,4,3)]:
            self.assertEqual(self.lib.rb_flood_fill_rgba(plane,16,2,2,x,y,
                0xffcc22ff,tol,queue,qcap,visited,vcap,C.byref(changed)),-1)
            self.assertEqual(bytes(plane),backup)
            self.assertEqual(list(queue),[777]*4)
            self.assertEqual(bytes(visited),bytes([55]*4))
            self.assertEqual(changed.value,777)
        self.assertEqual(self.lib.rb_flood_fill_rgba(plane,16,2,2,0,0,
            0x00ff00ff,0,C.cast(plane,C.POINTER(U32)),4,visited,4,
            C.byref(changed)),-1)
        self.assertEqual(bytes(plane),backup)

    def test_bucket_fill_large_checkerboard_is_bounded(self):
        n=64*64
        plane=(U8*(n*4))()
        self.assertEqual(self.flood(plane,64,64,0,0,0xffffffff),(0,n))
        self.assertEqual(bytes(plane),bytes.fromhex('ffffffff')*n)


    def test_shapes_rectangle_outline_and_filled(self):
        pixels=(U8*(5*5*4))()
        shape=self.lib.rb_draw_shape_rgba
        self.assertEqual(shape(pixels,len(pixels),5,5,4,4,0,0,0,0,1,0xff0000ff),0)
        for y in range(5):
            for x in range(5):
                rgba=bytes(pixels[(y*5+x)*4:(y*5+x+1)*4])
                expected=bytes.fromhex('ff0000ff') if (x in (0,4) or y in (0,4)) else bytes(4)
                self.assertEqual(rgba,expected)
        self.assertEqual(shape(pixels,len(pixels),5,5,1,1,3,3,0,1,1,0x00ff00ff),0)
        self.assertEqual(bytes(pixels[(2*5+2)*4:(2*5+3)*4]),bytes.fromhex('00ff00ff'))
        self.assertEqual(bytes(pixels[0:4]),bytes.fromhex('ff0000ff'))

    def test_shapes_ellipse_coverage_and_outline(self):
        size=9*9*4
        filled=(U8*size)()
        outline=(U8*size)()
        draw=self.lib.rb_draw_shape_rgba
        self.assertEqual(draw(filled,size,9,9,2,2,6,6,1,1,1,0x112233ff),0)
        self.assertEqual(draw(outline,size,9,9,2,2,6,6,1,0,1,0x112233ff),0)
        at=lambda x,y:(y*9+x)*4
        self.assertEqual(bytes(filled[at(4,4):at(4,4)+4]),bytes.fromhex('112233ff'))
        self.assertEqual(bytes(outline[at(4,4):at(4,4)+4]),bytes(4))
        self.assertEqual(bytes(outline[at(4,2):at(4,2)+4]),bytes.fromhex('112233ff'))
        self.assertEqual(bytes(filled[at(2,2):at(2,2)+4]),bytes(4))
        self.assertEqual(bytes(outline[at(2,2):at(2,2)+4]),bytes(4))

    def test_shapes_clipping_and_single_pixel(self):
        rgba=(U8*16)()
        draw=self.lib.rb_draw_shape_rgba
        self.assertEqual(draw(rgba,16,2,2,-3,-3,0,0,0,1,1,0x334455ff),0)
        self.assertEqual(bytes(rgba[0:4]),bytes.fromhex('334455ff'))
        self.assertEqual(bytes(rgba[4:]),bytes(12))
        self.assertEqual(draw(rgba,16,2,2,1,1,1,1,1,1,3,0xaabbccff),0)
        self.assertEqual(bytes(rgba[12:16]),bytes.fromhex('aabbccff'))

    def test_shapes_alpha_blending_and_invalid_atomicity(self):
        draw=self.lib.rb_draw_shape_rgba
        rgba=(U8*4)(0,0,255,255)
        self.assertEqual(draw(rgba,4,1,1,0,0,0,0,0,1,1,0xff000080),0)
        self.assertIn(rgba[0],(127,128))
        self.assertEqual(rgba[1],0)
        self.assertIn(rgba[2],(127,128))
        self.assertEqual(rgba[3],255)
        original=bytes(rgba)
        for shape,filled,thickness,x in [
            (2,0,1,0),(0,2,1,0),(0,0,0,0),(0,0,129,0),(0,0,1,16385)]:
            self.assertEqual(draw(rgba,4,1,1,x,0,0,0,shape,filled,thickness,0xffffffff),-1)
            self.assertEqual(bytes(rgba),original)
        self.assertEqual(draw(rgba,3,1,1,0,0,0,0,0,1,1,0xffffffff),-1)
        self.assertEqual(bytes(rgba),original)
        self.assertEqual(draw(rgba,4,1,1,0,0,0,0,0,1,1,0x11223300),0)
        self.assertEqual(bytes(rgba),original)


    def test_feather_brush_soft_core_and_translucent_fringe(self):
        size=17*17*4
        image=(U8*size)()
        draw=self.lib.rb_draw_feather_stroke
        self.assertEqual(draw(image,size,17,17,8.5,8.5,8.5,8.5,
            8.0,0xff0000ff,1.0,0.25),0)
        at=lambda x,y:(y*17+x)*4
        center=image[at(8,8)+3]
        fringe=image[at(11,8)+3]
        outside=image[at(12,8)+3]
        self.assertEqual(center,255)
        self.assertGreater(fringe,0)
        self.assertLess(fringe,center)
        self.assertEqual(outside,0)
        self.assertEqual(bytes(image[at(11,8):at(11,8)+3]),bytes.fromhex('ff0000'))
        self.assertEqual(bytes(image[at(8,8):at(8,8)+4]),bytes.fromhex('ff0000ff'))

    def test_feather_hardness_one_equals_existing_brush(self):
        pixels=20*20*4
        rigid=(U8*pixels)()
        feather=(U8*pixels)()
        hard=self.lib.rb_draw_basic_stroke
        soft=self.lib.rb_draw_feather_stroke
        self.assertEqual(hard(rigid,pixels,20,20,2.2,1.8,15.7,17.1,
            7.0,0x8020c0bb,0.65),0)
        self.assertEqual(soft(feather,pixels,20,20,2.2,1.8,15.7,17.1,
            7.0,0x8020c0bb,0.65,1.0),0)
        self.assertEqual(bytes(rigid),bytes(feather))

    def test_feather_opacity_and_noop(self):
        plane=(U8*(13*13*4))()
        size=len(plane)
        soft=self.lib.rb_draw_feather_stroke
        self.assertEqual(soft(plane,size,13,13,6.5,6.5,6.5,6.5,
            6.0,0x224466ff,0.5,0.25),0)
        at=(6*13+6)*4
        self.assertEqual(bytes(plane[at:at+3]),bytes.fromhex('224466'))
        self.assertIn(plane[at+3],(127,128))
        snapshot=bytes(plane)
        self.assertEqual(soft(plane,size,13,13,6.5,6.5,6.5,6.5,
            6.0,0xff00ffff,0.0,0.25),0)
        self.assertEqual(bytes(plane),snapshot)
        self.assertEqual(soft(plane,size,13,13,6.5,6.5,6.5,6.5,
            6.0,0xff00ff00,1.0,0.25),0)
        self.assertEqual(bytes(plane),snapshot)

    def test_feather_brush_invalid_is_atomic(self):
        plane=(U8*16)(*bytes.fromhex('11223344 55667788 99aabbcc ddeeff00'))
        snapshot=bytes(plane)
        soft=self.lib.rb_draw_feather_stroke
        for args in [
            (0.,0.,0.,0.,0.,0xffffffff,1.,0.25),
            (0.,0.,0.,0.,257.,0xffffffff,1.,0.25),
            (0.,0.,0.,0.,4.,0xffffffff,-0.1,0.25),
            (0.,0.,0.,0.,4.,0xffffffff,1.,-0.01),
            (0.,0.,0.,0.,4.,0xffffffff,1.,1.01),
            (math.nan,0.,0.,0.,4.,0xffffffff,1.,0.25),
            (0.,0.,math.inf,0.,4.,0xffffffff,1.,0.25),
        ]:
            self.assertEqual(soft(plane,16,2,2,*args),-1)
            self.assertEqual(bytes(plane),snapshot)
        self.assertEqual(soft(plane,15,2,2,0.,0.,0.,0.,
            4.,0xffffffff,1.,0.25),-1)
        self.assertEqual(bytes(plane),snapshot)


    def test_windows_ink_abi_and_pressure(self):
        self.assertEqual(C.sizeof(InkEvent),44)
        pressure=self.lib.rb_ink_pressure
        self.assertEqual(pressure(0,0),1.0)  # no PEN_MASK_PRESSURE
        self.assertEqual(pressure(0,1),0.0)
        self.assertEqual(pressure(512,1),0.5)
        self.assertEqual(pressure(1024,1),1.0)
        self.assertEqual(pressure(4096,1),1.0)
        self.assertEqual(pressure(512,4),1.0)
        self.assertEqual(self.lib.rb_ink_poll(None,1),-1)
        self.assertEqual(self.lib.rb_ink_poll(None,513),-1)
        self.assertEqual(self.lib.rb_ink_poll(None,0),0)
        self.assertEqual(self.lib.rb_ink_poll((InkEvent*1)(),1),0)

    def test_windows_ink_safe_attach_detach_without_pen_hardware(self):
        # Only the calling thread's own active Win32 window may be subclassed.
        self.assertIn(self.lib.rb_ink_attach(),(-1,1))
        attached=self.lib.rb_ink_is_attached()
        self.assertIn(attached,(0,1))
        self.assertEqual(self.lib.rb_ink_mouse_guard(),0)
        self.assertEqual(self.lib.rb_ink_dropped(),0)
        self.assertEqual(self.lib.rb_ink_detach(),0)
        self.assertEqual(self.lib.rb_ink_is_attached(),0)
        self.assertEqual(self.lib.rb_ink_detach(),0)


    def test_tilt_ellipse_orientation_and_swept_segment(self):
        draw=self.lib.rb_draw_tilt_stroke
        size=25*25*4
        horizontal=(U8*size)()
        vertical=(U8*size)()
        self.assertEqual(draw(horizontal,size,25,25,12.5,12.5,12.5,12.5,
            8.0,0xe53b44ff,1.0,1.0,90.0,0.0),0)
        self.assertEqual(draw(vertical,size,25,25,12.5,12.5,12.5,12.5,
            8.0,0xe53b44ff,1.0,1.0,0.0,90.0),0)
        at=lambda x,y:(y*25+x)*4
        self.assertEqual(bytes(horizontal[at(18,12):at(18,12)+4]),
            bytes.fromhex('e53b44ff'))
        self.assertEqual(bytes(horizontal[at(12,18):at(12,18)+4]),bytes(4))
        self.assertEqual(bytes(vertical[at(12,18):at(12,18)+4]),
            bytes.fromhex('e53b44ff'))
        self.assertEqual(bytes(vertical[at(18,12):at(18,12)+4]),bytes(4))
        line=(U8*size)()
        self.assertEqual(draw(line,size,25,25,3.5,8.5,21.5,8.5,
            4.0,0x3366aaff,.7,1.0,90.0,0.0),0)
        self.assertGreater(line[at(12,8)+3],0)
        self.assertGreater(line[at(21,8)+3],0)
        self.assertEqual(line[at(12,14)+3],0)

    def test_variable_pressure_single_pass_gradient_and_compatibility(self):
        draw=self.lib.rb_draw_pressure_stroke
        width,height=82,31
        size=width*height*4
        color=0x6ca5e3ff
        def pixel(plane,x,y):
            return bytes(plane[(y*width+x)*4:(y*width+x+1)*4])
        for style in range(4):
            canvas=(U8*size)()
            if style==2:
                self.assertEqual(self.lib.rb_clear(canvas,size,width,height,
                    0x54aaccff),0)
            self.assertEqual(draw(canvas,size,width,height,8.5,15.5,
                72.5,15.5,3.0,15.0,color,.2,.9,.25,45.,20.,style),0)
            # Thin/transparent beginning transitions continuously toward
            # the thick/high-opacity endpoint: no independent subsegments.
            left=pixel(canvas,10,15)[3]
            middle=pixel(canvas,41,15)[3]
            right=pixel(canvas,70,15)[3]
            if style!=2:
                self.assertTrue(0<left<middle<right<=255,
                    (style,left,middle,right))
                self.assertEqual(pixel(canvas,10,19)[3],0,
                    'Thin start must not use the endpoint diameter')
            else:
                self.assertTrue(0<=right<middle<left<255,
                    (style,left,middle,right))
            legacy=(U8*size)()
            same=(U8*size)()
            if style==2:
                self.lib.rb_clear(legacy,size,width,height,0x54aaccff)
                self.lib.rb_clear(same,size,width,height,0x54aaccff)
            old={
                0:lambda p:self.lib.rb_draw_basic_stroke(p,size,width,height,
                    5.5,13.5,65.5,13.5,9.,color,.45),
                1:lambda p:self.lib.rb_draw_feather_stroke(p,size,width,height,
                    5.5,13.5,65.5,13.5,9.,color,.45,.25),
                2:lambda p:self.lib.rb_erase_basic_stroke(p,size,width,height,
                    5.5,13.5,65.5,13.5,9.,.45),
                3:lambda p:self.lib.rb_draw_tilt_stroke(p,size,width,height,
                    5.5,13.5,65.5,13.5,9.,color,.45,.25,45.,20.)
            }
            self.assertEqual(old[style](legacy),0)
            self.assertEqual(draw(same,size,width,height,5.5,13.5,65.5,13.5,
                9.,9.,color,.45,.45,.25,45.,20.,style),0)
            self.assertEqual(bytes(legacy),bytes(same),
                'Constant pressure must match older C++ raster byte-for-byte')
        # Reject bad inputs atomically without touching RGBA bytes.
        invalid=(U8*size)(*([0x37]*size))
        original=bytes(invalid)
        for d0,d1,o0,o1,x1,tilt,style in (
            (0.,5.,.5,.5,10.,0.,0),
            (4.,257.,.5,.5,10.,0.,0),
            (4.,5.,-1.,.5,10.,0.,0),
            (4.,5.,.5,2.,10.,0.,0),
            (4.,5.,.5,.5,math.nan,0.,0),
            (4.,5.,.5,.5,10.,91.,3),
            (4.,5.,.5,.5,10.,0.,4)):
            self.assertEqual(draw(invalid,size,width,height,
                5.5,15.5,x1,15.5,d0,d1,color,o0,o1,.25,tilt,0.,style),-1)
            self.assertEqual(bytes(invalid),original)



    def test_whole_stroke_alpha_union_and_baseline(self):
        width = height = 36
        pixels = width * height
        size = pixels * 4
        color = 0x3b8fdbff
        source = (U8 * size)()
        result = (U8 * size)()
        mask = (U8 * pixels)()
        draw = self.lib.rb_draw_accumulated_stroke
        def paint(a, b, opacity, style=0):
            return draw(result, size, source, size, mask, pixels,
                        width, height, *a, *b, 9., 9., color,
                        opacity, opacity, .25, 0., 0., style)
        center = (15 * width + 15) * 4
        self.assertEqual(paint((15.5, 15.5), (15.5, 15.5), .4), 0)
        first = bytes(result)
        self.assertIn(result[center+3], (102, 103))
        self.assertEqual(mask[15*width+15], result[center+3])
        self.assertEqual(paint((14.5, 15.5), (18.5, 15.5), .4), 0)
        self.assertEqual(bytes(result), first,
            'Repeated overlapping coverage must not darken the initial dot')
        self.assertEqual(paint((15.5, 12.5), (15.5, 17.5), .4), 0)
        self.assertEqual(bytes(result), first,
            'Intersecting segments must preserve maximum local coverage')
        self.assertEqual(paint((15.5, 15.5), (15.5, 15.5), .8), 0)
        self.assertEqual(result[center+3], 204)
        self.assertEqual(paint((15.5, 15.5), (15.5, 15.5), .2), 0)
        self.assertEqual(result[center+3], 204)
        self.assertEqual(result[center:center+3], bytes.fromhex('3b8fdb'))

        baseline = (U8 * size)()
        target = (U8 * size)()
        erasure = (U8 * pixels)()
        initial = bytes.fromhex('1656a0c8')
        for pos in range(0, size, 4):
            baseline[pos:pos+4] = initial
            target[pos:pos+4] = initial
        args = (target, size, baseline, size, erasure, pixels,
                width, height, 10.5, 10.5, 25.5, 25.5,
                9., 9., color, .55, .55, 1., 0., 0., 2)
        self.assertEqual(draw(*args), 0)
        affected = (18*width+18)*4
        a = target[affected+3]
        self.assertLess(a, 200)
        self.assertGreater(a, 0)
        self.assertEqual(bytes(target[affected:affected+3]), initial[:3])
        self.assertEqual(draw(*args), 0)
        self.assertEqual(target[affected+3], a,
            'Repeated eraser segment must not erase the pixel twice')
        self.assertEqual(draw(target, size, baseline, size, erasure, pixels,
            width, height, 10.5,10.5,25.5,25.5,
            9.,9.,color,.95,.95,1.,0.,0.,2),0)
        self.assertLess(target[affected+3],a)
        self.assertEqual(bytes(baseline[:4]), initial)

        before, previous_mask = bytes(target), bytes(erasure)
        bad = list(args)
        bad[1] = size - 1
        self.assertEqual(draw(*bad), -1)
        self.assertEqual(bytes(target), before)
        self.assertEqual(bytes(erasure), previous_mask)
        bad = list(args)
        bad[4] = target
        self.assertEqual(draw(*bad), -1)
        bad = list(args)
        bad[8] = float('nan')
        self.assertEqual(draw(*bad), -1)
        self.assertEqual(bytes(target), before)
        self.assertEqual(bytes(erasure), previous_mask)

    def test_whole_stroke_soft_and_pressure_gradient(self):
        w,h = 80,40
        size=w*h*4
        for style in (0,1,2,3):
            base=(U8*size)()
            if style==2:
                self.lib.rb_clear(base,size,w,h,0x778899ff)
            canvas=(U8*size)(*base)
            coverage=(U8*(w*h))()
            draw=self.lib.rb_draw_accumulated_stroke
            args=(canvas,size,base,size,coverage,w*h,w,h,
                5.5,19.5,65.5,19.5,2.,18.,0x8b3a66ff,
                .2,.7,.25,55.,15.,style)
            self.assertEqual(draw(*args),0)
            at=lambda x,y:(y*w+x)*4+3
            low=canvas[at(8,19)]
            high=canvas[at(60,19)]
            if style!=2:
                self.assertGreater(high,low)
            else:
                self.assertLess(high,low)
            previous=bytes(canvas)
            self.assertEqual(draw(*args),0)
            self.assertEqual(bytes(canvas),previous,
                'Repeated pressure-gradient stroke re-composited a pixel')
    def test_tilt_zero_matches_old_hard_and_soft_brush(self):
        tilt=self.lib.rb_draw_tilt_stroke
        hard=self.lib.rb_draw_basic_stroke
        feather=self.lib.rb_draw_feather_stroke
        length=19*19*4
        for hardness in (1.0,0.25,0.0):
            before=(U8*length)()
            after=(U8*length)()
            args=(2.2,4.5,13.8,17.1,6.5,0x887766cc,.72)
            if hardness==1.0:
                self.assertEqual(hard(before,length,19,19,*args),0)
            else:
                self.assertEqual(feather(before,length,19,19,*args,hardness),0)
            self.assertEqual(tilt(after,length,19,19,*args,hardness,0.,0.),0)
            self.assertEqual(bytes(after),bytes(before))
        a=(U8*length)()
        self.assertEqual(tilt(a,length,19,19,9.5,9.5,9.5,9.5,7.,
            0xff0000ff,.6,.25,60.,0.),0)
        center=(9*19+9)*4
        self.assertGreater(a[center+3],0)
        self.assertLess(a[center+3],255)

    def test_tilt_rejects_invalid_without_mutating_pixels(self):
        draw=self.lib.rb_draw_tilt_stroke
        pixels=(U8*16)(*bytes.fromhex('01020304 10111213 20212223 30313233'))
        before=bytes(pixels)
        for x,y,diam,alpha,hardness,tx,ty in [
            (0,0,0,1.,1.,0.,0.),
            (0,0,257,1.,1.,0.,0.),
            (0,0,4,-.1,1.,0.,0.),
            (0,0,4,1.,-.1,0.,0.),
            (0,0,4,1.,1.,91.,0.),
            (0,0,4,1.,1.,0.,-91.),
            (math.nan,0,4,1.,1.,0.,0.),
            (0,0,4,1.,1.,math.inf,0.),
        ]:
            self.assertEqual(draw(pixels,16,2,2,x,y,x,y,
                diam,0xffffffff,alpha,hardness,tx,ty),-1)
            self.assertEqual(bytes(pixels),before)
        self.assertEqual(draw(pixels,15,2,2,0.,0.,0.,0.,
            4.,0xffffffff,1.,1.,20.,0.),-1)
        self.assertEqual(bytes(pixels),before)


if __name__ == '__main__':
    unittest.main(verbosity=2)
