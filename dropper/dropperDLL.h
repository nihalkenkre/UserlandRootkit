#pragma once

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

__declspec(dllexport) void insert_ph_implant(void);
__declspec(dllexport) void hook_ph(void);
__declspec(dllexport) void hide_process(LPSTR lpProcName);
__declspec(dllexport) void show_process(LPSTR lpProcName);
__declspec(dllexport) void unhook_ph(void);
__declspec(dllexport) void remove_ph_implant(void);