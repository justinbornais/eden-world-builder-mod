.intel_syntax noprefix
.text

.extern GETKEY_IAT
.extern CALLOC_IAT
.extern GETENV_IAT
.extern FOPEN_IAT
.extern FREAD_IAT
.extern FWRITE_IAT
.extern FCLOSE_IAT
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
.set ALLOC_SIZE,    0x840200
.set PRESET_BYTES,  0x780000
.set FILE_HEADER,   52

.global macro_input
macro_input:
    sub rsp, 0x28
    /* Escape cancels every macro mode except an active recording with edits. */
    mov ecx, 0x1b
    call qword ptr [rip + GETKEY_IAT]
    test ax, ax
    jz 1f
    cmp byte ptr [rip + MACRO_STATE], 2
    je 1f
    mov byte ptr [rip + MACRO_STATE], 0
1:
    mov ecx, 0x4d
    call qword ptr [rip + GETKEY_IAT]
    test al, 1
    jz 2f
    call macro_toggle
2:
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
    /* Load persisted presets once, immediately after the lazy allocation. */
    sub rsp, 8
    call macro_load_file
    add rsp, 8
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
    cld
    rep movsq
    call macro_save_file
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

/*
 * Make replay independent of the block currently selected by the user.
 * Preserve the selection, then apply the preset's first event before the
 * native anchor placement. The argument registers for buildBlock are saved.
 */
.org 0x300, 0xcc
.global macro_prepare_anchor
macro_prepare_anchor:
    cmp byte ptr [rip + MACRO_STATE], 5
    jne macro_prepare_done
    push rcx
    push rdx
    push r8
    push r9
    mov rax, qword ptr [rip + WORLD_REFPTR]
    mov rax, qword ptr [rax]
    mov rax, qword ptr [rax + 0x20]
    mov edx, dword ptr [rax + 0x18]
    mov dword ptr [rip + META + 0x50], edx
    mov edx, dword ptr [rax + 0x1c]
    mov dword ptr [rip + META + 0x54], edx
    mov dl, byte ptr [rax + 0x9ec]
    mov byte ptr [rip + META + 0x58], dl
    movzx edx, byte ptr [rip + MACRO_SLOT]
    inc edx
    imul edx, edx, SLOT_SIZE
    mov r10, qword ptr [rip + MACRO_PTR]
    add r10, rdx
    mov edx, dword ptr [r10 + 12]
    mov dword ptr [rax + 0x18], edx
    mov edx, dword ptr [r10 + 16]
    mov dword ptr [rax + 0x1c], edx
    mov dl, byte ptr [r10 + 20]
    mov byte ptr [rax + 0x9ec], dl
    pop r9
    pop r8
    pop rdx
    pop rcx
macro_prepare_done:
    ret

/* Build %APPDATA%\Eden\eden_macros.dat in the allocation's tail buffer. */
.org 0x400, 0xcc
macro_make_path:
    mov rcx, qword ptr [rip + MACRO_PTR]
    add rcx, 0x840000
    xor edx, edx
1:
    cmp edx, 400
    jae 3f
    mov al, byte ptr [r10 + rdx]
    test al, al
    jz 2f
    mov byte ptr [rcx + rdx], al
    inc edx
    jmp 1b
2:
    lea r11, [rip + macro_suffix]
    xor r8d, r8d
4:
    mov al, byte ptr [r11 + r8]
    mov byte ptr [rcx + rdx], al
    inc edx
    inc r8d
    test al, al
    jnz 4b
    mov rax, rcx
    ret
3:
    xor eax, eax
    ret

