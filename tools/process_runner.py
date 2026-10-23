"""Bounded owned child process with durable command, logs and exit status."""
import json
import pathlib
import subprocess
import time

def run_process(command, output, timeout, cwd=None, env=None):
    output = pathlib.Path(output)
    output.mkdir(parents=True, exist_ok=True)
    argv = [str(value) for value in command]
    result = {'command': argv, 'timeout_seconds': timeout, 'timed_out': False,
              'exit_code': None, 'ok': False}
    started = time.monotonic()
    stdout, stderr = b'', b''
    try:
        process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        result['pid'] = process.pid
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            result['timed_out'] = True
            process.kill()
            stdout, stderr = process.communicate(timeout=5)
        result['exit_code'] = process.returncode
        result['ok'] = process.returncode == 0 and not result['timed_out']
    except OSError as error:
        result['launch_error'] = str(error)
    result['duration_seconds'] = round(time.monotonic() - started, 3)
    (output / 'stdout.log').write_bytes(stdout)
    (output / 'stderr.log').write_bytes(stderr)
    (output / 'process.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result
