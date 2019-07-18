
	.macpack cbm

	.import screen, clear_screen, setrow, nextrow, dumpreg
	.importzp vreg

	.import initmmc64, enable8mhzmode, sendifcondmmc64
	.import blockreadcmd, waitformmcdata, blockread, stopcmd, mmc64cmd
	.importzp mmcptr, blknum

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

	lda #'0'
	adc #0
	sta screen+2

	jsr enable8mhzmode

	lda #4
	sta screen+3

	jsr sendifcondmmc64

	sta screen+4
	lda #'0'
	adc #0
	sta screen+5

@idlewait:
	ldy #0
	lda #$77
	jsr mmc64cmd
	ldy #$40
	lda #$69
	jsr mmc64cmd	
	lda $de10
	bne @idlewait

	ldy #0
	lda #$7a
	jsr mmc64cmd
	stx $de10
	stx $de10
	stx $de10
	stx $de10

	lda #0
	sta blknum
	sta blknum+1
	sta blknum+2
	sta blknum+3
	jsr blockreadcmd

	lda #5
	sta screen+6

	jsr waitformmcdata

	lda #6
	sta screen+7

	lda #<(screen+80)
	sta mmcptr
	lda #>(screen+80)
	sta mmcptr+1
	jsr blockread

	lda #7
	sta screen+8

	jsr stopcmd

	lda #8
	sta screen+9

	
	lda #0
	sta blknum
	sta $d020

@nextframe:
	lda #<$4000
	sta mmcptr
	lda #>$4000
	sta mmcptr+1
	ldx #18
@movieloop:
	txa
	pha

	jsr blockreadcmd
	jsr waitformmcdata
	jsr blockread
	jsr stopcmd
		
	pla
	tax
	dex
	bne @movieloop

@sync1:
	lda $d011
	bpl @sync1

	lda #$3b
	sta $d011
	lda #$80
	sta $d018
	lda #2
	sta $dd00


	lda #<$2000
	sta mmcptr
	lda #>$2000
	sta mmcptr+1
	ldx #18
@movieloop2:
	txa
	pha

	jsr blockreadcmd
	jsr waitformmcdata
	jsr blockread
	jsr stopcmd
		
	pla
	tax
	cpx #3
	bne @noswitch
	lda #>$0c00
	sta mmcptr+1
@noswitch:		
	dex
	bne @movieloop2

@sync2:
	lda $d011
	bpl @sync2

	lda #$3b
	sta $d011
	lda #$38
	sta $d018
	lda #3
	sta $dd00

	jmp @nextframe
	
		
halt_here:
	jmp halt_here


waitdma:
	inc $d020
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

