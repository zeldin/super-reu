super-reu -- an advanced FPGA-based ram expansion module for C64/C128
=====================================================================

### Features

The extensions that super-reu offer over a regular 1700/1750 REU are:
 * Larger storage capacity (up to 16 mibioctets)
 * Paced DMA transfers
 * Multiple DMA channels
 * External data generators/consumers


See also:
- [Register manual](docs/registers.md)
- [m64conv manual](docs/m64conv.md)
- [m64 format specification](docs/m64.md)
- [Porting guide](docs/porting_guide.md)



Movie player demonstrator
-------------------------

An example application demonstrating the capabilities of the super-reu
in the form of a full screen movie player is included in the repository.
The application can stream full screen bitmapped video (320x200 in hires
or 160x200 in multicolor) at 50 fps and sampled sound at 16 kHz from an
sdcard.


Chameleon v2 top level design
-----------------------------

While the DMA engine and MMC64 modules are not tied to any specific FPGA
solution, this repository contains a top level design integrating the
modules onto the Chameleon v2 hardware.  Although the super-reu does not
depend on any address decoder PLA tricks, and thus should work fine
in a C128, note that the default core of the Chameleon v2 does use
such tricks and thus it is not safe to use it in a C128.

The Chameleon v2 top level design does not support the VGA port or 3.5mm
stereo-audio plug on the Chameleon.  Please use the DIN video connector
or RF output on the C64 for audio and video connection.


Prerequisites
-------------

To build the movie player demonstrator for Chameleon v2, the
following is needed:

- [Quartus 18.0 Lite Edition](https://www.intel.com/content/www/us/en/programmable/downloads/download-center.html)
- [cc65 development package](https://cc65.github.io/)


Building and installing
-----------------------

To build the movie player demonstrator and m64conv tool, run

```
make QUARTUS_SH=/path/to/quartus_sh
```

specifying the correct path to `quartus_sh` in your Quartus installation
(default is `/opt/intelFPGA_lite/18.0/quartus/bin/quartus_sh`).
`ca65` and `ld65` need to be present in the executable path.

If everything goes well, the core and ROM can be flashed on Chameleon v2
using

```
make SLOT=n flash
```

If no `SLOT` is specified, slot 2 will be used.  `chacocmd` must be
present in the executable path.

