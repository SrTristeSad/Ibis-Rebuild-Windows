"""Read-only Windows path diagnostics for the original LÖVE bootstrap / LLVM failure.

Never changes ACLs, copies a proprietary artifact, launches a compiler, or
converts an inaccessible path into a false build success.
"""
import argparse
import ctypes
import json
import os
import pathlib
import sys


def get_long_path(path):
    """Check the same Win32 canonicalization used during LLVM startup.

    Returning 0 with GetLastError=5 strongly suggests inaccessible parent
    directory metadata. It does *not* prove an executable cannot run.
    """
    if os.name != 'nt':
        return {'available': False, 'reason': 'Windows-only API'}
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    function = kernel.GetLongPathNameW
    function.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint32]
    function.restype = ctypes.c_uint32
    buffer = ctypes.create_unicode_buffer(32768)
    ctypes.set_last_error(0)
    count = function(str(path), buffer, len(buffer))
    error = ctypes.get_last_error()
    if count == 0:
        return {'available': True, 'ok': False, 'winerror': error}
    if count >= len(buffer):
        return {'available': True, 'ok': False, 'error': 'path-exceeds-buffer'}
    return {'available': True, 'ok': True, 'resolved': buffer.value}


def inspect(path):
    if not path:
        return {'supplied': False}
    target = pathlib.Path(path).absolute()
    result = {'supplied': True, 'path': str(target),
              'exists': target.exists(), 'is_file': target.is_file()}
    if not result['exists']:
        result['diagnosis'] = 'missing'
    else:
        result['long_path'] = get_long_path(target)
        if result['long_path'].get('winerror') == 5:
            result['diagnosis'] = 'GetLongPathNameW ACCESS_DENIED; check ancestor traversal permissions'
        elif result['long_path'].get('ok'):
            result['diagnosis'] = 'canonicalization-accepted'
        else:
            result['diagnosis'] = 'canonicalization-not-established'
    return result


def check(root, runtime=None, compiler=None):
    root = pathlib.Path(root).absolute()
    rt = pathlib.Path(runtime).absolute() if runtime else None
    report = {'kind': 'read-only-windows-startup-preflight', 'platform': sys.platform,
              'mutated_permissions': False, 'downloaded': False,
              'android_runtime_compared': False,
              'paths': {
                  'project_main': inspect(root / 'app/main.lua'),
                  'project_directory': inspect(root),
                  'love_executable': inspect(rt / 'love.exe' if rt else None),
                  'love_console': inspect(rt / 'lovec.exe' if rt else None),
                  'luajit_runtime': inspect(rt / 'lua51.dll' if rt else None),
                  'native_dll': inspect(root / 'build/rebuild_core.dll'),
                  'compiler': inspect(compiler),
              }}
    report['file_system_bootstrap_risk'] = [
        name for name, detail in report['paths'].items()
        if detail.get('long_path', {}).get('winerror') == 5
    ]
    report['compiler_launch_verified'] = False
    report['love_startup_verified'] = False
    report['note'] = ('This only identifies possible path restrictions. A process '
        'exit code, native ABI test and official LÖVE startup test are still required.')
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime')
    parser.add_argument('--compiler')
    parser.add_argument('--output')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    report = check(root, args.runtime or os.environ.get('LOVE_RUNTIME'), args.compiler)
    output = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        path = pathlib.Path(args.output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(output + '\n', encoding='utf-8')
    print(output)
    return 0  # A probe is not a build or UI acceptance test.


if __name__ == '__main__':
    sys.exit(main())
