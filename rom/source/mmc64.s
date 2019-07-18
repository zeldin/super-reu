
	.export initmmc64, enable8mhzmode, sendifcondmmc64
	.export blockreadcmd, waitformmcdata, blockread, stopcmd, mmc64cmd
	.exportzp mmcptr, blknum


	.zeropage

mmcptr:	.res 2
blknum:	.res 4

	.code

	
; Initialize a flash card plugged into the MMC64

initmmc64:
;	inc $0427
;	bne @foo
;	inc $0426
@foo:	
	lda $de11	;get contents of MMC64 control register
	and #%10111011	;set 250khz & write trigger mode
	ora #%00000010	;disable card select
	sta $de11	;update control register
	ldx #$0a	;initialize counter (10*8 pulses)
	ldy #$ff	;initialize value to be written (bits must be all high)
@mmcinitloop:	
	sty $de10	;send 8 pulses to the card
@busywait:	
	lda $de12	;we catch the status register
	and #$01	;all bits shiftet out?
	bne @busywait	;nope, so wait
	dex		;decrement counter
	bne @mmcinitloop;until 80 pulses sent
	lda $de12		;is there a card at all ?
	and #$08		
	bne @error		;nope, bail out
	lda $de11	;pull card chip select line down for SPI communication
	and #%11111101
	sta $de11
	ldy #$08		;we send 8 command bytes to the card
	ldx #$05		;we wait for the response up to 5 bytes
@mmc64resetloop:
	lda @resetcmd-1,y	;grab command byte
	sta $de10		;and fire it to the card
@resetbusy:	
	lda $de12		;we check the busy bit
	and #$01		;to ensure that the transfer is safe
	bne @resetbusy
	dey			;decrease command counter
	bne @mmc64resetloop	;until the entire command has been sent
	lda $de10		;now we check the card response
	cmp #$01		;did it accept the command ?
	clc
	beq @done		;ok, everything is fine !
	dex			;need to check more bytes before retransmit?
	beq initmmc64		;no, try again
	iny
	bne @mmc64resetloop	;get the next byte
@error:	
	sec
@done:
	rts

@resetcmd:	
	.byte $ff,$f9,$00,$00,$00,$00,$40,$ff	;CMD0


enable8mhzmode:	
	lda $de11
	ora #%00000100
	sta $de11
	rts


;check if card is SD1 or SD2

sendifcondmmc64:	
	ldy #$09		;we send 8 command bytes to the card
@sendifcondloop:	
	lda @sendifcondcmd-1,y	;grab command byte
	sta $de10		;and fire it to the card
	dey			;decrease command counter	
	bne @sendifcondloop	;until entire command has been sent
	clc
	lda $de10		;did the card accept the command
	and #$04
	bne @issd1
	ldy #$04
	lda #$ff
@recvifconfloop:
	sta $de10
	dey
	bne @recvifconfloop
	lda $de10
	cmp #$aa
	clc
	beq @issd2
	sec
@issd1:
	lda #$00
@issd2:
	rts

@sendifcondcmd:
	.byte $ff,$ff,$87,$aa,$01,$00,$00,$48,$ff	;CMD8

	
;Block read command

blockreadcmd:	
	ldy #$ff
	sty $de10
	lda #$51		;  CMD17
	sta $de10
	lda blknum+3
	sta $de10
	lda blknum+2
	sta $de10
	lda blknum+1
	sta $de10
	lda blknum
	sta $de10
	sty $de10
	sty $de10
	sty $de10
	rts

	
;Wait until card is ready

waitformmcdata:	
	lda #$ff	
	sta $de10		;write all high bits
	lda $de10		;to give the possibility to respond
	cmp #$fe		;has it started?
	bne waitformmcdata 	;nop, so we continue waiting
	rts
	
; Transfer 512 bytes from card into memory

blockread:	
	lda $de11		;set MMC64 into read trigger mode
	ora #%01000000		;which means every read triggers a SPI transfer
	sta $de11

	lda $de10		;we have to start with one dummy read here

	ldx #$02		;set up counters
	ldy #$00
@sectorcopyloop:	
	lda $de10		;get data byte from card
	sta (mmcptr),y		;store it into memory ( mmcptr has to be initialized)
	iny			;have we copied 256 bytes ?
	bne @sectorcopyloop	;nope, so go on!
	inc mmcptr+1		;increase memory pointer for next 256 bytes
	dex			;have we copied 512 bytes ?
	bne @sectorcopyloop

	lda $de10		;we have to end the data transfer with one dummy read
	
	lda $de11		;now we put the hardware back into write trigger mode again
	and #%10111111	
	sta $de11
	inc blknum
	bne @nowrap
	inc blknum+1
	bne @nowrap
	inc blknum+2
	bne @nowrap
	inc blknum+3
@nowrap:
	rts

;Stop the data transfer

stopcmd:	
	ldy #$09
@stopcmdloop:	
	lda @stopcmd-1,y
	sta $de10
	dey
	bne @stopcmdloop
	rts
	
@stopcmd:	
	.byte $ff,$ff,$ff,$00,$00,$00,$00,$4c,$ff	;CMD12


mmc64cmd:
	ldx #$ff
	stx $de10
	sta $de10
	sty $de10
	inx
	stx $de10
	stx $de10
	stx $de10
	dex
	stx $de10
	stx $de10
	stx $de10
	rts
