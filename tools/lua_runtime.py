"""Owned headless LuaJIT state. Never load LÖVE/SDL/graphics into Python."""
import ctypes as C
import pathlib
import struct

LUA_STATE = C.c_void_p
# lua_CFunction entrypoints are int(lua_State*). Documented for audit only:
# luaopen_love and luaopen_love_graphics must NOT be called by this host.
FORBIDDEN_GRAPHICS_ENTRYPOINTS = {
    'luaopen_love': {'argtypes': ['lua_State*'], 'restype': 'int'},
    'luaopen_love_graphics': {'argtypes': ['lua_State*'], 'restype': 'int'},
}
API = {
    'luaL_newstate': (LUA_STATE, []),
    'luaL_openlibs': (None, [LUA_STATE]),
    'lua_close': (None, [LUA_STATE]),
    'lua_gettop': (C.c_int, [LUA_STATE]),
    'lua_settop': (None, [LUA_STATE, C.c_int]),
    'luaL_loadfile': (C.c_int, [LUA_STATE, C.c_char_p]),
    'luaL_loadstring': (C.c_int, [LUA_STATE, C.c_char_p]),
    'lua_pcall': (C.c_int, [LUA_STATE, C.c_int, C.c_int, C.c_int]),
    'lua_tolstring': (C.c_void_p, [LUA_STATE, C.c_int, C.POINTER(C.c_size_t)]),
}

def pe_machine(path):
    with pathlib.Path(path).open('rb') as f:
        if f.read(2) != b'MZ':
            raise ValueError('Expected Windows PE DLL')
        f.seek(0x3c); offset = struct.unpack('<I', f.read(4))[0]
        f.seek(offset)
        if f.read(4) != b'PE\0\0':
            raise ValueError('Invalid PE signature')
        return struct.unpack('<H', f.read(2))[0]

class LuaState:
    def __init__(self, runtime):
        path = pathlib.Path(runtime) / 'lua51.dll'
        if C.sizeof(C.c_void_p) != 8 or pe_machine(path) != 0x8664:
            raise RuntimeError('Python and LuaJIT must both be Windows x64')
        self.library = C.CDLL(str(path.resolve()))  # Lua 5.1 C ABI, cdecl.
        for name, (result, arguments) in API.items():
            function = getattr(self.library, name)
            function.argtypes = arguments
            function.restype = result
        pointer = self.library.luaL_newstate()
        if not pointer:
            raise MemoryError('luaL_newstate returned NULL')
        self._pointer = LUA_STATE(pointer)
        self.closed = False
        self.close_succeeded = False
        self.library.luaL_openlibs(self._pointer)
        if self.library.lua_gettop(self._pointer) != 0:
            self.close()
            raise RuntimeError('Fresh Lua stack was not empty')

    @property
    def pointer(self):
        if self.closed:
            raise RuntimeError('Lua state is closed; pointer must not be reused')
        return self._pointer

    def text(self):
        size = C.c_size_t()
        address = self.library.lua_tolstring(self.pointer, -1, C.byref(size))
        if not address:
            raise RuntimeError('Expected a string on the Lua stack')
        return C.string_at(address, size.value).decode('utf-8')

    def execute(self, code):
        lib, state = self.library, self.pointer
        lib.lua_settop(state, 0)
        status = lib.luaL_loadstring(state, code.encode('utf-8'))
        if not status:
            status = lib.lua_pcall(state, 0, 1, 0)
        if status:
            message = self.text()
            lib.lua_settop(state, 0)
            raise RuntimeError(message)
        return self.text()

    def check_syntax(self, path):
        state = self.pointer
        status = self.library.luaL_loadfile(state, str(path).encode('utf-8'))
        message = self.text() if status else None
        self.library.lua_settop(state, 0)
        if status:
            raise RuntimeError(message)

    def close(self):
        if self.closed:
            raise RuntimeError('Refusing to call lua_close twice')
        state = self._pointer
        self.closed = True
        # A failed close poisons the state: never retry a possible double free.
        # The exception propagates; callers must not record test success.
        self.library.lua_close(state)
        self._pointer = None
        self.close_succeeded = True

    def __enter__(self):
        return self

    def __exit__(self, kind, error, trace):
        self.close()
        return False
