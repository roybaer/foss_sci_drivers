FOSS SCI Drivers
================

This repository aims to provide a collection of newly written drivers for
Sierra's Creative Interpreter that was the basis of various Point-and-Click
adventures and other games by Sierra On-Line in the late 1980s and early
1990s.

These new drivers will be free and open-source software published under the
GNU LGPL license.

Video Drivers
-------------

This section lists all Video drivers that are part of this collection.

### Plantronics ColorPlus ###

The SCI0 driver PCPLUS.DRV provides a 16-color mode with 320x200 pixels on
machines with a Plantronics ColorPlus graphics card or compatible hardware.

It has the following features:

- Native 320x200 pixel 16-color mode
- Full mouse cursor support
- 8088 compatibility
- Small size

Note:
The driver has not been optimized for speed, yet.
A speed-up of factor two or three should be possible.

Assembling
----------

The source code can be assembled with `yasm` or `nasm`, e.g. via:

    yasm -o PCPLUS.DRV pcplus.s

See Also
--------

A list of SCI-based games can be found on Wikipedia:
https://en.wikipedia.org/wiki/List_of_Sierra's_Creative_Interpreter_games

There is a closed-source driver for the VDU (Video Display Unit) of the
Amstrad PC1512.  It can be downloaded from
http://sierrahelp.com/Patches-Updates/MiscUpdates.html.