macro_load_file:
    push rbx
    sub rsp, 0x20
    lea rcx, [rip + appdata_name]
    call qword ptr [rip + GETENV_IAT]
    test rax, rax
    jz macro_load_done
    mov r10, rax
    call macro_make_path
    test rax, rax
    jz macro_load_done
    mov rcx, rax
    lea rdx, [rip + mode_rb]
    call qword ptr [rip + FOPEN_IAT]
    test rax, rax
    jz macro_load_done
    mov rbx, rax
    lea rcx, [rip + META + 0x60]
    mov edx, 1
    mov r8d, FILE_HEADER
    mov r9, rbx
    call qword ptr [rip + FREAD_IAT]
    cmp eax, FILE_HEADER
    jne macro_load_close
    movabs rax, 0x313043414d4e4445 /* "EDNMAC01" */
    cmp qword ptr [rip + META + 0x60], rax
    jne macro_load_close
    cmp dword ptr [rip + META + 0x68], 1
    jne macro_load_close
    xor ecx, ecx
macro_validate_counts:
    cmp ecx, 10
    jae macro_load_slots
    lea rdx, [rip + META + 0x6c]
    cmp dword ptr [rdx + rcx*4], MAX_EVENTS
    ja macro_load_close
    inc ecx
    jmp macro_validate_counts
macro_load_slots:
    mov rcx, qword ptr [rip + MACRO_PTR]
    add rcx, SLOT_SIZE
    mov edx, 1
    mov r8d, PRESET_BYTES
    mov r9, rbx
    call qword ptr [rip + FREAD_IAT]
    cmp eax, PRESET_BYTES
    jne macro_load_close
    xor ecx, ecx
macro_copy_counts:
    cmp ecx, 10
    jae macro_load_close
    lea rdx, [rip + META + 0x6c]
    mov eax, dword ptr [rdx + rcx*4]
    lea rdx, [rip + PRESET_COUNTS]
    mov dword ptr [rdx + rcx*4], eax
    inc ecx
    jmp macro_copy_counts
macro_load_close:
    mov rcx, rbx
    call qword ptr [rip + FCLOSE_IAT]
macro_load_done:
    add rsp, 0x20
    pop rbx
    ret

macro_save_file:
    push rbx
    sub rsp, 0x20
    lea rcx, [rip + appdata_name]
    call qword ptr [rip + GETENV_IAT]
    test rax, rax
    jz macro_save_file_done
    mov r10, rax
    call macro_make_path
    test rax, rax
    jz macro_save_file_done
    mov rcx, rax
    lea rdx, [rip + mode_wb]
    call qword ptr [rip + FOPEN_IAT]
    test rax, rax
    jz macro_save_file_done
    mov rbx, rax
    movabs rax, 0x313043414d4e4445
    mov qword ptr [rip + META + 0x60], rax
    mov dword ptr [rip + META + 0x68], 1
    xor ecx, ecx
macro_header_counts:
    cmp ecx, 10
    jae macro_write_header
    lea rdx, [rip + PRESET_COUNTS]
    mov eax, dword ptr [rdx + rcx*4]
    lea rdx, [rip + META + 0x6c]
    mov dword ptr [rdx + rcx*4], eax
    inc ecx
    jmp macro_header_counts
macro_write_header:
    lea rcx, [rip + META + 0x60]
    mov edx, 1
    mov r8d, FILE_HEADER
    mov r9, rbx
    call qword ptr [rip + FWRITE_IAT]
    cmp eax, FILE_HEADER
    jne macro_save_close
    mov rcx, qword ptr [rip + MACRO_PTR]
    add rcx, SLOT_SIZE
    mov edx, 1
    mov r8d, PRESET_BYTES
    mov r9, rbx
    call qword ptr [rip + FWRITE_IAT]
macro_save_close:
    mov rcx, rbx
    call qword ptr [rip + FCLOSE_IAT]
macro_save_file_done:
    add rsp, 0x20
    pop rbx
    ret

appdata_name: .asciz "APPDATA"
mode_rb:      .asciz "rb"
mode_wb:      .asciz "wb"
macro_suffix: .asciz "\\Eden\\eden_macros.dat"

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
    mov eax, dword ptr [rip + META + 0x50]
    mov dword ptr [rsp + 0x24], eax
    mov eax, dword ptr [rip + META + 0x54]
    mov dword ptr [rsp + 0x28], eax
    mov al, byte ptr [rip + META + 0x58]
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
