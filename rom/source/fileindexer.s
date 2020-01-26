
	.macpack cbm

	.export index_file

	.import index_clear, index_add
	.import follow_fat, cluster, blocks_per_cluster

	.import screen, clear_screen, setrow, nextrow, printtext

	.import index_fill0, index_refill	
	.importzp blknum, index_avail

	.bss

block_progress_low:	.res 1
block_progress_high:	.res 1
progress_target_low:	.res 1
progress_target_high:	.res 1
blocks_remain:		.res 3

	.code

index_overflow:
	lda #10
	jsr setrow
	jsr printtext
	scrcode "ERROR:	File too fragmented@"
@hang:
	beq @hang
	
index_file:
	sta blocks_remain
	stx blocks_remain+1
	sty blocks_remain+2
	ora blocks_remain+1
	ora blocks_remain+2
	bne @nonempty
	jmp @eof
@nonempty:
	inx
	bne @nowrap
	iny
@nowrap:
	stx progress_target_low
	sty progress_target_high
	jsr index_clear
	jsr clear_screen
	lda #0
	sta block_progress_low
	sta block_progress_high
	jsr setrow
	jsr printtext
	scrcode "Indexing file...@"
	lda #$73
	sta screen+83
	lda #$6b
	sta screen+116
	ldx #31
	lda #$e
@setcolor1:
	sta $d800+84,x
	dex
	bpl @setcolor1
	lda #0
@next_cluster:
	tay
	sec
	lda block_progress_low
	sbc progress_target_low
	tax
	lda block_progress_high
	sbc progress_target_high
	bcc @noprogress
	sta block_progress_high
	stx block_progress_low
	tya
	and #7
	tax
	lda progressbar,x
	pha
	tya
	lsr
	lsr
	lsr
	tax
	pla
	sta screen+84,x
	lda #0
	sta block_progress_low
	sta block_progress_high
	iny
@noprogress:
	ldx blocks_per_cluster
	lda blocks_remain+2
	bne @whole_cluster
	lda blocks_remain+1
	bne @whole_cluster
	cpx blocks_remain
	bcc @whole_cluster
	ldx blocks_remain
	lda #0
	sta blocks_remain
	beq @residue
@whole_cluster:
	sec
	lda blocks_remain
	sbc blocks_per_cluster
	sta blocks_remain
	lda blocks_remain+1
	sbc #0
	sta blocks_remain+1
	lda blocks_remain+2
	sbc #0
	sta blocks_remain+2
@residue:
	txa
	clc
	adc block_progress_low
	sta block_progress_low
	bne @noprogress2
	inc block_progress_high
@noprogress2:
	txa
	jsr index_add
	bcc @index_ok
	jmp index_overflow
@index_ok:
	lda blocks_remain+2
	ora blocks_remain+1
	ora blocks_remain
	beq @eof
	tya
	pha
	jsr follow_fat
	pla
	bcs @eof
	jmp @next_cluster
@eof:
	jsr index_fill0
	jsr clear_screen
	ldx #31
	lda $d800
@setcolor2:
	sta $d800+84,x
	dex
	bpl @setcolor2
	rts


progressbar:
	.byte $65, $74, $75, $61, $f6, $ea, $e7, $e0
