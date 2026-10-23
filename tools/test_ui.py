"""Interface integration only through the official LÖVE process lifecycle."""
import argparse
import json
import pathlib
import sys
import time
from build import ROOT, BUILD, runtime
from process_runner import run_process
from windows_preflight import check as inspect_windows_paths

def run_ui(output, runtime_path=None, lua_only=False, timeout=30, route='both'):
    output = pathlib.Path(output)
    output.mkdir(parents=True, exist_ok=True)
    rt = runtime(runtime_path)
    executable = ROOT / 'dist/Android1412Rebuild.exe'
    commands = []
    if route in ('both', 'packaged'):
        commands.append(('packaged', [executable]))
    if route in ('both', 'official'):
        runner = rt / 'lovec.exe'
        if not runner.exists():
            runner = rt / 'love.exe'
        commands.append(('official', [runner, ROOT / 'app']))
    results = []
    for name, command in commands:
        folder = output / name
        folder.mkdir(exist_ok=True)
        app_report, capture = folder / 'app-report.json', folder / 'ui.png'
        args = command + ['--lua-test' if lua_only else '--self-test', '--data-dir', folder / 'data',
                          '--report', app_report, '--capture', capture]
        process = run_process(args, folder, timeout, cwd=ROOT)
        try:
            application = json.loads(app_report.read_text(encoding='utf-8')) if app_report.exists() else None
        except (OSError, ValueError) as error:
            application = {'ok': False, 'error': str(error)}
        stdout = (folder / 'stdout.log').read_text(encoding='utf-8', errors='replace')[-3000:]
        stderr = (folder / 'stderr.log').read_text(encoding='utf-8', errors='replace')[-3000:]
        startup_failure = None
        if not application:
            if 'Failed to initialize filesystem' in (stderr + stdout):
                startup_failure = 'love-boot-filesystem-before-main-lua'
            elif not process['ok']:
                startup_failure = 'process-terminated-before-application-report'
        results.append({'route': name, 'process': process, 'application': application,
                        'startup_failure': startup_failure,
                        'stdout_tail': stdout, 'stderr_tail': stderr,
                        'screenshot_bytes': capture.stat().st_size if capture.exists() else 0,
                        'ok': bool(process['ok'] and application and application.get('ok')
                                   and capture.exists() and (lua_only or application.get('native_loaded')))})
    report = {'ok': bool(results) and all(r['ok'] for r in results),
              'host_path_preflight': inspect_windows_paths(ROOT, rt),
              'suite': 'official-runtime-ui', 'python_graphics_embedding': False,
              'native_required': not lua_only, 'android_runtime_compared': False,
              'routes': results,
              'feature_status': {
                  'initialization': 'passed' if results and all(r['ok'] for r in results) else 'failed_or_blocked',
                  'canvas_creation': ('native self-test created/loaded a RGBA document'
                      if results and all(r['ok'] and (r['application'] or {}).get('native', {}).get('buffer_roundtrip')
                          for r in results) else 'not_verified'),
                  'painting': ('basic independent C++ stroke tested; Android equivalence unverified'
                      if results and all(r['ok'] and (r['application'] or {}).get('native', {}).get('basic_desktop_stroke')
                          for r in results) else 'not_verified'),
                  'layers': ('RBD2 multiple editable raster layers roundtrip verified; normal blend only'
                      if results and all(r['ok'] and (r['application'] or {}).get('native', {}).get('layered_roundtrip')
                          for r in results) else 'not_verified'),
                  'save_reopen': ('native integration saved/reopened editable RBD2 and checked PNG pixels'
                      if results and all(r['ok'] and (r['application'] or {}).get('native', {}).get('png_pixels')
                          for r in results) else 'not_verified')}}
    (output / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report

def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime')
    parser.add_argument('--output')
    parser.add_argument('--lua-only', action='store_true')
    parser.add_argument('--native', action='store_true', help='Compatibility flag; native is required by default')
    parser.add_argument('--route', choices=['both', 'packaged', 'official'], default='both')
    parser.add_argument('--timeout', type=int, default=30)
    args = parser.parse_args(argv)
    if args.timeout < 1 or args.timeout > 120:
        parser.error('--timeout must be between 1 and 120 seconds')
    output = pathlib.Path(args.output) if args.output else BUILD / ('ui-' + str(time.time_ns()))
    try:
        report = run_ui(output, args.runtime, args.lua_only, args.timeout, args.route)
    except Exception as error:
        output.mkdir(parents=True, exist_ok=True)
        report = {'ok': False, 'suite': 'official-runtime-ui', 'error': str(error)}
        (output / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'output': str(output), **report}, indent=2))
    return 0 if report['ok'] else 1

if __name__ == '__main__':
    sys.exit(main())
