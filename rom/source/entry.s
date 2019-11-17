
	.macpack cbm

	.import screen, init_screen, clear_screen, setrow, nextrow, dumpreg
	.importzp vreg

	.import fileselector, movie_player


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
	stx $dc02
	inx
	stx $dc03
	dex
	lda #$7f
	sta $dc00

	jsr init_screen

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

@wait_here:	
	inc $d020
	lda $dc01
	and #$10
	bne @wait_here

@next_movie:
	lda #0
	sta $d020
	jsr fileselector
	jsr movie_player
	jsr init_screen
	jsr clear_screen
	lda #$1b
	sta $d011
	jmp @next_movie


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


message:
	scrcode "Hello, this is EXROM code."
message_length = * - message


irq_handler:
	inc $d021
	jmp irq_handler

