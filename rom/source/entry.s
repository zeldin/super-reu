
	.macpack cbm

	.import init_screen, clear_screen, setrow, nextrow, printtext, printhex
	.importzp vreg

	.import deselectmmc64, selectmmc64, stopcmd

	.import fileselector, movie_player


	.zeropage

isc128:	.res 1
	
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
	sta isc128
	sta $d418
	sta $d404
	sta $d40b
	sta $d412
	sta $de13
	lda $de11
	and #%00000100
	ora #%00000011
	sta $de11
	jsr checkc128
	bne @not128
	inc isc128
@not128:

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
	lda isc128
	beq @noprompt128
	jsr printtext
	scrcode "Press ",$5f," to enter C128 mode@"
	jsr nextrow
@noprompt128:
	jsr printtext
	scrcode "RESTORE returns to this screen@"
	
	lda #$1b
	sta $d011


wait_here:	
	lda $dc01
	lsr
	bcc @next_movie
	lsr
	bcc go128
	lsr
	lsr
	lsr
	lsr
	lsr
	bcc exit_to_basic
	jmp wait_here

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

go128:
	lda isc128
	beq wait_here
	sei
	ldx #$ff
	txs
	ldx #@stub2_size-1
@copy_stub2:
	lda @stub2,x
	sta $1f0,x
	dex
	bpl @copy_stub2
	lda #$52
	ldy #%10100011
	jmp $1f0

@stub2:
	sty $de11
	sta $de00
	bne @stub2

@stub2_size = *-@stub2
	

irq_handler:
	inc $d020
	jmp irq_handler


	; Check for C128, result in Z
checkc128:
	lda #$ff
	sta $d02f
	lda #$fe
	sta $d030
	ldx $d02f
	ldy $d030
	lda #$00
	sta $d02f
	sta $d030
	lda $d02f
	stx $d02f
	inx
	bne @not128
	iny
	iny
	bne @not128
	cmp #$f8   ; d02f implements 3 bits for extra keyboard columns
	bne @not128
	lda $d030  ; d030 implements 2 bits for 2MHz and test mode
	cmp #$fc
@not128:
	rts


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
	ldx #@stub_size-1
@copy_stub:
	lda @stub,x
	sta $140,x
	dex
	bpl @copy_stub
	lda #0
	ldx #$37
	ldy #%10100011
	jmp $140

@stub:
	sty $de11
	stx $01
	tax
	tay
	jsr $ff84
	jsr $ff87
	jsr $ff8a
	jsr $ff81
	cli
	jmp ($a000)

@stub_size = *-@stub
