
	.macpack cbm

	.export index_file

	.import index_clear, index_add
	.import follow_fat, cluster, blocks_per_cluster

	.import screen, clear_screen, setrow, nextrow, printtext

	.import index_fill0, index_refill	
	.import printhex
	.importzp blknum, index_avail
		
	.code

index_overflow:
	lda #10
	jsr setrow
	jsr printtext
	scrcode "ERROR:	File too fragmented@"
@hang:
	beq @hang
	
index_file:
	jsr index_clear
	jsr clear_screen
	lda #0
	jsr setrow
	jsr printtext
	scrcode "Indexing file...@"
	lda #0
@next_cluster:
	tay
	and #7
	tax
	lda progress,x
	sta screen+16
	dey
	lda blocks_per_cluster
	jsr index_add
	bcs index_overflow
	tya
	pha
	jsr follow_fat
	pla
	bcc @next_cluster
	
	lda #2
	jsr setrow
	jsr index_fill0
	beq nope
@nextindex:
	lda blknum+3
	jsr printhex
	lda blknum+2
	jsr printhex
	lda blknum+1
	jsr printhex
	lda blknum
	jsr printhex
	iny
	lda index_avail+1
	jsr printhex
	lda index_avail
	jsr printhex
	jsr nextrow
	jsr index_refill
	bne @nextindex
nope:
	jsr nextrow
	jsr printtext
	scrcode "End of index@"

@wait_here:	
	inc $d020
	lda $dc01
	and #$10
	bne @wait_here
	lda #0
	sta $d020
	rts


progress:
	.byte $6c, $7c, $7e, $7b, $70, $6d, $7d, $6e
