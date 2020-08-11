; PCPLUS.DRV - An SCI video driver for the Plantronics ColorPlus.
; Copyright (C) 2020  Benedikt Freisen
;
; This library is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; This library is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

; SCI drivers use a single code/data segment starting at offset 0
[bits 16]
[org 0]

;-------------- entry --------------------------------------------------
; This is the driver entry point that delegates the incoming far-call
; to the dispatch routine via jmp.
;
; Parameters:   bp      index into the call table (always even)
;               ?       depends on the requested function
; Returns:      ?       depends on the requested function
;-----------------------------------------------------------------------
entry:  jmp     dispatch

; magic numbers followed by two pascal strings
signature       db      00h, 21h, 43h, 65h, 87h, 00h
driver_name     db      6, "pcplus"
description     db      33, "Plantronics ColorPlus - 16 Colors"

; call-table for the dispatcher
call_tab        dw      get_driver_id           ; bp = 0
                dw      init_video_mode         ; bp = 2
                dw      restore_mode            ; bp = 4
                dw      update_rect             ; bp = 6
                dw      show_cursor             ; bp = 8
                dw      hide_cursor             ; bp = 10
                dw      move_cursor             ; bp = 12
                dw      load_cursor             ; bp = 14
                dw      hw_scroll_dummy         ; bp = 16

;-------------- cursor_struct ------------------------------------------
; Structure that stores the current mouse cursor.
; Cursor format expected by load_cursor:
;
; Two unused words followed by
; sixteen 16-bit little-endian words AND-matrix followed by
; sixteen 16-bit little-endian words OR-matrix.
; The most significant bit is the left-most pixel.
; Everything else is not part of the API and for internal use, only.
;-----------------------------------------------------------------------
cursor_struct:
; reserved fields not used by the driver
cursor_dnu1     dw      0
cursor_dnu2     dw      0
; and-mask
cursor_and      times   16 dw 0
; or-mask
cursor_or       times   16 dw 0

; saved background pixels overwritten by the cursor
cursor_bg       times   160 db 0
cursor_ofs      dw      0
cursor_hbytes   db      0
cursor_rows     db      0

cursor_counter  dw      0
cursor_x        dw      0
cursor_y        dw      0
cursor_new_x    dw      0
cursor_new_y    dw      0

cursor_lock     dw      0

;-------------- dispatch -----------------------------------------------
; This is the dispatch routine that delegates the incoming far-call to
; to the requested function via call.
;
; Parameters:   bp      index into the call table (always even)
;               ?       depends on the requested function
; Returns:      ?       depends on the requested function
;-----------------------------------------------------------------------
dispatch:
        ; save segments & set ds to cs
        push    es
        push    ds
        push    cs
        pop     ds

        ; dispatch the call while preserving ax, bx, cx, dx and si
        call    [cs:call_tab+bp]

        ; restore segments
        pop     ds
        pop     es

        retf

;-------------- get_driver_id ------------------------------------------
; Returns a magic number that is usually identical to the number of
; colors.
;
; Parameters:   --
; Returns:      ax      magic number
;-----------------------------------------------------------------------
get_driver_id:
        mov     ax,16
        ret

;-------------- init_video_mode-----------------------------------------
; Initializes the video mode provided by this driver and returns the
; previous video mode, i.e. the BIOS mode number.
;
; Parameters:   --
; Returns:      ax      BIOS mode number of the previous mode
;-----------------------------------------------------------------------
init_video_mode:
        ; get current video mode
        mov     ah,0fh
        int     10h

        ; save mode number
        push    ax

        ; set video mode 5 (320x200 - 4 colors)
        mov     ax,5
        int     10h

        ; enable ColorPlus extensions for 16 colors
        mov     dx,3ddh
        mov     al,10h
        out     dx,al

        ; clear blue/intensity page
        mov     ax,0b800h
        mov     es,ax
        mov     di,16384
        mov     cx,8192
        xor     ax,ax
        rep     stosw

        ; restore mode number
        pop     ax
        xor     ah,ah

        ret

;-------------- restore_mode -------------------------------------------
; Restores the provided BIOS video mode.
;
; Parameters:   ax      BIOS mode number
; Returns:      --
;-----------------------------------------------------------------------
restore_mode:
        ; save parameter
        push    ax

        ; disable ColorPlus extensions
        mov     dx,3ddh
        mov     al,0
        out     dx,al

        ; restore parameter
        pop     ax

        ; set video mode
        xor     ah,ah
        int     10h

        ret

