
	.macpack cbm

	.import screen, clear_screen, setrow, nextrow, dumpreg
	.importzp vreg

	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum

	.import initstream, getstreamdata
	

frame_header = $0bf0

	.zeropage

vswap:	.res 1
aswap:	.res 1
		
	.code
	
	.word start
	.word start

	.byte "CBM80"

start:
	sei
@wait1:	
	lda $d011
	bpl @wait1
@wait2:	
	lda $d011
	bmi @wait2

	ldx #$ff
	txs

	ldx #17
init_vic_loop:
	lda vicinit-1,x
	sta $d010,x
	dex
	bne init_vic_loop
	stx $dc03
	dex
	stx $dc02
	lda #3
	sta $dd00
	lda #$3f
	sta $dd02
	lda #$7f
	sta $dc0d
	sta $dd0d
	lda $dc0d
	lda $dd0d
	lda #<irq_handler
	sta $314
	lda #>irq_handler
	sta $315
	cli

	jsr clear_screen

	ldx #message_length-1
print_message:	
	lda message,x
	sta screen,x
	dex
	bpl print_message

	lda #$1b
	sta $d011


	;; Do some register I/O


	lda #$91
	sta $dea2

	lda #$ff
	ldx #16
@init_row:
	sta screen+40,x
	dex
	bpl @init_row

	lda #<(screen+7)
	sta $df02
	lda #>(screen+8)
	sta $df03

	lda #$40
	sta $df09
	
	lda #0
	sta $df04
	sta $df05
	sta $df06

	lda #7
	sta $df07
	lda #0
	sta $df08

	lda #$b0
	sta $df01

	jsr waitdma

	lda #<(screen+42)
	sta $df02
	lda #>(screen+42)
	sta $df03
	lda #$91
	sta $df01

	jsr waitdma

	lda #0
	sta $df04
	sta $df05
	sta $df06
	lda #<$8004
	sta $df02
	lda #>$8004
	sta $df03
	lda #5
	sta $df07
	lda #0
	sta $df08
	lda #$90
	sta $df01

	jsr waitdma

	lda #<$de00
	sta $df02
	lda #>$de00
	sta $df03
	lda #2
	sta $df07
	lda #0
	sta $df08
	lda #$90
	sta $df01

	jsr waitdma

	lda #0
	sta $df04
	sta $df05
	sta $df06
	lda #<(screen+60)
	sta $df02
	lda #>(screen+60)
	sta $df03
	lda #7
	sta $df07
	lda #0
	sta $df08
	lda #$b1
	sta $df01

	jsr waitdma

	lda #<$de02
	sta $df02
	lda #>$de02
	sta $df03
	lda #1
	sta $df07
	lda #0
	sta $df08
	lda #$91
	sta $df01

	jsr waitdma


	lda #3
	jsr setrow

	ldx #0
@dumpde00loop:
	jsr dumpdereg
	inx
	cpx #8
	bcc @dumpde00loop

	lda #16
	jsr setrow

	ldx #$10
@dumpde10loop:
	jsr dumpdereg
	inx
	cpx #$14
	bcc @dumpde10loop
	
	lda #3
	jsr setrow

	ldx #0
@dumpdfloop:
	ldy #20
	jsr dumpdfreg
	inx
	cpx #16
	bcc @dumpdfloop


	;; Holding pattern

	lda #$7f
	sta $dc00
@wait_here:	
	inc $d020
	lda $dc01
	and #$10
	bne @wait_here

	jsr clear_screen

	lda #1
	sta screen

	jsr initmmc64

	sta screen+1
	lda #'0'
	adc #0
	sta screen+2

	jsr selectmmc64

	lda #3
	sta screen+4
	
	lda #0
	sta blknum
	sta blknum+1
	sta blknum+2
	sta blknum+3

	lda #5
	sta screen+6

	lda #<(screen+80)
	sta mmcptr
	lda #>(screen+80)
	sta mmcptr+1

	jsr blockread1
	sta screen+7
	lda #'0'
	adc #0
	sta screen+8

	
	lda #0
	sta blknum
	sta $d020

	lda #0
	sta vswap
	sta aswap
	sta $df04
	sta $df05
	sta $df06
	sta $df19
	sta $df1d
	sta $df29
	sta $df2d
	lda #<$d418
	sta $df12
	sta $df22
	lda #>$d418
	sta $df13
	sta $df23

	ldx #2
	lda #$10
	bit $df00
	beq @only128k
	lda $df06
	eor #$ff
	tax
	inx
