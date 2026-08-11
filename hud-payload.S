.intel_syntax noprefix
.text

.extern HUD_BEGIN
.extern HUD_END
.extern STATUS_CTOR_RECT
.extern STATUS_FONT_FIT
.extern STATUS_SET
.extern STATUS_RENDER
.extern GETTICK_IAT
.extern MOUSE_CAPTURED
.extern FLY_MODE
.extern NOCLIP_STATE
.extern REPEAT_STATE
.extern RANGE_STATE
.extern REPLACE_STATE
.extern AUTOFILL_STATE
.extern CLEAR_STATE
.extern MACRO_STATE
.extern IGNORE_LIQUID_STATE

/*
 * Persistent textual HUD for the mod.  Eden's statusbar owns and caches the
 * Texture2D, while this payload owns only the widget and its libc++ string.
 * The string is rebuilt every frame, but statusbar::setStatus compares it to
 * the cached value and rerasterizes only after an actual state change.
 */
.global mod_hud
mod_hud:
    cmp byte ptr [rip + MOUSE_CAPTURED], 1
    jne hud_epilogue
    sub rsp, 0x20

    cmp byte ptr [rip + panel_initialized], 0
    jne panel_ready
    lea rcx, [rip + panel_widget]
    lea rdx, [rip + panel_rect]
    call STATUS_CTOR_RECT
    lea rcx, [rip + panel_widget]
    mov eax, 0x3d99999a                 /* 0.075 of panel height */
    movd xmm1, eax
    call STATUS_FONT_FIT
    /* Raw payload extraction does not carry PE base relocations.  Resolve the
       long-string data pointer at runtime so ASLR can relocate Eden safely. */
    lea rax, [rip + panel_buffer]
    mov qword ptr [rip + panel_string + 16], rax
    mov byte ptr [rip + panel_initialized], 1
panel_ready:
    lea r10, [rip + panel_buffer]

    lea rdx, [rip + str_flying]
    call append_string
    cmp byte ptr [rip + FLY_MODE], 0
    lea rdx, [rip + str_off]
    je 1f
    lea rdx, [rip + str_on]
1:  call append_string

    lea rdx, [rip + str_noclip]
    call append_string
    cmp byte ptr [rip + NOCLIP_STATE], 0
    lea rdx, [rip + str_off]
    je 2f
    lea rdx, [rip + str_on]
2:  call append_string

    lea rdx, [rip + str_autoplace]
    call append_string
    movzx eax, byte ptr [rip + REPEAT_STATE]
    test eax, eax
    jz auto_off
    cmp eax, 1
    je auto_5
    cmp eax, 2
    je auto_10
    cmp eax, 3
    je auto_20
    cmp eax, 4
    je auto_50
    lea rdx, [rip + str_max]
    jmp auto_done
auto_off: lea rdx, [rip + str_off]
    jmp auto_done
auto_5: lea rdx, [rip + str_5]
    jmp auto_done
auto_10: lea rdx, [rip + str_10]
    jmp auto_done
auto_20: lea rdx, [rip + str_20]
    jmp auto_done
auto_50: lea rdx, [rip + str_50]
auto_done: call append_string

    lea rdx, [rip + str_range]
    call append_string
    movzx eax, byte ptr [rip + RANGE_STATE]
    test eax, eax
    jz range_normal
    cmp eax, 1
    je range_20
    cmp eax, 2
    je range_50
    lea rdx, [rip + str_unlimited]
    jmp range_done
range_normal: lea rdx, [rip + str_normal]
    jmp range_done
range_20: lea rdx, [rip + str_20_blocks]
    jmp range_done
range_50: lea rdx, [rip + str_50_blocks]
range_done: call append_string

    lea rdx, [rip + str_replace]
    call append_string
    cmp byte ptr [rip + REPLACE_STATE], 0
    lea rdx, [rip + str_off]
    je 3f
    lea rdx, [rip + str_on]
3:  call append_string

    lea rdx, [rip + str_fill]
    call append_string
    movzx eax, byte ptr [rip + AUTOFILL_STATE]
    test eax, eax
    jz fill_off
    cmp eax, 1
    je fill_point_a
    cmp eax, 2
    je fill_point_b
    cmp eax, 3
    je fill_filled
    lea rdx, [rip + str_hollow_armed]
    jmp fill_done
fill_off: lea rdx, [rip + str_off]
    jmp fill_done
fill_point_a: lea rdx, [rip + str_point_a]
    jmp fill_done
fill_point_b: lea rdx, [rip + str_press_kl]
    jmp fill_done