;-------------- update_rect --------------------------------------------
; Transfer the specified rectangle from the engine's internal linear
; frame buffer of IRGB pixels to the screen.
;
; Parameters:   ax      Y-coordinate of the top-left corner
;               bx      X-coordinate of the top-left corner
;               cx      Y-coordinate of the bottom-right corner
;               dx      X-coordinate of the bottom-right corner
;               si      frame buffer segment (offset = 0)
; Returns:      --
; Notes:        The implementation may expand the rectangle as needed
;               and may assume that all parameters are valid.
;               It has to hide the mouse cursor if it intersects with
;               the rectangle and has to lock it, otherwise.
;-----------------------------------------------------------------------
update_rect:

        shr     bx,1
        shr     bx,1
        add     dx,3
        shr     dx,1
        shr     dx,1
        ; load and convert cursor x
        mov     bp,[cursor_x]
        shr     bp,1
        shr     bp,1
        ; compare to right edge
        cmp     dx,bp
        jl      .just_lock
        ; compare to left edge (a bit generously)
        add     bp,5
        sub     bp,bx
        jl      .just_lock
        ; load cursor y
        mov     bp,[cursor_y]
        ; compare to bottom edge
        cmp     cx,bp
        jl      .just_lock
        ; compare to top edge
        add     bp,16
        sub     bp,ax
        jl      .just_lock

        ; locking the cursor is not enough -> hide it
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        call    hide_cursor
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        clc
        jmp     .just_hide

.just_lock:
        call    lock_cursor
        stc
.just_hide:
        pushf

        mov     bp,0b800h
        mov     es,bp
        push    ds
        mov     ds,si

        ; calculate source address
        sub     cx,ax
        sub     dx,bx
        mov     bp,ax
        mov     ah,160
        mul     ah
        add     ax,bx
        add     ax,bx
        mov     si,ax
        ; calculate destination address
        mov     ax,bp
        xor     di,di
        shr     ax,1
        rcr     di,1
        shr     di,1
        shr     di,1
        mov     ah,80
        mul     ah
        add     di,ax
        add     di,bx

        mov     bp,dx
        mov     dx,cx
.y_loop:
        mov     cx,bp
        push    si
        push    di
.x_loop:
        ; load a word from the engine's frame buffer
        lodsw
        ; rearrange the IRGBIRGBIRGBIRGB word to RGRGRGRG and BIBIBIBI bytes
        xchg    al,ah
        mov     bx,ax
        and     bx,7777h
        and     ax,8888h
        shl     bx,1
        shr     ax,1
        shr     ax,1
        shr     ax,1
        or      ax,bx
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bl,1
        shl     ax,1
        rcl     bh,1
        shl     ax,1
        rcl     bh,1
        ; write to the screen's red/green and blue/intensity page
        mov     [es:di],bl
        mov     [es:di+16384],bh
        inc     di
        loop    .x_loop

        pop     di
        pop     si
        add     si,160
        ; handle scanline interleaving
        add     di,8192
        cmp     di,16384
        jb      .odd
        sub     di,16304
.odd:

        dec     dx
        jns     .y_loop

        pop     ds
        ; unlock/show cursor
        popf
        jnc     .show
        call    unlock_cursor
        ret
.show:  call    show_cursor

        ret

;-------------- show_cursor --------------------------------------------
; Increment the mouse cursor visibility counter and draw the cursor if
; the counter reaches one.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
show_cursor:
        ; hard synchronization
        pushf
        cli

        or      word [cursor_counter],0
        jne     .skip
        call    draw_cursor

.skip:  inc     word [cursor_counter]
        popf

        ret

;-------------- hide_cursor --------------------------------------------
; Decrement the mouse cursor visibility counter and restore the
; background if the counter reaches zero.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
hide_cursor:
        ; hard synchronization
        pushf
        cli

        dec     word [cursor_counter]
        jnz     .skip
        call    restore_background

.skip:  popf

        ret

