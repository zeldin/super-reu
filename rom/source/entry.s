
	.macpack cbm

	.import screen, clear_screen, setrow, nextrow, dumpreg
	.importzp vreg

	.import initmmc64, selectmmc64, deselectmmc64
	.import blockread1, blockreadn, blockreadmulticmd, stopcmd
	.importzp mmcptr, blknum

	.import movie_player

	.import __SCRN_START__

AVEC = ((__SCRN_START__ >> 6) & $3f0) ^ (($1000 >> 10) & $0f) ^ $300


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
	lda #>AVEC
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

	jsr movie_player
	
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
	.byte <AVEC
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

