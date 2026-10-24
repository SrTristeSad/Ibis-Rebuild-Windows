/* Original Windows Ink event bridge for the current LÖVE window only.
   Win32 WM_POINTER messages are forwarded to SDL's original WndProc.
   No Android/iBis source, injection, worker thread or CRT allocation. */
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0602
#endif
#include <windows.h>
#include "core.h"

static_assert(sizeof(RBInkEvent)==44, "x64 FFI pen event size");

namespace {
constexpr rb_u32 QUEUE_SIZE=512;
RBInkEvent queue[QUEUE_SIZE]={};
rb_u32 read_index=0,write_index=0,dropped=0;
HWND tracked_window=0;
WNDPROC previous_proc=0;
DWORD owner_thread=0;
rb_u32 active_pointer=0;
ULONGLONG last_pen_tick=0;

void offer(const RBInkEvent& event) {
    const rb_u32 next=(write_index+1)%QUEUE_SIZE;
    if (next==read_index) {
        ++dropped;
        if (event.kind==2) return; // Never displace DOWN/UP for MOVE.
        read_index=(read_index+1)%QUEUE_SIZE;
    }
    queue[write_index]=event;
    write_index=next;
}
void reset_window() {
    tracked_window=0;previous_proc=0;owner_thread=0;active_pointer=0;
    read_index=0;write_index=0;last_pen_tick=0;dropped=0;
}
bool current_thread() { return owner_thread==GetCurrentThreadId(); }
rb_u32 kind_of(UINT message) {
    if (message==WM_POINTERDOWN) return 1;
    if (message==WM_POINTERUPDATE) return 2;
    if (message==WM_POINTERUP) return 3;
    if (message==WM_POINTERCAPTURECHANGED) return 4;
    return 0;
}
LRESULT CALLBACK ink_proc(HWND hwnd,UINT msg,WPARAM wparam,LPARAM lparam) {
    const WNDPROC original=previous_proc;
    const rb_u32 kind=kind_of(msg);
    if (kind && hwnd==tracked_window) {
        const rb_u32 id=static_cast<rb_u32>(wparam&0xFFFFu);
        POINTER_INPUT_TYPE pointer_type=PT_POINTER;
        const bool confirmed=(GetPointerType(id,&pointer_type)!=0 &&
                              pointer_type==PT_PEN);
        const bool owned=(active_pointer!=0 && active_pointer==id);
        if ((confirmed || owned) && (kind!=1 || active_pointer==0 || owned)) {
            POINT position={static_cast<LONG>(static_cast<short>(lparam&0xFFFF)),
                            static_cast<LONG>(static_cast<short>((lparam>>16)&0xFFFF))};
            POINTER_PEN_INFO pen={};
            const bool has_pen=GetPointerPenInfo(id,&pen)!=0;
            if (has_pen) position=pen.pointerInfo.ptPixelLocation;
            ScreenToClient(hwnd,&position);
            RECT rect={};
            GetClientRect(hwnd,&rect);
            RBInkEvent event={};
            event.kind=static_cast<rb_i32>(kind);
            event.pointer_id=id;
            event.x=static_cast<float>(position.x);
            event.y=static_cast<float>(position.y);
            event.pressure=has_pen?rb_ink_pressure(pen.pressure,pen.penMask):1.0f;
            event.tilt_x=has_pen && (pen.penMask&PEN_MASK_TILT_X)?pen.tiltX:0;
            event.tilt_y=has_pen && (pen.penMask&PEN_MASK_TILT_Y)?pen.tiltY:0;
            event.flags=has_pen?static_cast<rb_u32>(pen.penFlags):0;
            event.mask=has_pen?static_cast<rb_u32>(pen.penMask):0;
            event.client_width=static_cast<rb_u32>(rect.right-rect.left);
            event.client_height=static_cast<rb_u32>(rect.bottom-rect.top);
            if (kind==1 && active_pointer==0) active_pointer=id;
            if (owned || kind==1) {
                offer(event);
                last_pen_tick=GetTickCount64();
                if (kind==3 || kind==4) active_pointer=0;
            }
        }
    }
    if (msg==WM_NCDESTROY && hwnd==tracked_window) {
        // Do not keep a dangling window procedure chain.
        reset_window();
    }
    return original?CallWindowProcW(original,hwnd,msg,wparam,lparam):
        DefWindowProcW(hwnd,msg,wparam,lparam);
}
} // namespace

float rb_ink_pressure(rb_u32 raw,rb_u32 mask) {
    if (!(mask&PEN_MASK_PRESSURE)) return 1.0f;
    if (raw>=1024u) return 1.0f;
    return static_cast<float>(raw)/1024.0f;
}
rb_i32 rb_ink_is_attached(void) {
    return tracked_window && IsWindow(tracked_window)?1:0;
}
rb_i32 rb_ink_attach(void) {
    if (tracked_window) return current_thread() && IsWindow(tracked_window)?1:-1;
    HWND hwnd=GetActiveWindow();
    if (!hwnd || !IsWindow(hwnd)) return -1;
    DWORD process=0;
    const DWORD thread=GetWindowThreadProcessId(hwnd,&process);
    if (thread!=GetCurrentThreadId() || process!=GetCurrentProcessId()) return -1;
    SetLastError(0);
    const LONG_PTR old=SetWindowLongPtrW(hwnd,GWLP_WNDPROC,
                                        reinterpret_cast<LONG_PTR>(&ink_proc));
    if (!old) return -1;
    tracked_window=hwnd;
    previous_proc=reinterpret_cast<WNDPROC>(old);
    owner_thread=thread;
    read_index=write_index=dropped=0;
    active_pointer=0;
    last_pen_tick=0;
    return 1;
}
rb_i32 rb_ink_detach(void) {
    if (!tracked_window) return 0;
    if (!current_thread()) return -1;
    if (IsWindow(tracked_window)) {
        if (reinterpret_cast<WNDPROC>(GetWindowLongPtrW(tracked_window,GWLP_WNDPROC))
            !=&ink_proc) return -1; // Never break another subclass.
        SetLastError(0);
        const LONG_PTR old=SetWindowLongPtrW(tracked_window,GWLP_WNDPROC,
                                            reinterpret_cast<LONG_PTR>(previous_proc));
        if (!old) return -1;
    }
    reset_window();
    return 0;
}
rb_i32 rb_ink_mouse_guard(void) {
    if (!tracked_window || !current_thread()) return 0;
    if (active_pointer) return 1;
    // Some SDL mouse events are dispatched after the pen's WM_POINTERUP.
    if (last_pen_tick && GetTickCount64()-last_pen_tick<=150u) return 1;
    return 0;
}
rb_i32 rb_ink_poll(RBInkEvent* output,rb_u32 capacity) {
    if ((capacity && !output) || capacity>QUEUE_SIZE ||
        (tracked_window && !current_thread())) return -1;
    rb_u32 count=0;
    while (count<capacity && read_index!=write_index) {
        output[count++]=queue[read_index];
        read_index=(read_index+1)%QUEUE_SIZE;
    }
    return static_cast<rb_i32>(count);
}
rb_u32 rb_ink_dropped(void) { return dropped; }
