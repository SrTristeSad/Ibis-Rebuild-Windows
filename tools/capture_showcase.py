"""Record real LÖVE screenshots using the verified Windows native renderer.

Runs in the official LÖVE Windows executable, not a mock, design render,
browser screenshot, or image-generation model.
"""
import argparse
import json
import pathlib
import struct
import sys
import time
from build import ROOT, BUILD, runtime
from process_runner import run_process

NAMES = (
    '01-galeria.png',
    '02-editor-compacto.png',
    '03-biblioteca-pinceis.png',
    '04-seletor-cores.png',
    '05-camadas.png',
    '06-editor-desktop.png',
    '07-editor-960x640.png',
)
PNG_MAGIC = b'\x89PNG\r\n\x1a\n'


def capture(output, runtime_path=None):
    output = pathlib.Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    rt = runtime(runtime_path)
    executable = rt / 'lovec.exe'
    if not executable.is_file():
        executable = rt / 'love.exe'
    workspace = output / 'isolated-project'
    workspace.mkdir(exist_ok=True)
    # These arguments are intentionally unavailable during a normal app launch.
    command = [executable, ROOT / 'app', '--data-dir', workspace,
               '--showcase-dir', output]
    process = run_process(command, output / 'command', 70, cwd=ROOT)
    report_file = output / 'showcase-report.json'
    app = json.loads(report_file.read_text(encoding='utf-8')) \
        if report_file.is_file() else {'ok': False, 'error': 'Showcase report missing'}
    items = []
    for name in NAMES:
        path = output / name
        if not path.is_file():
            items.append({'name': name, 'ok': False, 'reason': 'Screenshot missing'})
            continue
        data = path.read_bytes()
        ok = len(data) > 1500 and data.startswith(PNG_MAGIC) and \
            data[12:16] == b'IHDR'
        dimensions = struct.unpack('>II', data[16:24]) if ok else (0, 0)
        expected_dimensions = (960, 640) if name == '07-editor-960x640.png' else (1220, 800)
        ok = ok and dimensions == expected_dimensions
        items.append({'name': name, 'ok': bool(ok),
                      'bytes': len(data), 'dimensions': dimensions})
    verified = bool(process['ok'] and app.get('ok') and
                    app.get('real_love_render') and app.get('native_cpp') and
                    all(x['ok'] for x in items))
    stdout_file = output / 'command' / 'stdout.log'
    stderr_file = output / 'command' / 'stderr.log'
    result = {'ok': verified, 'capture_type': 'real_love_window',
              'native_cpp': bool(app.get('native_cpp')),
              'android_1412_pixel_parity': False, 'process': process,
              'screenshots': items, 'app': app,
              'stdout_tail': stdout_file.read_text(encoding='utf-8', errors='replace')[-1400:]
                  if stdout_file.exists() else '',
              'stderr_tail': stderr_file.read_text(encoding='utf-8', errors='replace')[-1400:]
                  if stderr_file.exists() else ''}
    (output / 'verification.json').write_text(
        json.dumps(result, indent=2), encoding='utf-8')
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime')
    parser.add_argument('--output')
    args = parser.parse_args()
    destination = pathlib.Path(args.output) if args.output else \
        BUILD / ('showcase-' + str(time.time_ns()))
    try:
        report = capture(destination, args.runtime)
    except Exception as exc:
        destination.mkdir(parents=True, exist_ok=True)
        report = {'ok': False, 'error': str(exc)}
        (destination / 'verification.json').write_text(
            json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