fill_filled: lea rdx, [rip + str_filled_armed]
fill_done: call append_string

    lea rdx, [rip + str_clear]
    call append_string
    movzx eax, byte ptr [rip + CLEAR_STATE]
    test eax, eax
    jz clear_off
    cmp eax, 1
    je clear_point_a
    cmp eax, 2
    je clear_point_b
    lea rdx, [rip + str_armed]
    jmp clear_done
clear_off: lea rdx, [rip + str_off]
    jmp clear_done
clear_point_a: lea rdx, [rip + str_point_a]
    jmp clear_done
clear_point_b: lea rdx, [rip + str_press_j]
clear_done: call append_string

    lea rdx, [rip + str_ignore_liquid]
    call append_string
    cmp byte ptr [rip + IGNORE_LIQUID_STATE], 0
    lea rdx, [rip + str_off]
    je 4f
    lea rdx, [rip + str_on]
4:  call append_string

    lea rdx, [rip + str_macro]
    call append_string
    movzx eax, byte ptr [rip + MACRO_STATE]
    test eax, eax
    jz macro_off
    cmp eax, 1
    je macro_record
    cmp eax, 2
    je macro_record
    cmp eax, 3
    je macro_save
    cmp eax, 5
    je macro_apply
    lea rdx, [rip + str_active]
    jmp macro_done
macro_off: lea rdx, [rip + str_off_no_nl]
    jmp macro_done
macro_record:
    call qword ptr [rip + GETTICK_IAT]
    test eax, 0x100
    lea rdx, [rip + str_recording]
    jz macro_done
    lea rdx, [rip + str_recording_bright]
    jmp macro_done
macro_save: lea rdx, [rip + str_select_slot]
    jmp macro_done
macro_apply: lea rdx, [rip + str_apply]
macro_done: call append_string

    mov byte ptr [r10], 0
    lea rax, [rip + panel_buffer]
    sub r10, rax
    mov qword ptr [rip + panel_string + 8], r10

    call HUD_BEGIN
    lea rcx, [rip + panel_widget]
    lea rdx, [rip + panel_string]
    mov eax, 0x40000000                 /* 2.0 seconds */
    movd xmm2, eax
    xor r9d, r9d                        /* left alignment */
    call STATUS_SET
    lea rcx, [rip + panel_widget]
    call STATUS_RENDER
    call HUD_END
    add rsp, 0x20

hud_epilogue:
    add rsp, 0x1d0
    pop rbx
    pop rbp
    pop rdi
    pop rsi
    pop r12
    pop r14
    pop r15
    ret

/* rdx = zero-terminated source, r10 = destination/end; preserves r10. */
append_string:
    mov al, byte ptr [rdx]
    inc rdx
    test al, al
    jz 1f
    mov byte ptr [r10], al
    inc r10
    jmp append_string
1:  ret

.p2align 4
panel_initialized: .byte 0
.p2align 4
panel_rect: .float 4.0, 4.0, 260.0, 220.0
/* libc++ long string: odd capacity word, current size, data pointer. */
.p2align 3
panel_string: .quad 0x201, 0, 0
.p2align 4
panel_widget: .space 0x60, 0
panel_buffer: .space 0x200, 0

str_flying:          .asciz "Flying: "
str_noclip:          .asciz "\nNoclip: "
str_autoplace:       .asciz "\nAutoplace: "
str_range:           .asciz "\nRange: "
str_replace:         .asciz "\nReplace: "
str_fill:            .asciz "\nAuto-fill: "
str_clear:           .asciz "\nClear: "
str_ignore_liquid:   .asciz "\nIgnore Liquid: "
str_macro:           .asciz "\nMacro: "
str_on:              .asciz "ON"
str_off:             .asciz "OFF"
str_off_no_nl:       .asciz "OFF"
str_5:               .asciz "5/s"
str_10:              .asciz "10/s"
str_20:              .asciz "20/s"
str_50:              .asciz "50/s"
str_max:             .asciz "MAX"
str_normal:          .asciz "Normal"
str_20_blocks:       .asciz "20 blocks"
str_50_blocks:       .asciz "50 blocks"
str_unlimited:       .asciz "Unlimited"
str_point_a:         .asciz "Place point A"
str_press_kl:        .asciz "Press K/L"
str_filled_armed:    .asciz "Place point B (filled)"
str_hollow_armed:    .asciz "Place point B (hollow)"
str_press_j:         .asciz "Press J"
str_armed:           .asciz "Place point B"
str_recording:       .asciz "Recording..."
str_recording_bright:.asciz "RECORDING..."
str_select_slot:     .asciz "Select save slot"
str_apply:           .asciz "Apply preset"
str_active:          .asciz "Active"
