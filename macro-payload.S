.intel_syntax noprefix
.text

.extern GETKEY_IAT
.extern CALLOC_IAT
.extern WORLD_REFPTR
.extern BUILD_BLOCK
.extern DESTROY_BLOCK
.extern PAINT_BLOCK
.extern DESTROY_RETURN
.extern PAINT_RETURN
.extern META
.set MACRO_PTR,     META+0x00
.set MACRO_STATE,   META+0x08
.set MACRO_COUNT,   META+0x0c
.set MACRO_SLOT,    META+0x10
.set MACRO_AX,      META+0x14
.set MACRO_AY,      META+0x18
.set MACRO_AZ,      META+0x1c
.set PRESET_COUNTS, META+0x20

.set EVENT_SIZE,    24
.set MAX_EVENTS,    32768
.set SLOT_SIZE,     0x0c0000
.set ALLOC_SIZE,    0x840000

.global macro_input
macro_input:
    sub rsp, 0x28
    mov ecx, 0x4d
    call qword ptr [rip + GETKEY_IAT]
    test al, 1
    jz 1f
    call macro_toggle
1:
    mov ecx, 0x31
    xor edx, edx
    call poll_digit
    mov ecx, 0x32
    mov edx, 1
    call poll_digit
    mov ecx, 0x33
    mov edx, 2
    call poll_digit
    mov ecx, 0x34
    mov edx, 3
    call poll_digit
    mov ecx, 0x35
    mov edx, 4
    call poll_digit
    mov ecx, 0x36
    mov edx, 5
    call poll_digit
    mov ecx, 0x37
    mov edx, 6
    call poll_digit
    mov ecx, 0x38
    mov edx, 7
    call poll_digit
    mov ecx, 0x39
    mov edx, 8
    call poll_digit
    mov ecx, 0x30
    mov edx, 9
    call poll_digit
    add rsp, 0x28
    ret

poll_digit:
    push rdx
    sub rsp, 0x20
    call qword ptr [rip + GETKEY_IAT]
    add rsp, 0x20
    pop rcx
    test al, 1
    jz 1f
    call macro_digit
1:  ret

macro_toggle:
    cmp byte ptr [rip + MACRO_STATE], 1
    je macro_stop
    cmp byte ptr [rip + MACRO_STATE], 2
    je macro_stop
    cmp qword ptr [rip + MACRO_PTR], 0
    jne 1f
    mov ecx, 1
    mov edx, ALLOC_SIZE
    sub rsp, 0x28
    call qword ptr [rip + CALLOC_IAT]
    add rsp, 0x28
    test rax, rax
    jz macro_toggle_done
    mov qword ptr [rip + MACRO_PTR], rax
1:
    mov dword ptr [rip + MACRO_COUNT], 0
    mov byte ptr [rip + MACRO_STATE], 1
    ret
macro_stop:
    mov byte ptr [rip + MACRO_STATE], 3
macro_toggle_done:
    ret

macro_digit:
    push rsi
    push rdi
    mov r10d, ecx
    cmp byte ptr [rip + MACRO_STATE], 3
    je macro_save
    cmp byte ptr [rip + MACRO_STATE], 1
    jne macro_digit_done
    cmp dword ptr [rip + MACRO_COUNT], 0
    jne macro_digit_done
    lea rax, [rip + PRESET_COUNTS]
    mov eax, dword ptr [rax + r10*4]
    test eax, eax
    jz macro_digit_done
    mov byte ptr [rip + MACRO_SLOT], r10b
    mov byte ptr [rip + MACRO_STATE], 5
    jmp macro_digit_done
macro_save:
    mov eax, dword ptr [rip + MACRO_COUNT]
    test eax, eax
    jz macro_save_finish
    lea rdx, [rip + PRESET_COUNTS]
    mov dword ptr [rdx + r10*4], eax
    mov rsi, qword ptr [rip + MACRO_PTR]
    mov ecx, r10d
    inc ecx
    imul ecx, ecx, SLOT_SIZE
    mov rdi, rsi
    add rdi, rcx
    lea ecx, [rax + rax*2]
    rep movsq
macro_save_finish:
    mov byte ptr [rip + MACRO_STATE], 0
macro_digit_done:
    pop rdi
    pop rsi
    ret

/* eax=operation, coordinates in ebx/esi/edi. */
macro_record:
    cmp byte ptr [rip + MACRO_STATE], 1
    je 1f
    cmp byte ptr [rip + MACRO_STATE], 2
    jne macro_record_done
1:
    mov r10, qword ptr [rip + MACRO_PTR]
    test r10, r10
    jz macro_record_done
    mov ecx, dword ptr [rip + MACRO_COUNT]
    cmp ecx, MAX_EVENTS
    jae macro_record_full
    mov r11d, eax
    test ecx, ecx
    jne 2f
    mov dword ptr [rip + MACRO_AX], ebx
    mov dword ptr [rip + MACRO_AY], esi
    mov dword ptr [rip + MACRO_AZ], edi
    mov byte ptr [rip + MACRO_STATE], 2
