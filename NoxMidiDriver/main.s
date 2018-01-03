;-----------------------------------------------------------------------------------------
;  main.s
;  NoxMidiDriver
;
;  Created by Eric Rangell on 1/2/18.
;  Copyright © 2018 Eric Rangell for Nox Archaist. All rights reserved.
;
;  Passport MIDI Interface Interrupt Playback Driver for Nox Archaist
;  This driver would be loaded only if the user selects Passport MIDI for music output.
;  When the Interrupt Activation routine is called, binary files in the current prefix directory
;  named S###.MCK will be played sequentially. (ex: S000.MCK, S001.MCK, S002.MCK)
;  The MCK file format will be defined by the sound engineering team, and translated to MIDI messages.
;  ProRWTS will double buffer the song data 512 bytes at a time to AUX memory.
;  Each song will loop until the Advance command or Silence command is sent by the main program.
;  The playlist will repeat (return to S000.MCK) when the next sequential song file cannot be found.
;
;  Build pipeline: https://github.com/jeremysrand/Apple2BuildPipeline
;  Changed disk template to Prodos 2.4.1
;-----------------------------------------------------------------------------------------
AUXBUF1     = $1000             ;beginning of 758 bytes of aux memory for double buffering disk blocks
AUXBUF2     = AUXBUF1 + $0100
AUXBUF3     = AUXBUF2 + $0100
;-----------------------------------------------------------------------------------------
MLI         = $BF00     ;prodos machine language interface
PRINTHEX    = $FDDA     ;print accumulator value in hex
;-----------------------------------------------------------------------------------------
main:
    brk                 ;do not BRUN - BLOAD, set slot, then call $6F02
;
midislot:   .byte $02   ;default passport midi slot = 2
;
    jsr cfgslot
    jsr allocint
;-----------------------------------------------------------------------------------------
midiinit:
    lda #$13    ; init and reset ACIA chip
mod1:
    sta $C0A8   ; control register for slot 2
    lda #$11
mod2:
    sta $C0A8
    rts
;-----------------------------------------------------------------------------------------
cfgslot:
    lda midislot
    and #$F8
    bne errbrk     ;slot >7 invalid
    lda midislot
    and #07
    beq errbrk      ;slot 0 invalid
    ora #$08        ;Derive MIDI slot address   C098 = slot1, C0A8 = slot2, C0F8 = slot7
    sec
    rol             ;This creates the 8 in the lower nibble
    asl
    asl
    asl
    sta mod1+1      ; self modify addresses in subroutines below
    sta mod2+1
    sta midiout+1
    clc
    adc #$01
    sta mod3+1
    sec
    sbc #09     ;derive address of control register (C090=slot1, C0A0=slot2, C0F0=slot7)
    sta mod4+1
    sta mod6+1
    sta mod8+1
    sta mod10+1
    sta mod11+1
    sta mod12+1
    sta imod2+1
    sta imod3+1
    sta imod4+1
    clc
    adc #$01    ;C091, C0A1, ... C0F1
    sta mod5+1
    sta imod1+1
    adc #$03    ;C094, C0A4, ... C0F4
    sta mod7+1
    adc #01     ;C095, C0A5, ... C0F5
    sta mod9+1
;
    rts
;
pallocint:  .byte $02   ;mli parm area for alloc interrupt
pintnum:    .byte $00   ;interrupt number (1-4) returned here
pintadrs:   .byte <inthand, >inthand
;
allocint:
    jsr MLI
    .byte $40
    .byte <pallocint
    .byte >pallocint
    bcs errbrk
    lda pintnum
    sta pdeintnum
    rts
;-----------------------------------------------------------------------------------------
; ERROR CODES:
; 00 = slot 0 invalid for midi slot
; > 07 = slot >7 invalid for midi slot
;-----------------------------------------------------------------------------------------
errbrk:
    jsr PRINTHEX
    brk
;-----------------------------------------------------------------------------------------
;
; above code uses exactly $80 bytes
;
;-------------------- configuration code above not needed after it runs ------------------
;
maincode:
    jmp midiout             ; call to send midi bytes
;
midibyte:   .byte $90       ;user pokes midi data byte to send out on the wire
temporeq:   .byte $00       ;to request tempo change, populate inttimer and set to non-zero
inttimer:   .byte $88,$08   ;timer interrupt value - set based on tempo of song
;-----------------------------------------------------------------------------------------
    jmp activateint         ; call when ready to play 512 byte buffer from aux queue
    jmp deactivateint       ; call to stop timer interrupts (pause, panic)
    jmp deallocint          ; call when exiting program
;-----------------------------------------------------------------------------------------
;
pdeallint:  .byte $01       ;MLI parameter list for Deallocate Interrupt
pdeintnum:  .byte $00
;
;-----------------------------------------------------------------------------------------
deallocint:
    jsr MLI
    .byte $41
    .byte <pdeallint, >pdeallint
    bcs errbrkmain
    rts
;-----------------------------------------------------------------------------------------
errbrkmain:
    jsr PRINTHEX
    brk
;-----------------------------------------------------------------------------------------
midiout:
    lda $C0A8   ; wait for transmit data register empty
    and #$02
    beq midiout
    lda midibyte
mod3:
    sta $C0A9   ; send user's byte out on the wire
    rts
;-----------------------------------------------------------------------------------------
deactivateint:
    php
    sei
    lda #$01
imod4:
    sta $C0A0   ;stop 6840 PTM timer in case it was running
    plp
    rts
;-----------------------------------------------------------------------------------------
activateint:
    lda #$01
mod4:
    sta $C0A0   ;stop 6840 PTM timer in case it was running
    php
    sei         ;disable interrupts while setting timer
    lda #$43    ;reset 6840 PTM
mod5:
    sta $C0A1
    jsr tempochg
    lda #$01    ;write control register 2
mod10:
    sta $C0A0
    lda #$C3    ;CONTINUOUS, IRQ AND TIMER OUTPUT ENABLED
mod11:
    sta $C0A0
    lda #$00    ;zero control register 1 to activate timer
mod12:
    sta $c0A0   ;timer interrupts are active now
    plp
    rts
;-----------------------------------------------------------------------------------------
tempochg:
    lda #$04    ; register #4
mod6:
    sta $C0A0
    lda inttimer+1  ;high byte of timer value
mod7:
    sta $C0A4
    lda #$05    ; register #5
mod8:
    sta $C0A0
    lda inttimer  ;low byte of timer value
mod9:
    sta $C0A5
    lda #$00
    sta temporeq
    rts
;-----------------------------------------------------------------------------------------
notours:
    sec     ;do not claim the interrupt - return to Prodos
    rts
;
inthand:
    cld         ;required for Prodos interrupt handler
imod1:
    lda $C0A1   ;check clock interrupt flag
    bpl notours
    lda #$01
imod2:
    sta $C0A0   ;stop clock during interrupt processing
;-----------------------------------------------------------------------------------------
    bit $c030   ;test interrupt processing
;-----------------------------------------------------------------------------------------
    lda temporeq
    beq strtclck
    jsr tempochg
strtclck:
    lda #$00    ;restart clock
imod3:
    sta $C0A0
    clc         ;claim the interrupt
    rts
;-----------------------------------------------------------------------------------------
mainend:
    brk
