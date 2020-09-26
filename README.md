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

Note:
The level of optimization is a compromise between size and speed.
Faster or smaller implementations are possible.

### Sigma Designs Color 400 ###

The SCI0 driver COL400.DRV provides a 16-color mode with 320x200 pixels on
machines with a Color 400 graphics card by Sigma Designs.

It has the following features:

- Native 320x200 pixel 16-color mode
- Full mouse cursor support
- 8088 compatibility

Note:
This driver is derived from PCPLUS.DRV.

Assembling
----------

The source code can be assembled with `yasm` or `nasm`, e.g. via:

    yasm -o drv/PCPLUS.DRV src/pcplus.s

See Also
--------

A list of SCI-based games can be found on Wikipedia:
https://en.wikipedia.org/wiki/List_of_Sierra's_Creative_Interpreter_games

There is a closed-source driver for the VDU (Video Display Unit) of the
Amstrad PC1512.  It can be downloaded from
http://sierrahelp.com/Patches-Updates/MiscUpdates.html.

Furthermore, there is an unofficial closed-source driver for the 640x200
pixel 16-color mode of the Tandy Video II chip for SCI1/SCI1.1 256-color
games: http://www.symphoniae.com/Tandy/tandy640.zip

An unofficial closed-source SCI0 driver for the 640x400 pixel monochrome
mode of the Olivetti M24 (a.k.a. AT&T 6300), namely ATT320.DRV, does also
exist and is part of the following archive:
http://www.symphoniae.com/elw/sierrautil.zip

Ravi's Sound Drivers for General MIDI, as well as his driver framework to
base new audio drivers on, are open-source and available under LGPL:
http://www.sierrahelp.com/Utilities/SoundUtilities/RavisSoundDrivers.html