;-------------- move_cursor --------------------------------------------
; Moves the mouse cursor, unless it is locked, in which case it will be
; moved when unlocked.
;
; Parameters:   ax      new X-coordinate
;               bx      new Y-coordinate
; Returns:      --
; Note:         This function has to preserve all registers not
;               otherwise preserved.
;-----------------------------------------------------------------------
move_cursor:
        ; save everything
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        pushf

        ; move the cursor, unless it is locked
        cli
        push    bx
        push    ax
        cmp     word [cursor_lock],0
        jnz     .skip
        call    hide_cursor
        pop     word [cursor_x]
        pop     word [cursor_y]
        call    show_cursor
        jmp     .end
.skip:
        ; if locked, save coordinates for later
        pop     word [cursor_new_x]
        pop     word [cursor_new_y]
.end:

        ; restore everything
        popf
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax

        ret

;-------------- load_cursor --------------------------------------------
; Loads a new graphical mouse cursor.
;
; Parameters:   ax      segment of the new cursor
;               bx      offset of the new cursor
; Returns:      ax      the current cursor visibility
;-----------------------------------------------------------------------
load_cursor:
        ; copy the new cursor to the internal cursor data structure
        push    ds
        mov     ds,ax
        mov     si,bx
        mov     di,cursor_struct
        mov     ax,cs
        mov     es,ax
        mov     cx,34
        rep     movsw
        pop     ds

        ; make sure that the on-screen cursor changes, as well
        call    hide_cursor
        call    show_cursor

        ; return the cursor visibility counter
        mov     ax,[cursor_counter]

        ret

;-------------- hw_scroll_dummy ----------------------------------------
; Dummy for HW scolling functionality provided by some drivers.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
hw_scroll_dummy:
        ; this dummy implementation returns right away
        ret

;***********************************************************************
; The helper functions below are not part of the API.
;***********************************************************************

;-------------- draw_cursor --------------------------------------------
; Draws the mouse cursor after saving the screen content at its
; position to a buffer.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
draw_cursor:
        ; calculate on-screen cursor dimensions
        mov     ax,200
        sub     ax,[cursor_y]
        cmp     ax,16
        jl      .nocrop_v
        mov     ax,16
.nocrop_v:
        mov     [cursor_rows],ax

        mov     ax,[cursor_x]
        shr     ax,1
        shr     ax,1
        mov     bx,ax
        sub     ax,80
        neg     ax
        cmp     ax,5
        jl      .nocrop_h
        mov     ax,5
.nocrop_h:
        mov     [cursor_hbytes],al

        ; calculate cursor offset in video ram
        mov     ax,[cursor_y]
        xor     si,si
        shr     ax,1
        rcr     si,1
        shr     si,1
        shr     si,1
        mov     ah,80
        mul     ah
        add     si,ax
        add     si,bx
        mov     [cursor_ofs],si

        ; save screen content that will be overwritten
        push    ds
        mov     ax,ds
        mov     es,ax
        mov     ax,0b800h
        mov     ds,ax
        mov     di,cursor_bg

        ; red/green page
        xor     bx,bx
        mov     bl,[cs:cursor_hbytes]
        mov     dl,[cs:cursor_rows]
        xor     cx,cx
.save_y_loop_rg:
        mov     cl,bl
        rep     movsb
        sub     si,bx
        ; handle scanline interleaving
        add     si,8192
        cmp     si,16384
        jb      .save_odd_rg
        sub     si,16304
.save_odd_rg:
        dec     dl
        jnz     .save_y_loop_rg

        ; blue/intensity page
        mov     si,[cs:cursor_ofs]
        add     si,16384
        xor     bx,bx
        mov     bl,[cs:cursor_hbytes]
        mov     dl,[cs:cursor_rows]
        xor     cx,cx
.save_y_loop_bi:
        mov     cl,bl
        rep     movsb
        sub     si,bx
        ; handle scanline interleaving
        add     si,8192
        cmp     si,32768
        jb      .save_odd_bi
        sub     si,16304
.save_odd_bi:
        dec     dl
        jnz     .save_y_loop_bi

        pop     ds

        ; draw cursor
        mov     ax,0b800h
        mov     es,ax
        mov     di,[cursor_ofs]
        mov     si,cursor_and
        mov     dh,[cursor_rows]

.draw_y_loop:
        ; load AND-mask for this line
        lodsw
        ; make it easier to handle by inverting it
        not     ax
        ; calculate X-offset and mask
        mov     cx,[cursor_x]
        and     cx,3
        ; use ch to mask-in/out individual pixels from left to right
        mov     ch,0c0h
        shl     cl,1
        shr     ch,cl
        ; count horizontal bytes in bl
        xor     bx,bx
        ; save X-offset and mask for later
        push    cx

        ; apply the AND-mask to the current line
