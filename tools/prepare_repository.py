"""Create a reviewed source-only sibling tree. Never delete original files.

No credentials, network, repository visibility changes, push or GitHub writes.
The caller must separately verify a PRIVATE destination before publishing.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
from build import ROOT, BUILD

SOURCE_FILES = [
    '.gitignore', 'CMakeLists.txt', 'build.ps1', 'test.ps1', 'run.ps1',
    'native/core.h', 'native/core.cpp',
    'tests/test_core.py', 'tests/test_store.lua',
    'tools/build.py', 'tools/process_runner.py', 'tools/lua_runtime.py',
    'tools/test.py', 'tools/test_lua.py', 'tools/test_suites.py',
    'tools/test_ui.py', 'tools/test_ui_embedded.py',
    'tools/prepare_repository.py', 'tests/test_publication.py',
]
DENIED_SUFFIXES = {'.exe', '.dll', '.so', '.dylib', '.dex', '.vdex', '.odex', '.oat',
    '.apk', '.apk+', '.apks', '.xapk', '.aab', '.obj', '.o', '.lib', '.a', '.pdb',
    '.zip', '.7z', '.rar', '.tar', '.gz', '.bak', '.log', '.dmp', '.pyc', '.png',
    '.rbd', '.ipv', '.ipvz', '.pem', '.key', '.pfx', '.jks', '.keystore'}
DENIED_PARTS = {'build', 'dist', 'user-data', 'evidence', 'archive', '__pycache__',
                '.aws', '.codex', '.agents', 'node_modules'}
PATTERNS = {
    'github-token': re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})'),
    'aws-access-key': re.compile(r'(?:AKIA|ASIA)[0-9A-Z]{16}'),
    'private-key': re.compile(r'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----'),
    'personal-profile-path': re.compile(r'[A-Za-z]:(?:[\\/])+(?:Users|Documents and Settings)(?:[\\/])+[^\\/\s\"\']+', re.I),
    'email-address': re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    'decompiler-record': re.compile(r'"(?:raw_result|normalized_result|bytes_hex)"\s*:'),
    'decompiled-source-marker': re.compile('JADX' + r' WARN|@Override\s*//|Method dump ' + 'skipped'),
}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def review_file(name, data):
    path = pathlib.PurePosixPath(name)
    errors = []
    if path.is_absolute() or '..' in path.parts:
        errors.append('unsafe-relative-path')
    if path.suffix.lower() in DENIED_SUFFIXES or any(p in DENIED_PARTS for p in path.parts):
        errors.append('excluded-artifact-or-directory')
    if data.startswith((b'MZ', b'\x7fELF', b'PK\x03\x04')) or b'\0' in data:
        errors.append('binary-content')
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return errors + ['not-utf8-text']
    for label, pattern in PATTERNS.items():
        if pattern.search(text):
            errors.append(label)
    return errors

def plan_files():
    plan = {name: ROOT / name for name in SOURCE_FILES}
    for file in sorted((ROOT / 'app').glob('*.lua')):
        plan[file.relative_to(ROOT).as_posix()] = file
    if (ROOT / 'publication').is_dir():
        for file in sorted((ROOT / 'publication').rglob('*')):
            if file.is_file():
                plan[file.relative_to(ROOT / 'publication').as_posix()] = file
    else:
        # A prepared checkout already contains the reviewed documents at root.
        plan['README.md'] = ROOT / 'README.md'
        for file in sorted((ROOT / 'docs').rglob('*')):
            if file.is_file() and file.suffix in ('.md', '.json'):
                plan[file.relative_to(ROOT).as_posix()] = file
    return plan

def prepare(output):
    output = pathlib.Path(output).resolve()
    boundary = ROOT.parent.resolve()
    if not output.is_relative_to(boundary) or output == ROOT or output.is_relative_to(ROOT):
        raise ValueError('Publication tree must be a sibling inside the research workspace, never the source/original tree.')
    plan = plan_files()
    reviewed = {}
    problems = []
    for name, source in sorted(plan.items()):
        if not source.is_file() or source.is_symlink():
            raise ValueError('Missing/non-regular allowlisted source: ' + name)
        content = source.read_bytes()
        failures = review_file(name, content)
        if failures:
            problems.append({'path': name, 'findings': failures})
        reviewed[name] = {'sha256': digest(content), 'bytes': len(content),
                          'source': source.relative_to(ROOT).as_posix()}
    if problems:
        raise ValueError('Review rejected: ' + json.dumps(problems))
    previous = {}
    audit_path = BUILD / 'publication-review.json'
    if audit_path.exists():
        saved = json.loads(audit_path.read_text(encoding='utf-8'))
        if pathlib.Path(saved.get('output', '')).resolve() == output:
            previous = saved.get('files', {})
    # Never clear/remove a destination. Only replace a reviewed copy if its
    # current bytes still match our previous manifest; preserve user edits.
    if output.exists():
        for file in output.rglob('*'):
            relative_parts = file.relative_to(output).parts
            # Validation may have produced ignored local build/cache output.
            # Leave it untouched and outside the publication manifest.
            if any(part in {'.git', 'build', 'dist', '__pycache__'} for part in relative_parts):
                continue
            if file.is_file():
                relative = file.relative_to(output).as_posix()
                current = digest(file.read_bytes())
                if relative not in reviewed or (current != reviewed[relative]['sha256']
                        and current != previous.get(relative, {}).get('sha256')):
                    raise ValueError('Destination has an unreviewed/different file; preserved without overwrite: ' + relative)
    output.mkdir(parents=True, exist_ok=True)
    for name, record in reviewed.items():
        destination = output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or digest(destination.read_bytes()) != record['sha256']:
            destination.write_bytes(plan[name].read_bytes())
        if digest(destination.read_bytes()) != record['sha256']:
            raise ValueError('Publication hash mismatch: ' + name)
    broken = []
    for name in reviewed:
        if name.endswith('.md'):
            for link in re.findall(r'\]\(([^)]+)\)', (output / name).read_text(encoding='utf-8')):
                if '://' not in link and not link.startswith('#'):
                    if not (output / name).parent.joinpath(link.split('#')[0]).exists():
                        broken.append({'path': name, 'link': link})
    if broken:
        raise ValueError('Broken local documentation links: ' + json.dumps(broken))
    # Verify reads/copying did not change the allowlisted originals.
    assert all(digest(plan[n].read_bytes()) == r['sha256'] for n, r in reviewed.items())
    manifest = {'kind': 'reviewed-source-only-publication', 'files': reviewed,
                'file_count': len(reviewed), 'review_findings': [], 'broken_links': [],
                'originals_preserved': True, 'remote_writes_performed': False,
                'private_repository_required': True, 'output': str(output)}
    BUILD.mkdir(exist_ok=True)
    (BUILD / 'publication-review.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default=str(ROOT.parent / 'github-ready/Ibis-Rebuild-Windows'))
    args = parser.parse_args()
    try:
        report = prepare(args.output)
        print(json.dumps({'output': report['output'], 'files': report['file_count'],
                          'review_findings': [], 'originals_preserved': True,
                          'remote_writes_performed': False}, indent=2))
        return 0
    except Exception as error:
        print('PUBLICATION PREPARATION FAILED:', error, file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
