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
            'rb_compose_normal': (I32, [C.POINTER(U8), U64, C.POINTER(U8), U64,
                U32, U32, F32]),
            'rb_move_rect_rgba': (I32, [C.POINTER(U8), U64, U32, U32,
                I32, I32, U32, U32, I32, I32, C.POINTER(U8), U64]),
            'rb_transform_rect_rgba': (I32, [C.POINTER(U8), U64, U32, U32,
                I32, I32, U32, U32, I32, I32, U32, U32, U32, C.POINTER(U8), U64]),
            'rb_erase_basic_stroke': (I32, [C.POINTER(U8), U64, U32, U32,
                F32, F32, F32, F32, F32, F32]),
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


if __name__ == '__main__':
    unittest.main(verbosity=2)
