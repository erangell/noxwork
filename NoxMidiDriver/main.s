;-----------------------------------------------------------------------------------------
;  main.s
;  NoxMidiDriver
;
;  Created by Eric Rangell on 1/2/18.
;  Copyright © 2018 Eric Rangell for Nox Archaist. All rights reserved.
;
; TEST OF MOCKINGBOARD INTERRUPTS - ASSUMES MOCKINGBOARD IS IN SLOT 4
;
;  Build pipeline: https://github.com/jeremysrand/Apple2BuildPipeline
;  Changed disk template to Prodos 2.4.1
;-----------------------------------------------------------------------------------------
AUXBUF1     = $5600             ;beginning of 768 bytes of aux memory for double buffering disk blocks
AUXBUF2     = AUXBUF1 + $0100
AUXBUF3     = AUXBUF2 + $0100
;-----------------------------------------------------------------------------------------
; For testing with the game we won't have access to Prodos MLI - it will be replaced with ProRWTS
;MLI         = $BF00     ;prodos machine language interface
;
INTVECT     = $03FE     ;interrupt vector
;-----------------------------------------------------------------------------------------
main:   jmp mockinit
        jmp activateint         ; call when ready to play 512 byte buffer from aux queue
        jmp deactivateint       ; call to stop timer interrupts (pause, panic)
;
inttimer:   .byte $ff,$40   ;timer interrupt value - set based on tempo of song
temporeq:   .byte $00       ;to request tempo change, populate inttimer and set to non-zero
;
intdelay:   .byte $01       ;use to simulate the amount of work done in the interrupt handler
;
clickon:     .byte $01       ;turn on/turn off click on interrupt
;
intcount:   .byte $00,$00,$00,$00   ;number of interrupts processed
;
;-----------------------------------------------------------------------------------------
mockinit:
    lda #$FF    ; init and reset 6522 chip
    sta $C403
    lda #$07
    sta $C402
    rts
;-----------------------------------------------------------------------------------------
deactivateint:
    php
    sei
    lda #$7F    ;Interrupt Enable Register: clear any existing interrupt flags that may be enabled
    sta $C40E
    plp
    rts
;-----------------------------------------------------------------------------------------
activateint:
    php
    sei         ;disable interrupts while setting timer
    lda #<inthand
    sta INTVECT
    lda #>inthand
    sta INTVECT+1
    lda #$40    ;Auxiliary Control Register: Enable IRQ output on positive transition of input signal
    sta $C40B
    lda #$7F    ;Interrupt Enable Register: clear any existing interrupt flags that may be enabled
    sta $C40E
    lda #$C0    ;Enable IRQ for Timer 1:
    sta $C40D   ;Interrupt Flag Register
    sta $C40E   ;Interrupt Enable Register
    lda inttimer
    sta $C404   ;Timer 1 Counter LO (Also Timer 1 Latch LO)
    lda inttimer+1
    sta $C405   ;Timer 1 Counter HI
    plp
    cli         ;Ready to receive interrupts now
    rts
;
;-----------------------------------------------------------------------------------------
inthand:
    pha
    txa
    pha
    tya
    pha
    lda #$7F    ;Interrupt Enable Register: clear any existing interrupt flags that may be enabled
    sta $C40E
;-----------------------------------------------------------------------------------------
    lda clickon
    beq countints
    bit $C030
;
countints:
    clc
    lda intcount
    adc #$01
    sta intcount
    lda intcount+1
    adc #$00
    sta intcount+1
    lda intcount+2
    adc #$00
    sta intcount+2
    lda intcount+3
    adc #$00
    sta intcount+3
;-----------------------------------------------------------------------------------------
    ldx intdelay    ;simulate work done during the interrupt by setting intdelay
    beq delayend
outer:
    ldy #0
inner:
    dey
    bne inner
    dex
    bne outer
;-----------------------------------------------------------------------------------------
delayend:
    lda temporeq    ;process tempo change requests (timer interrupt values)
    beq strtclck
    jsr tempochg
strtclck:
    lda #$C0    ;Enable IRQ for Timer 1:
    sta $C40D   ;Interrupt Flag Register
    sta $C40E   ;Interrupt Enable register
    pla
    tay
    pla
    tax
    pla
    rti
;-----------------------------------------------------------------------------------------
tempochg:
    lda inttimer+1  ; high byte of timer value
    beq tmpodone    ; prevent high byte from being zero - you lose control of your apple
    lda inttimer
    sta $C404       ;Timer 1 Counter LO (Also Timer 1 Latch LO)
    lda inttimer+1
    sta $C405       ;Timer 1 Counter HI
tmpodone:
    lda #$00
    sta temporeq
    rts
;-----------------------------------------------------------------------------------------
mainend:
    brk