.draw_x_loop_and:
        shl     ax,1
        jnc     .skip_and
        not     ch
        ; red/green page
        mov     dl,[es:di+bx]
        and     dl,ch
        mov     [es:di+bx],dl
        ; blue/intensity page
        mov     dl,[es:di+bx+16384]
        and     dl,ch
        mov     [es:di+bx+16384],dl
        not     ch
.skip_and:
        shr     ch,1
        shr     ch,1
        jnc     .skip_reset_mask_and
        mov     ch,0c0h
        inc     bx
.skip_reset_mask_and:
        cmp     bl,[cursor_hbytes]
        jne     .draw_x_loop_and

        ; load OR-mask for this line; restore X-offset/mask in cx
        mov     ax,[si+30]
        xor     bx,bx
        pop     cx

        ; apply the OR-mask to the current line
.draw_x_loop_or:
        shl     ax,1
        jnc     .skip_or
        ; red/green page
        mov     dl,[es:di+bx]
        or      dl,ch
        mov     [es:di+bx],dl
        ; blue/intensity page
        mov     dl,[es:di+bx+16384]
        or      dl,ch
        mov     [es:di+bx+16384],dl
.skip_or:
        shr     ch,1
        shr     ch,1
        jnc     .skip_reset_mask_or
        mov     ch,0c0h
        inc     bx
.skip_reset_mask_or:
        cmp     bl,[cursor_hbytes]
        jne     .draw_x_loop_or

        ; handle scanline interleaving
        add     di,8192
        cmp     di,16384
        jb      .draw_odd
        sub     di,16304
.draw_odd:
        dec     dh
        jnz     .draw_y_loop

        ret

;-------------- restore_background -------------------------------------
; Restore the screen content previously saved and overwritten by
; draw_cursor.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
restore_background:
        mov     ax,0b800h
        mov     es,ax

        ; red/green page
        mov     di,[cursor_ofs]

        mov     si,cursor_bg
        xor     bx,bx
        mov     bl,[cursor_hbytes]
        mov     dl,[cursor_rows]
        xor     cx,cx
.y_loop_rg:
        mov     cl,bl
        rep     movsb
        sub     di,bx
        ; handle scanline interleaving
        add     di,8192
        cmp     di,16384
        jb      .odd_rg
        sub     di,16304
.odd_rg:
        dec     dl
        jnz     .y_loop_rg

        ; blue/intensity page
        mov     di,[cursor_ofs]
        add     di,16384

        mov     si,cursor_bg
        xor     bx,bx
        mov     bl,[cursor_hbytes]
        mov     dl,[cursor_rows]
        xor     cx,cx
.y_loop_bi:
        mov     cl,bl
        rep     movsb
        sub     di,bx
        ; handle scanline interleaving
        add     di,8192
        cmp     di,32768
        jb      .odd_bi
        sub     di,16304
.odd_bi:
        dec     dl
        jnz     .y_loop_bi

        ret

;-------------- lock_cursor --------------------------------------------
; Locks the cursor in its current position without changing its
; visibility.
;
; Parameters:   --
; Returns:      --
; Notes:        Has to preserve all registers
;-----------------------------------------------------------------------
lock_cursor:
        ; hard synchronization
        pushf
        cli

        inc     word [cursor_lock]
        push    ax
        ; initialize new cursor position with current cursor position
        mov     ax,[cursor_x]
        mov     [cursor_new_x],ax
        mov     ax,[cursor_y]
        mov     [cursor_new_y],ax
        pop     ax

        popf

        ret

;-------------- unlock_cursor ------------------------------------------
; Unlocks the cursor and updates its position, if it has changed since
; the cursor has been locked.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
unlock_cursor:
        ; hard synchronization
        pushf
        cli

        dec     word [cursor_lock]
        jnz     .end
        ; check if cursor should have moved and move for real
        mov     ax,[cursor_new_x]
        mov     bx,[cursor_new_y]
        cmp     ax,[cursor_x]
        jne     .move
        cmp     bx,[cursor_y]
        jne     .move
        jmp     .end
.move:  call    move_cursor

.end:   popf

        ret
