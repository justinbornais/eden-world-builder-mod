.intel_syntax noprefix
.text

.extern GETMODULEFILENAME_IAT
.extern FOPEN_IAT
.extern FGETS_IAT
.extern FCLOSE_IAT
.extern STRTOL_IAT

/* Load optional mod-config.yaml once; embedded defaults need no file. */
.global config_init
config_init:
    cmp byte ptr [rip + CONFIG_STATUS], 0
    jne config_done
    push rbx
    push rsi
    push rdi
    sub rsp, 0x20
    xor ecx, ecx
    lea rdx, [rip + CONFIG_PATH]
    mov r8d, 511
    call qword ptr [rip + GETMODULEFILENAME_IAT]
    test eax, eax
    jz config_defaults
    lea rdi, [rip + CONFIG_PATH]
    mov ecx, eax
find_slash:
    test ecx, ecx
    jz config_defaults
    dec ecx
    mov dl, byte ptr [rdi + rcx]
    cmp dl, '\\'
    je got_slash
    cmp dl, '/'
    jne find_slash
got_slash:
    inc ecx
    lea rsi, [rip + config_name]
copy_name:
    mov al, byte ptr [rsi]
    inc rsi
    mov byte ptr [rdi + rcx], al
    inc ecx
    test al, al
    jnz copy_name
    lea rcx, [rip + CONFIG_PATH]
    lea rdx, [rip + mode_rb]
    call qword ptr [rip + FOPEN_IAT]
    test rax, rax
    jz config_defaults
    mov rbx, rax
read_line:
    lea rcx, [rip + LINE_BUFFER]
    mov edx, 255
    mov r8, rbx
    call qword ptr [rip + FGETS_IAT]
    test rax, rax
    jz config_close
    mov rsi, rax
trim:
    mov al, byte ptr [rsi]
    cmp al, ' '
    je trim_one
    cmp al, 9
    jne dispatch
trim_one:
    inc rsi
    jmp trim
dispatch:
    mov rcx, rsi
    lea rdx, [rip + key_autoplace]
    call match_key
    test rax, rax
    jz try_range
    mov rcx, rax
    lea rdx, [rip + AUTOPLACE_VALUES]
    mov r8d, 8
    mov r9d, 1
    call parse_list
    test eax, eax
    jz read_line
    mov byte ptr [rip + AUTOPLACE_COUNT], al
    jmp read_line
try_range:
    mov rcx, rsi
    lea rdx, [rip + key_range]
    call match_key
    test rax, rax
    jz try_panel
    mov rcx, rax
    lea rdx, [rip + RANGE_VALUES]
    mov r8d, 8
    mov r9d, 2
    call parse_list
    test eax, eax
    jz read_line
    mov byte ptr [rip + RANGE_COUNT], al
    jmp read_line
try_panel:
    mov rcx, rsi
    lea rdx, [rip + key_panel]
    call match_key
    test rax, rax
    jz try_caps
    mov rcx, rax
    call parse_bool
    cmp eax, -1
    je read_line
    mov byte ptr [rip + PANEL_ENABLED], al
    jmp read_line
try_caps:
    mov rcx, rsi
    lea rdx, [rip + key_caps]
    call match_key
    test rax, rax
    jz read_line
    mov rcx, rax
    call parse_bool
    cmp eax, -1
    je read_line
    mov byte ptr [rip + CAPS_REPEAT_ENABLED], al
    jmp read_line
config_close:
    mov rcx, rbx
    call qword ptr [rip + FCLOSE_IAT]
    mov byte ptr [rip + CONFIG_STATUS], 1
    jmp config_exit
config_defaults:
    mov byte ptr [rip + CONFIG_STATUS], 1
config_exit:
    add rsp, 0x20
    pop rdi
    pop rsi
    pop rbx
config_done:
    ret

/* rcx=input, rdx=key. Return pointer after key or zero. */
match_key:
    mov al, byte ptr [rdx]
    test al, al
    jz key_yes
    cmp byte ptr [rcx], al
    jne key_no
    inc rcx
    inc rdx
    jmp match_key
