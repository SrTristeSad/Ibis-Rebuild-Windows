"""Offline build/package entry point. Does not install or download toolchains."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,sys,time,zipfile
from process_runner import run_process
ROOT=pathlib.Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'
def run(args,**kw):
    print('RUN',subprocess.list2cmdline([str(x) for x in args]),flush=True)
    logs=BUILD/'commands'/str(time.time_ns())
    result=run_process(args,logs,120,**kw)
    if not result['ok']:
        print((logs/'stderr.log').read_text(errors='replace')[-3000:],file=sys.stderr)
        raise RuntimeError('Command failed or timed out; logs: '+str(logs))
    return result
def candidates(explicit):
    if explicit:return [pathlib.Path(explicit)]
    result=[]
    for name in ['clang-cl','clang++','clang','cl']:
        p=shutil.which(name)
        if p:result.append(pathlib.Path(p))
    local_appdata=os.environ.get('LOCALAPPDATA')
    sdk=pathlib.Path(local_appdata)/'Android/Sdk/ndk' if local_appdata else None
    if sdk and sdk.exists():result+=sorted(sdk.glob('*/toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe'),reverse=True)
    return list(dict.fromkeys(result))
def compile_core(compiler=None):
    BUILD.mkdir(exist_ok=True); attempts=[]; selected=None
    for c in candidates(compiler):
        try:
            r=subprocess.run([str(c),'--version' if c.stem.lower()!='cl' else '/?'],capture_output=True,text=True,timeout=20)
            attempts.append({'path':str(c),'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
            if r.returncode==0:selected=c;break
        except (OSError,subprocess.TimeoutExpired) as e:attempts.append({'path':str(c),'error':str(e)})
    report={'attempts':attempts,'selected':str(selected) if selected else None,'downloaded':False}
    (BUILD/'toolchain-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    if not selected:raise RuntimeError('No usable C++ compiler. See build/toolchain-report.json; set --compiler to an installed compiler.')
    obj=BUILD/'core.obj'; ink_obj=BUILD/'win_ink.obj'; dll=BUILD/'rebuild_core.dll'; src=ROOT/'native/core.cpp'; ink_src=ROOT/'native/win_ink.cpp'
    if selected.stem.lower() in ('cl','clang-cl'):
        run([selected,'/nologo','/c','/O2','/GS-','/GR-','/Zl','/fp:precise','/std:c++17',src,'/Fo'+str(obj)])
        run([selected,'/nologo','/c','/O2','/GS-','/GR-','/Zl','/fp:precise','/std:c++17',ink_src,'/Fo'+str(ink_obj)])
        link=selected.parent/'link.exe'
        if not link.exists():link=pathlib.Path(shutil.which('link') or str(selected.parent/'lld-link.exe'))
        if link.exists():command=[link]
        elif (selected.parent/'ld.lld.exe').exists():command=[selected.parent/'ld.lld.exe','-flavor','link']
        else:raise RuntimeError('COFF linker not found; use a configured developer environment.')
        run(command+['/DLL','/NOENTRY','/NODEFAULTLIB','/MACHINE:X64','/OUT:'+str(dll),obj,ink_obj,'user32.lib','kernel32.lib'])
    else:
        run([selected,'--target=x86_64-pc-windows-msvc','-std=c++17','-O2','-ffreestanding','-fno-fast-math','-fno-builtin','-fno-exceptions','-fno-rtti','-fno-stack-protector','-c',src,'-o',obj])
        run([selected,'--target=x86_64-pc-windows-msvc','-std=c++17','-O2','-ffreestanding','-fno-fast-math','-fno-builtin','-fno-exceptions','-fno-rtti','-fno-stack-protector','-c',ink_src,'-o',ink_obj])
        link=selected.parent/'lld-link.exe'
        if link.exists():command=[link]
        else:
            link=selected.parent/'ld.lld.exe'
            if not link.exists():raise RuntimeError('COFF linker not found beside Clang.')
            command=[link,'-flavor','link']
        run(command+['/dll','/noentry','/nodefaultlib','/machine:x64','/out:'+str(dll),obj,ink_obj,'user32.lib','kernel32.lib'])
    # A loaded x64 DLL is required; a compiler success code alone is insufficient.
    import ctypes
    lib=ctypes.CDLL(str(dll));lib.rb_version.argtypes=[];lib.rb_version.restype=ctypes.c_uint32
    if lib.rb_version()!=1:raise RuntimeError('Unexpected native ABI.')
    report.update({'dll':str(dll),'sha256':hashlib.sha256(dll.read_bytes()).hexdigest(),'abi':1})
    (BUILD/'toolchain-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    return dll
def runtime(path=None):
    choices=[path,os.environ.get('LOVE_RUNTIME'),r'C:\Program Files\LOVE']
    for choice in choices:
        if choice and (pathlib.Path(choice)/'love.exe').is_file():return pathlib.Path(choice)
    raise RuntimeError('LÖVE 11.5 x64 runtime missing; use --runtime or LOVE_RUNTIME.')
def package(runtime_dir=None,require_native=True):
    rt=runtime(runtime_dir); dist=ROOT/'dist';dist.mkdir(exist_ok=True)
    dll=BUILD/'rebuild_core.dll'
    if require_native and not dll.is_file():raise RuntimeError('A real compiled native DLL is required for the normal release.')
    archive=BUILD/'app.love';BUILD.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for f in sorted((ROOT/'app').rglob('*')):
            if f.is_file():z.write(f,f.relative_to(ROOT/'app').as_posix())
        if (ROOT/'tests/test_store.lua').exists():z.write(ROOT/'tests/test_store.lua','tests/test_store.lua')
    exe=dist/'Android1412Rebuild.exe'
    with exe.open('wb') as out:
        out.write((rt/'love.exe').read_bytes());out.write(archive.read_bytes())
    for f in rt.glob('*.dll'):shutil.copy2(f,dist/f.name)
    shutil.copy2(rt/'license.txt',dist/'LOVE-LICENSE.txt')
    if dll.is_file():shutil.copy2(dll,dist/dll.name)
    shutil.copy2(ROOT/'README.md',dist/'README.md')
    manifest={'project_version':'0.1.0','stage':'gallery-canvas-input-contract','native_included':dll.is_file(),'runtime':str(rt),'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'sources':{f.relative_to(ROOT).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for folder in ['app','native'] for f in sorted((ROOT/folder).rglob('*')) if f.is_file()},'offline':True,'webview':False}
    (dist/'build-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('PACKAGED',exe,flush=True);return exe
def main():
    ap=argparse.ArgumentParser();ap.add_argument('command',choices=['build','package','all','lua-shell'])
    ap.add_argument('--compiler');ap.add_argument('--runtime');args=ap.parse_args()
    if args.command in ('build','all'):compile_core(args.compiler)
    if args.command in ('package','all','lua-shell'):package(args.runtime,require_native=args.command!='lua-shell')
if __name__=='__main__':
    try:main()
    except Exception as e:print('BUILD FAILED:',str(e),file=sys.stderr);sys.exit(1)
