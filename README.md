# noxwork

This is a test of a Passport MIDI interface interrupt-driven playback routine that will play a MCK file (format to be defined)
using double-buffering to 768 bytes of AUX memory.  The objective is to keep the main memory footprint as small as possible.
The idea is that when the user selects their sound output device, the appropriate driver will be loaded and initialized.
The loader/relocation/initialization code can then be discarded/overwritten leaving the driver and interrupt handler in main memory.

After booting the floppy disk image:

BLOAD NOXMIDI

CALL -151
6F81: 01        poke the slot number of your Passport MIDI card

6F82G           configures the code for the selected slot, allocates interrupt handler, initializes ACIA

at this point, memory from 6F80-6FFF is no longer used.

7000L

7003: midi byte

7000G - send midi byte

example:    7003:90 N 7000G N 7003:3C N 7000G N 7003:40 N 7000G

you should hear a middle C playing

7003:3C N 7000G N 7003:00 N 7000G

you should hear the middle C stop playing

Interrupt test:

7005 and 7006 - initial timer value (lo, hi)

7007G - activate interrupts

Interrupt handler is at 7074

currently clicks speaker on each interrupt (707F)

Caller may request a tempo change by storing new tempo in 7005,7006 and setting 7004 to a non-zero value.

This will also be used when a tempo change command is processed in the MIDI data.

Added Range checking on TEMPO value to prevent CPU overload if interrupts too fast:

High byte of Tempo value cannot equal zero.  If it is, tempo does not get changed, no warning/error.



Testing interrupt driven MIDI playback:

- First call a routine to load the song file (S000.MCK) to aux memory (The disk image does this)

- BLOAD NOXMIDI - follow instructions above to configure slot

- 7007G to activate interrupts


