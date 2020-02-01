super-reu register descriptions
===============================

DMA channels (REC)
------------------

The registers for the DMA channels appear at base address `DF00` in the
C64 memory space.  Each channel occupies a 16 byte address space, with
channel 0 at `DF00` to `DF0F`, channel 1 at `DF10` to `DF1F`, and so on.

### 1700/1750 REC compatible registers

|Address | Bits | Function                                  | |
|--------|------|-------------------------------------------|-|
|$DFx0   | 7-0  | Status Register - Read Only
|        |      | 7 - Interrupt Pending; | 1 = Interrupt waiting to be serviced
|        |      | 6 - End of Block;      | 1 = Transfer complete
|        |      | 5 - Fault;             | 1 = Block verify error
|        |      | 4 - Size;              | 0 = Total expansion = 128K or 256K
|        |      |                        | 1 = Total expansion >= 512K
|        |      | 3-0 Version;           | 8 = First release of super-reu
|        |      | Note: Bits 7-5 are cleared when this register is read
|        |      |
|$DFx1   | 7-0  | Command Register - Read/Write
|        |      | 7 - Execute;           | 1 = Transfer per current config.
|        |      | 6 - Reserved;
|        |      | 5 - Load;              | 1 = Enable AUTOLOAD option
|        |      | 4 - FF00               | 1 = Disable FF00 decode
|        |      | 3 - Reserved;
|        |      | 2 - Reserved;
|        |      | 1,0 - Transfer type;   | 00 = transfer C64 -> RAM module
|        |      |                        | 01 = transfer C64 <- RAM module
|        |      |                        | 10 = swap C64 <-> RAM module
|        |      |                        | 11 = verify C64 - RAM module
|        |      |
|$DFx2   | 7-0  | C64 Base Address, LSB - Read/Write
|        |      |  Lower 8 bits of base address, C64
|        |      |
|$DFx3   | 7-0  | C64 Base Address, MSB - Read/Write
|        |      |  Upper 8 bits of base address, C64
|        |      |
|$DFx4   | 7-0  | Expansion RAM address, LSB - Read/Write
|        |      |  Lower 8 bits of base address, expansion RAM
|        |      |
|$DFx5   | 7-0  | Expansion RAM address, MSB - Read/Write
|        |      |  Upper 8 bits of base address, expansion RAM
|        |      |
|$DFx6   | n-0  | Expansion RAM bank - Read/Write
|        |      |  Expansion RAM bank pointer.
|        |      |  If total expansion size is 512K or less, n=2
|        |      |  Otherwise n=log2(total expansion size)-17
|        |      |
|$DFx7   | 7-0  | Transfer length, LSB - Read/Write
|        |      |  Lower 8 bits of the byte counter
|        |      |
|$DFx8   | 7-0  | Transfer length, MSB - Read/Write
|        |      |  Upper 8 bits of the byte counter
|        |      |
|$DFx9   | 7-5  | Interrupt mask register - Read/Write
|        |      | 7 - Interrupt enable   | 1 = Interrupts enabled
|        |      | 6 - End of Block mask  | 1 = Interrupt on end of block
|        |      | 5 - Verify error       | 1 = Interrupt on verify error
|        |      |
|$DFxA   | 7-6  | Address control register - Read/Write
|        |      | 0,0 = Increment both addresses (default)
|        |      | 0,1 = Fix expansion address
|        |      | 1,0 = Fix C64 address
|        |      | 1,1 = Fix both addresses


#### Size considerations

When the total expansion size is 512K or less, the Expansion RAM bank
register works like on the 1700 and 1750 - the 3 least significant bits
are writable regardless of expansion size, and the 5 most significant
bits can not be written and always read as `1`.  The size bit of the
Status Register will only indicate whether the full 512K are available or
not, it is not possible to distinguish between the 128K and 256K settings.