key_yes:
    mov rax, rcx
    ret
key_no:
    xor eax, eax
    ret

/* Parse true/false after a key. */
parse_bool:
bool_trim:
    mov al, byte ptr [rcx]
    cmp al, ' '
    je bool_inc
    cmp al, 9
    jne bool_value
bool_inc:
    inc rcx
    jmp bool_trim
bool_value:
    or al, 0x20
    cmp al, 't'
    je bool_true
    cmp al, '1'
    je bool_true
    cmp al, 'f'
    je bool_false
    cmp al, '0'
    je bool_false
    mov eax, -1
    ret
bool_true:
    mov eax, 1
    ret
bool_false:
    xor eax, eax
    ret

/* rcx=list text, rdx=destination, r8=max count, r9=1 rates / 2 ranges. */
parse_list:
    push rbx
    push rsi
    push rdi
    push r12
    sub rsp, 0x28
    mov rsi, rcx
    mov rdi, rdx
    mov r12d, r9d
    xor ebx, ebx
seek_open:
    mov al, byte ptr [rsi]
    test al, al
    jz list_done
    inc rsi
    cmp al, '['
    jne seek_open
list_next:
    mov al, byte ptr [rsi]
    cmp al, ' '
    je list_advance
    cmp al, 9
    je list_advance
    cmp al, ','
    je list_advance
    cmp al, ']'
    je list_done
    test al, al
    jz list_done
    cmp ebx, 8
    jae list_done
    or al, 0x20
    cmp r12d, 1
    jne maybe_unlimited
    cmp al, 'm'
    je special_zero
maybe_unlimited:
    cmp r12d, 2
    jne parse_number
    cmp al, 'u'
    je special_zero
parse_number:
    mov rcx, rsi
    lea rdx, [rip + ENDPTR]
    mov r8d, 10
    call qword ptr [rip + STRTOL_IAT]
    mov rcx, qword ptr [rip + ENDPTR]
    cmp rcx, rsi
    je skip_token
    cmp eax, 1
    jl skip_token
    cmp r12d, 1
    jne range_limit
    cmp eax, 1000
    jg skip_token
    jmp store_value
range_limit:
    cmp eax, 448
    jg skip_token
store_value:
    mov dword ptr [rdi + rbx*4], eax
    inc ebx
    mov rsi, rcx
    jmp list_next
special_zero:
    mov dword ptr [rdi + rbx*4], 0
    inc ebx
skip_token:
    mov al, byte ptr [rsi]
    test al, al
    jz list_done
    cmp al, ','
    je list_advance
    cmp al, ']'
    je list_done
    inc rsi
    jmp skip_token
list_advance:
    inc rsi
    jmp list_next
list_done:
    mov eax, ebx
    add rsp, 0x28
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

mode_rb:          .asciz "rb"
config_name:      .asciz "mod-config.yaml"
key_autoplace:    .asciz "autoplace_presets:"
key_range:        .asciz "range_presets:"
key_panel:        .asciz "status_panel:"
key_caps:         .asciz "caps_lock_macro_repeat:"

.org 0x1000, 0
/* Defaults used when the optional file is absent or unreadable. */
CONFIG_STATUS:       .byte 0
AUTOPLACE_COUNT:     .byte 5
RANGE_COUNT:         .byte 4
PANEL_ENABLED:       .byte 1
CAPS_REPEAT_ENABLED: .byte 1
.org 0x1010, 0
AUTOPLACE_VALUES:
.long 5, 10, 20, 50, 0, 0, 0, 0
.org 0x1030, 0
RANGE_VALUES:
.long 20, 50, 100, 0, 0, 0, 0, 0
.org 0x1100, 0
CONFIG_PATH:
.space 0x200, 0
.org 0x1300, 0
LINE_BUFFER:
.space 0x1f8, 0
ENDPTR:
.quad 0
