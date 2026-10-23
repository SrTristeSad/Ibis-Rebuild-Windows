"""Separate, time-bounded headless Lua, C++ and official-runtime GUI suites."""
import argparse
import json
import os
import pathlib
import sys
import time
from build import ROOT, BUILD
from process_runner import run_process

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--suite', choices=['all', 'lua', 'native', 'ui'], default='all')
    parser.add_argument('--runtime')
    parser.add_argument('--lua-only', action='store_true', help='Explicitly limits scope; never counts native as passed')
    parser.add_argument('--no-gui', action='store_true')
    args = parser.parse_args()
    output = BUILD / ('validation-' + str(time.time_ns()))
    output.mkdir(parents=True)
    result = {'ok': False, 'output': str(output), 'suites': {},
              'android_runtime_compared': False, 'native_required': not args.lua_only}
    selected = ['lua', 'native', 'ui'] if args.suite == 'all' else [args.suite]
    if args.lua_only:
        selected = [s for s in selected if s != 'native']
    if args.no_gui:
        selected = [s for s in selected if s != 'ui']
    for suite in selected:
        folder = output / suite
        if suite == 'lua':
            command = [sys.executable, ROOT / 'tools/test_lua.py', '--output', folder]
            if args.runtime:
                command += ['--runtime', args.runtime]
            process = run_process(command, folder, 35, cwd=ROOT)
        elif suite == 'native':
            env = dict(os.environ, RB_CORE_DLL=str(BUILD / 'rebuild_core.dll'))
            process = run_process([sys.executable, ROOT / 'tests/test_core.py'], folder, 35, cwd=ROOT, env=env)
        else:
            command = [sys.executable, ROOT / 'tools/test_ui.py', '--output', folder, '--timeout', '25']
            if args.runtime:
                command += ['--runtime', args.runtime]
            if args.lua_only:
                command += ['--lua-only']
            process = run_process(command, folder, 65, cwd=ROOT)
        child_report = folder / 'report.json'
        detail = json.loads(child_report.read_text(encoding='utf-8')) if child_report.exists() else None
        result['suites'][suite] = {'process': process, 'detail': detail,
                                    'ok': process['ok'] and (not detail or detail.get('ok', False))}
    result['ok'] = bool(selected) and all(s['ok'] for s in result['suites'].values())
    (output / 'report.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    (BUILD / 'latest-test.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))
    return 0 if result['ok'] else 1

if __name__ == '__main__':
    sys.exit(main())