When the total expansion size is larger than 512K, additional bits of
the Expansion RAM bank register will become writable as needed, but they
are set to `1` on reset.  The size bit of the Status Register is set to `1`.
In order to probe the actual size of the memory expansion when the size bit
is `1`, write `$00` to the Expansion RAM bank register and read back the
result.  Any non-usable address bits will read back as `1`:s, so inverting
the bits of the value read back gives the highest usable bank number (i.e.
the total number of banks minus one).


### super-reu specific registers

|Address | Bits | Function                                  | |
|--------|------|-------------------------------------------|-|
|$DFxB   | 7-6  | Channel pacing control - Read/Write
|        |      | 7 - Enable rate mode   | 1 = Transfers have a constant rate
|        |      | 6 - Enable delay mode  | 1 = Transfers have a constant delay
|        |      |
|$DFxC   | 7-0  | Delay/Rate length, LSB - Read/Write
|        |      |  Lower 8 bits of the number of PHI2 cycles of delay or rate
|        |      |
|$DFxD   | 7-0  | Delay/Rate length, MSB - Read/Write
|        |      |  Upper 8 bits of the number of PHI2 cycles of delay or rate
|        |      |
|$DFxE   | 7-0  | Rate length, fraction - Read/Write
|        |      |  Number of 1/256:th PHI2 cycles to add to the rate
|        |      |
|$DFxF   | 7-0  | Reserved - Read Only
|        |      |  Reserved for future use, currently reads as all `1`:s

When either bit of the Channel pacing control register is set, pacing
is enabled for that channel.  Rate mode means that transfers will be
triggered by a clock with a specified period.  Delay mode means that
transfers will be triggered by a timer counting a specified delay after
the previous transfer.  The delay or rate is specified as a number of
cycles, with 16 integer bits and 8 fractional bits.  Since DMA transfers
only occur on whole cycles, the fractional part is only meaningful in
rate mode, where the fraction accumulates over multiple transfers.
Setting the fractional value to 0 (the default) disables the fraction
feature.

The difference between delay and rate mode is due to the fact that the
bus is not always available for DMA transfers (or to a specific DMA
channel in the case that multiple DMA channels are in use), which
means that there will be an undeterministic delay between the
condition for the next transfer being fulfilled and the transfer
actually happening.  In delay mode, the time to the next transfer is
counted from the point where the transfer actually happens, meaning
that the undeterministic delay of one transfer will also affect the
following transfers.  In rate mode, the time is counted from the
previous timer expiry, meaning that the time a request is triggered is
not affected by the time it took to execute the previous transfer.
On the other hand it is possible for the timer to expire again before the
previous transfer has completed, in which case no transfer will be
executed for that timer expiry.  To guarantee a certain number of
transfers per time unit, it is therefore necessary to use rate mode
with a length large enough that each transfer is able to complete
within the allotted time.


#### Paced DMA considerations