@only128k:
	jsr initstream

	jmp @nextframe

@readblocked2:
	lda #0
	sta $df04
@readblocked1:
	lda #2
	sta $d020
@nextframe:
	lda $df05
	jsr getstreamdata
	beq @readblocked1

	lda #<frame_header
	sta $df02
	lda #>frame_header
	sta $df03
	lda #<16
	sta $df07
	lda #>16
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

	cpx frame_header+2
	bcc @readblocked2
	
	lda frame_header+4
	and #$04
	beq @noaudioprep

	lda aswap
	eor #$10
	sta aswap
	tax
	lda $df04
	sta $df14,x
	lda $df05
	sta $df15,x
	lda $df06
	sta $df16,x
	lda frame_header+5
	sta $df17,x
	lda frame_header+6
	sta $df18,x
	lda #$80
	sta $df1a,x
	sta $df1b,x
	lda frame_header+10
	sta $df1c,x
	lda frame_header+11
	sta $df1e,x
	lda #$81
	sta $df11,x

@noaudioprep:	
	lda #0
	sta $df04
	clc
	lda $df05
	adc frame_header+3
	sta $df05
	bne @nowrap1
	inc $df06
@nowrap1:

	ldx vswap
	lda frame_header+4
	and #$01
	beq @nobitmap
	txa
	eor #$04
	sta vswap
	tax
		
	dec $d020
	dec $d020

	lda #0
	sta $df02
	sta $df07
	lda swapdata+0,x
	sta $df03
	lda #>$2000
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

	dec $d020

	lda #0
	sta $df02
	sta $df07
	lda swapdata+1,x
	sta $df03
	lda #>$0400
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

@nobitmap:
	lda #0
	sta $d020
	
@sync1:
	inc $d024
	lda $d012
	bne @sync1
	lda $d011
	bmi @sync1

	sta $ff00 ; trigger audio DMA, if set up
	lda #$3b
	sta $d011
	lda swapdata+2,x
	sta $d018
	lda swapdata+3,x
	sta $dd00

	dec $d020
	
	lda frame_header+$f
	sta $d021
	lda frame_header+$e
	sta $d016

	lda frame_header+$4
	and #$02
	beq @nocram

	lda #0
	sta $df02
	sta $df07
	lda #>$d800
	sta $df03
	lda #>$0400
	sta $df08
	lda #$91
	sta $df01
	jsr waitdma

@nocram:
	lda frame_header+2
	beq end_of_movie
	jmp @nextframe

end_of_movie:
	lda #0
	sta $d020
	ldx #3
@wait0:
	inc $d024
	lda $d012
	beq @wait0
@wait1:
	inc $d024
	lda $d012
	bne @wait1
	lda $d011
	bmi @wait1
	lda #$0b
	sta $d011
	dex
	bne @wait0

	lda #$08
	sta $d016
	lda #$15
	sta $d018
	lda #0
	sta $d418

halt_here:
	jmp halt_here


waitdma:
	inc $d024
	lda $df00
	bpl waitdma
	rts



	;; Dump one register on page $DE00 and advance to the next row
	;; A - scratch
	;; X - in: low byte of register address (preserved)
	;; Y - in: column to print at, out: set to 0
dumpdereg:
	lda #>$de00
	jsr dumpreg
	ldx vreg
	jmp nextrow

	;; Dump one register on page $DF00 and advance to the next row
	;; A - scratch
	;; X - in: low byte of register address (preserved)
	;; Y - in: column to print at, out: set to 0
dumpdfreg:
	lda #>$df00
	jsr dumpreg
	ldx vreg
	jmp nextrow


vicinit:
	.byte $0b
	.byte 0, 0, 0
	.byte 0
	.byte $08
	.byte 0
	.byte $15
	.byte $ff
	.byte 0
	.byte $ff
	.byte 0
	.byte 0
	.byte 0, 0
	.byte 0
	.byte 0

message:
	scrcode "hello, this is exrom code."
message_length = * - message


irq_handler:
	inc $d021
	jmp irq_handler


	.align 4

swapdata:
	.byte >$4000, >$6000, $80, 2
	.byte >$2000, >$0c00, $38, 3
	
