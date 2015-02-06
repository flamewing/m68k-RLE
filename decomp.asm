; ===========================================================================
; values for the rwd argument
READ = %001100
WRITE = %000111
DMA = %100111

VRAMCommReg_defined := 1
VRAMCommReg macro reg,rwd,clr
	lsl.l	#2,reg							; Move high bits into (word-swapped) position, accidentally moving everything else
    if rwd <> READ
	addq.w	#1,reg							; Add write bit...
    endif
	ror.w	#2,reg							; ... and put it into place, also moving all other bits into their correct (word-swapped) places
	swap	reg								; Put all bits in proper places
    if clr <> 0
	andi.w	#3,reg							; Strip whatever junk was in upper word of reg
    endif
	if rwd == DMA
	tas.b	reg								; Add in the DMA bit -- tas fails on memory, but works on registers
    endif
    endm
; ===========================================================================
; Checks if we already have a byte stored in d6 and writes a word composed
; of the byte in d6 and the byte in d3 to a2 if so
; Otherwise, stores byte in d3 to high byte of d6
ChkWriteWord macro target
	tst.b	d0
	bne.s	.got_high_byte
	move.b	d3,d6
	lsl.w	#8,d6
	st.b	d0
	bra.s	target

.got_high_byte:
	move.b	d3,d6
	move.w	d6,(a2)
	clr.b	d0
	dbra	d1,target
    endm
; ===========================================================================
; d2 = VRAM address
; a1 = compressed art to write to VRAM
SNKDec:
	move.w	#$2700,sr
	movem.l	d0/d1/d3-a0/a2-a6,-(sp)

SNKDecToVRAM:
	VRAMCommReg d2, WRITE, 1
	lea	(VDP_data_port).l,a2
	move.l	d2,VDP_control_port-VDP_data_port(a2)

SNKDecMain:
	;16 words = 1 tile
	moveq	#0,d0
	moveq	#0,d1
	move.w	(a1)+,d1 
	lsl.l	#4,d1							; number of uncompressed words
	
	move.b	(a1)+,d3
	ChkWriteWord .main_loop
	bra.s	SNKDecEnd
;----------------------------------------------------------------------------
.main_loop:
	move.b	(a1)+,d4
	cmp.b	d3,d4
	bne.s	.cont
	ChkWriteWord .fetch_count
	bra.s	SNKDecEnd
;----------------------------------------------------------------------------
.fetch_count:
	move.b	(a1)+,d5

.copy_loop:
	tst.b	d5
	beq.s	.main_loop
	subq.b	#1,d5
	ChkWriteWord .copy_loop
	bra.s	SNKDecEnd
;----------------------------------------------------------------------------
.cont:
	move.b	d4,d3
	ChkWriteWord .main_loop

SNKDecEnd:
	movem.l	(sp)+,d0/d1/d3-a0/a2-a6
	move.w	#$2000,sr
	rts
; ===========================================================================