2:
    lea eax, [rcx + rcx*2]
    shl eax, 3
    add r10, rax
    mov eax, ebx
    sub eax, dword ptr [rip + MACRO_AX]
    mov dword ptr [r10 + 0], eax
    mov eax, esi
    sub eax, dword ptr [rip + MACRO_AY]
    mov dword ptr [r10 + 4], eax
    mov eax, edi
    sub eax, dword ptr [rip + MACRO_AZ]
    mov dword ptr [r10 + 8], eax
    mov rax, qword ptr [rip + WORLD_REFPTR]
    mov rax, qword ptr [rax]
    mov rax, qword ptr [rax + 0x20]
    mov edx, dword ptr [rax + 0x18]
    mov dword ptr [r10 + 12], edx
    mov edx, dword ptr [rax + 0x1c]
    mov dword ptr [r10 + 16], edx
    mov dl, byte ptr [rax + 0x9ec]
    mov byte ptr [r10 + 20], dl
    mov byte ptr [r10 + 21], r11b
    inc ecx
    mov dword ptr [rip + MACRO_COUNT], ecx
    cmp ecx, MAX_EVENTS
    jb macro_record_done
macro_record_full:
    mov byte ptr [rip + MACRO_STATE], 3
macro_record_done:
    ret

.org 0x1000, 0xcc
.global macro_build
macro_build:
    cmp byte ptr [rip + MACRO_STATE], 5
    je macro_playback
    xor eax, eax
    jmp macro_record

macro_playback:
    push rbx
    push rsi
    push rdi
    push rbp
    push r12
    push r14
    push r15
    sub rsp, 0x30
    mov r12d, ebx
    mov r14d, esi
    mov r15d, edi
    movzx eax, byte ptr [rip + MACRO_SLOT]
    lea rdx, [rip + PRESET_COUNTS]
    mov edi, dword ptr [rdx + rax*4]
    mov ecx, eax
    inc ecx
    imul ecx, ecx, SLOT_SIZE
    mov rsi, qword ptr [rip + MACRO_PTR]
    add rsi, rcx
    mov rax, qword ptr [rip + WORLD_REFPTR]
    mov rax, qword ptr [rax]
    mov rbp, qword ptr [rax + 0x20]
    mov eax, dword ptr [rbp + 0x18]
    mov dword ptr [rsp + 0x24], eax
    mov eax, dword ptr [rbp + 0x1c]
    mov dword ptr [rsp + 0x28], eax
    mov al, byte ptr [rbp + 0x9ec]
    mov byte ptr [rsp + 0x2c], al
    xor ebx, ebx
macro_play_loop:
    cmp ebx, edi
    jae macro_play_done
    mov eax, dword ptr [rsi + 12]
    mov dword ptr [rbp + 0x18], eax
    mov eax, dword ptr [rsi + 16]
    mov dword ptr [rbp + 0x1c], eax
    mov al, byte ptr [rsi + 20]
    mov byte ptr [rbp + 0x9ec], al
    mov edx, dword ptr [rsi + 0]
    add edx, r12d
    mov r8d, dword ptr [rsi + 4]
    add r8d, r14d
    mov r9d, dword ptr [rsi + 8]
    add r9d, r15d
    mov rax, qword ptr [rip + WORLD_REFPTR]
    mov rax, qword ptr [rax]
    mov rcx, qword ptr [rax]
    cmp byte ptr [rsi + 21], 1
    je macro_play_destroy
    cmp byte ptr [rsi + 21], 2
    je macro_play_paint
    call BUILD_BLOCK
    jmp macro_play_next
macro_play_destroy:
    call DESTROY_BLOCK
    jmp macro_play_next
macro_play_paint:
    movzx eax, byte ptr [rsi + 20]
    mov dword ptr [rsp + 0x20], eax
    call PAINT_BLOCK
macro_play_next:
    add rsi, EVENT_SIZE
    inc ebx
    jmp macro_play_loop
macro_play_done:
    mov eax, dword ptr [rsp + 0x24]
    mov dword ptr [rbp + 0x18], eax
    mov eax, dword ptr [rsp + 0x28]
    mov dword ptr [rbp + 0x1c], eax
    mov al, byte ptr [rsp + 0x2c]
    mov byte ptr [rbp + 0x9ec], al
    mov byte ptr [rip + MACRO_STATE], 0
    add rsp, 0x30
    pop r15
    pop r14
    pop r12
    pop rbp
    pop rdi
    pop rsi
    pop rbx
    ret

.org 0x1800, 0xcc
.global macro_destroy
macro_destroy:
    call DESTROY_BLOCK
    mov eax, 1
    call macro_record
    jmp DESTROY_RETURN

.org 0x1840, 0xcc
.global macro_paint
macro_paint:
    call PAINT_BLOCK
    push rdi
    mov edi, r14d
    mov eax, 2
    call macro_record
    pop rdi
    jmp PAINT_RETURN