When all active DMA channels use the pacing control function, it means
that the DMA engine will relinquish control of the bus (deassert the
DMA signal) and reclaim it asynchronously at a later time.  Due to a
design bug in the C64 expansion port (see
[the paper by Gideon Zweijtzer](https://codebase64.org/lib/exe/fetch.php?media=base:safely_freezing_the_c64.pdf)
for details), this can not be done safely at any time.  In order to
guarantee correct operation of the 6510 CPU, a suspended DMA operation
will be resumed at one of the following points:

* When VIC has asserted and released BA, which is to say after it has
  read character pointers (a "bad line") or sprite data.  Since VIC has
  the means to halt the 6510 safely, it is always possible to extend
  the halt state for DMA purposes at the end of VIC:s access.  Since
  VIC can not be halted, it is not possible to perform any DMA
  operation _during_ a bad line however.

* After 6510 finishes an instruction performing a write to memory.
  The switch from write cycles to read cycles (when fetching the next
  instruction) serves as a trigger to indicate a point where DMA can
  safely be restarted.

Thus, if you are not content with paced DMA resuming at the next bad line
(or sprite line), you should make sure to include some regular write
operations in your 6510 code.  This means any instruction of: `BRK`,
`DEC`, `INC`, `JSR`, `PHA`, `PHP`, `STA`, `STX`, `STY`, or one of
`ASL`, `LSR`, `ROL` or `ROR` with a memory operand.

When non-paced DMA is active in another channel, the 6510 is
constantly halted and paced DMA will be able to resume immediately
(except when locked out from the bus by VIC).


SDcard access (MMC64)
---------------------

The registers for SDcard access are mostly compatible with MMC64, but
the base address is moved to $DE10 to make room for the extra DMA channels.

### MMC64 compatible registers

|Address | Bits | Function                                  | |
|--------|------|-------------------------------------------|-|
|$DE10   | 7-0  | SPI transfer register.
|        |      |  Write in this register sends byte to SPI bus
|        |      |  Read is last retrieved byte
|        |      |
|$DE11   | 7-0  | Control register - Read/Write
|        |      | 7 - MMC64 active       | 1 = Register $DE10 is disabled
|        |      | 6 - SPI trigger mode   | 0 = SPI transfer on write to $DE10
|        |      |                        | 1 = SPI transfer on read from $DE10
|        |      | 5 - External ROM       | 1 = Disable external ROM
|        |      | 4 - Flash mode         | Not implemented, must be set to 0
|        |      | 3 - Clock port address | Not implemented, must be set to 0
|        |      | 2 - Clock speed        | 0 = 250 kHz SPI clock
|        |      |                        | 1 = 8 MHz SPI clock
|        |      | 1 - MMC card select    | 0 = Card selected
|        |      |                        | 1 = Card not selected
|        |      | 0 - MMC64 Bios         | Not implemented, must be set to 1
|        |      |
|$DE12   | 5-0  | Status register - Read Only
|        |      | 5 - Flash jumper       | Not implemented, always reads as 0
|        |      | 4 - MMC Write Protect  | 0 = Card can be written
|        |      |                        | 1 = Card is write protected
|        |      | 3 - MMC Card Detect    | 0 = Card inserted
|        |      |                        | 1 = No card present, slot empty
|        |      | 2 - External EXROM line
|        |      | 1 - External GAME line
|        |      | 0 - Busy               | 0 = SPI bus ready
|        |      |                        | 1 = SPI bus busy



### super-reu specific registers

|Address | Bits | Function                                  | |
|--------|------|-------------------------------------------|-|
|$DE13   | 1-0  | Block transfer register - Read/Write
|        |      | 1 - Block Fail          | 0 = Last transfer completed ok
|        |      |                         | 1 = Last transfer failed
|        |      |                         | This bit is read only
|        |      | 0 - Read Blocks         | 1 = Block transfer active
|        |      |
|$DE14   | 7-0  | Block Count - Read/Write
|        |      |  Number of 512-byte blocks to transfer.
|        |      |  Set to 0 to transfer 256 blocks
|        |      |
|$DE15   | 7-0  | Expansion RAM address, LSB - Read/Write
|        |      |  Lower 8 bits of base address, expansion RAM
|        |      |
|$DE16   | 7-0  | Expansion RAM address, MSB - Read/Write
|        |      |  Upper 8 bits of base address, expansion RAM
|        |      |
|$DE17   | 7-0  | Expansion RAM bank - Read/Write
|        |      |  Expansion RAM bank pointer.


Before requesting a block transfer, software must manually send CMD18
and wait for R1.  It can then write the number of 512-byte blocks to
transfer into $DE14 and set the Read Blocks bit of $DE13.  The hardware
will now automatically wait for each block and transfer it to the
expansion RAM.

It is not possible to use the Busy bit of $DE12 to check if a block
transfer is still active.  The Read Blocks bit of $DE13 must be
checked instead.  Once a block transfer stops, the Read Blocks bit will
automatically be reset to 0.

Writing a zero to the Read Blocks bit during a transfer will make it
immediately finish with an error.  It is the responsibility of the software
to restore the card to a known state afterwards.

The expansion RAM address will automatically increment as bytes are
transferred.  At the end of a successful transfer, Block Count will be 0.
