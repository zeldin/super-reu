
	.macpack cbm

	.import init_screen, clear_screen, setrow, nextrow, printtext, printhex
	.importzp vreg

	.import deselectmmc64, selectmmc64, stopcmd

	.import fileselector, movie_player


	.code
	
	.word start
	.word start

	.byte "CBM80"

start:
	sei
	cld
	lda #$37
	sta $01
	lda #$2f
	sta $00
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
	lda #0
	sta $dc13
	lda $de11
	and #%00000100
	ora #%00000011
	sta $de11

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
	lda #<start
	sta $318
	lda #>start
	sta $319
	cli

	lda #%00000100
	bit $de11
	beq @no8mhz
	jsr selectmmc64
	jsr stopcmd
	jsr deselectmmc64
@no8mhz:

	jsr clear_screen
	lda #0
	jsr setrow
	jsr printtext
	scrcode "super-reu version @"
	lda $df00
	and #$0f
	jsr printhex
	lda #3
	jsr setrow
	jsr printtext
	scrcode "Press 1 for movie player@"
	jsr nextrow
	jsr printtext
	scrcode "Press Q to quit into BASIC@"
	jsr nextrow
	jsr printtext
	scrcode "RESTORE returns to this screen@"
	
	lda #$1b
	sta $d011


@wait_here:	
	lda $dc01
	lsr
	bcc @next_movie
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	bcc exit_to_basic
	jmp @wait_here

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


irq_handler:
	inc $d020
	jmp irq_handler


exit_to_basic:
	sei
	ldx #$ff
	txs
	cld
	lda #$37
	sta $01
	lda #$2f
	sta $00
	lda #$0b
	sta $d011
	jsr $ff84
	jsr $ff87
	jsr $ff8a
	jsr $ff81
	ldx #@stub_size-1
@copy_stub:
	lda @stub,x
	sta $1f0,x
	dex
	bpl @copy_stub
	lda #0
	ldx #$37
	ldy #%10100011
	jmp $1f0

@stub:
	sty $de11
	stx $01
	tax
	tay
	cli
	jmp ($a000)

@stub_size = *-@stub
