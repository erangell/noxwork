# noxwork

This branch contains a Mockingboard Interrupt Test routine which assembles at $A900

It is intended for benchmarking to find out how music interrupts affect game performance.

The Mockingboard must be installed in Slot 4.

To load it from BASIC:

BLOAD NOXMIDI,A$6900

CALL-151

A900<6900.69FFM

A900G - Initializes Mockingboard 6522 chip for left speaker.

A903G - Activate Interrupts - you will hear the Apple speaker clicking on each interrupt.

A906G - Deactivate interrupts - to stop the timer interrupts.

The following parameters may be adjusted while interrupts are active:

A909.A911 - display values of all parameters

A909 =  inttimer:   .byte $ff,$40   ;timer interrupt value - set based on tempo of song

Do not set the INTTIMER value below $3000 - the interrupt routine seems to stop.

A90B = temporeq:   .byte $00       ;to request tempo change, populate inttimer and set to non-zero

Example: To request a longer timer value:

A909: 00 80 01

This sets the timer value to $8000 and requests the interrupt routine to change the tempo.

You should hear slower clicks

A90C = intdelay:   .byte $01       ;use to simulate the amount of work done in the interrupt handler

Use powers of 2 to see the effect of more work done in the interrupt handler, example:

Press Control G a few times to hear the beep

A90C:8

Press Control G a few times to hear how the beep is slower when more work is done on the interrupt

A90D = clickon:     .byte $01       ;turn on/turn off click on interrupt

Use this before playing the game to turn off the clicking after setting your test parameters.

A90E = intcount:   .byte $00,$00,$00,$00   ;number of interrupts processed

This 4 byte counter will increment once for each interrupt.

To verify that the interrupt routine is active, type A90E.A911 several times - you should see different values

