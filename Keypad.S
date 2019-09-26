#Author: Alex Gerson
# Keypad API Routines
#
	.syntax unified
	.cpu cortex-m4
  	.thumb
	.section .text

	.global Keypad

	.equ GPIOA_BASE, 0x40020000
	.equ GPIOB_BASE, 0x40020400
	.equ GPIOC_BASE, 0x40020800

	.equ MODER, 0x00
	.equ PUPDR, 0x0C
	.equ IDR, 0x10
	.equ ODR, 0x14
	.equ BSRR, 0x18

	.equ RCC_BASE, 0x40023800
	.equ RCC_AHB1ENR, 0x30
	.equ GPIOA_EN, 0b1
	.equ GPIOB_EN, 0b10
	.equ GPIOC_EN, 0b100

	#lcd pins - for BSRR use
	.equ LCD_E_SET,  1<<10
	.equ LCD_RW_SET, 1<<9
	.equ LCD_RS_SET, 1<<8

	.equ LCD_E_CLR,  LCD_E_SET << 16
	.equ LCD_RW_CLR, LCD_RW_SET << 16
	.equ LCD_RS_CLR, LCD_RS_SET << 16


Keypad:
/*  MAIN FUNCTION FROM LAB05!!!!

	bl key_init
	bl lcd_init
	bl lcd_clear
	bl lcd_home
	MOV R10, #0
loop:
	bl key_getchar
	CMP R0, #0
	BEQ nah
	bl lcd_data
	ADD R10, #1
nah:
	#sentinel keep track of key presses
	//when 32 is reached, clear screen
	CMP R10, #32
	BNE end
	bl lcd_clear
	bl lcd_home
	MOV R10, #0
end:
	b loop
*/
		#function definitions below main demo

	/*Initialize the keypad GPIO port.  
	  Depending on your scanning algorithm,
	  there may not be any work to do in this method.*/
		.global key_init
key_init:
	//stack
	push {R0-R12, LR}
	//RCC enable for GPIOC
	#PC[0..3]=COL[1..4], PC[4..7]=ROW[1..4]
	ldr r4, =RCC_BASE
	ldr r5,[r4, #RCC_AHB1ENR]
	orr r5, r5, #GPIOC_EN
	str r5,[r4, #RCC_AHB1ENR]

	#ROW1-4 pull up
	#COL1-4 pull up
	ldr r0, =GPIOC_BASE
	mov R2, #0b01010101
	ldr r1, [r0, #PUPDR]
	bfi r1, r2, #8, #8
	bfi R1, R2, #0, #8
	str r1, [r0, #PUPDR]

	pop {R0-R12, PC}

COLout_ROWin:
	push {R0-R12, LR}
	/*MODER Port C
	  COL4-1 output PC3-0
	  ROW4-1 input PC7-4*/
	ldr r4, =GPIOC_BASE
	mov R2, #0b01010101 //C3-0 output
	//zero extend C7-4 for input
	ldr R5,[R4, #MODER]
	bfi R5, R2, #0, #16
	str R5,[R4, #MODER]

	POP {R0-R12, PC}

COLin_ROWout:
	push {r0-r12, LR}
	/*MODER Port C
	  COL4-1 input PC3-0
	  ROW4-1 output PC7-4*/
	ldr r4, =GPIOC_BASE
	mov R2, #0b01010101 //R2 has output
	mov R1, #0 //R1 has input
	//
	ldr R5,[R4, #MODER]
	bfi R5, R2, #8, #8
	bfi R5, R1, #0, #8
	str R5,[R4, #MODER]

	POP {R0-R12, PC}

/*Returns in r0 a numeric code representing the button on the keypad that was pressed (1 to 16),
  or 0 if no button is pressed.*/
		.global key_getkey_noblock
key_getkey_noblock:
	push {R1-R12, LR}
	/*COL4-1 output PC3-0
	  ROW4-1 input PC7-4*/
	bl COLout_ROWin
	//send 0 to column
	ldr r0, =GPIOC_BASE
	LDR R1, [R0, #ODR]
	MOV R2, #0
	BFI R1, R2, #0, #4
	STR R1, [R0, #ODR]

	mov R1, #10
	bl lcd_delay
	// read IDR of ROW
	LDR R3, [r0, #IDR]
	UBFX R4, R3, #4, #4

	mov R5, #0 // initialize as no key pressed
	CMP R4, #0b1110
	IT EQ
	moveq R5, #1 //R5 has row of the key press
	CMP R4, #0b1101
	IT EQ
	moveq R5, #2
	CMP R4, #0b1011
	IT EQ
	moveq R5, #3
	CMP R4, #0b0111
	IT EQ
	moveq R5, #4

	/*COL4-1 PC3-0
	  ROW4-1 PC7-4*/
	bl COLin_ROWout
	// put IDR value of row in its ODR
	LDR R1, [R0, #ODR]
	BFI R1, R4, #4, #4
	STR R1, [R0, #ODR]

	mov R1, #10
	bl lcd_delay
	//read 0 on column IDR
	LDR R3, [r0, #IDR]
	UBFX R6, R3, #0, #4

	CMP R6, #0b1110
	IT EQ
	moveq R7, #1 //R7 has column of the key press
	CMP R6, #0b1101
	IT EQ
	moveq R7, #2
	CMP R6, #0b1011
	IT EQ
	moveq R7, #3
	CMP R6, #0b0111
	IT EQ
	moveq R7, #4

	//return 0 if no key pressed
	CMP R5, #0
	ITT EQ
	moveq R0, #0
	BEQ skip

	#assign key number to R0 according to row(R5) col(R7)
	#(row-1)*4+col=key_num
	sub R5, R5, #1
	mov R8, #4
	MUL R0, R5, R8
	add R0, R0, R7
skip:
	pop {R1-R12, PC}

/*Same as key_getkey_noblock, but blocks – that is,
  waits until a key is pressed and then returns the key code.
  Per discussion in lecture, you may wish to return after said key is released.*/
		.global key_getkey
key_getkey:
	push {R1-R12, LR}
1:
	bl key_getkey_noblock
	CMP R0, #0
	beq 1b

	mov R10, R0
2:
	bl key_getkey_noblock
	CMP R0, #0
	bne 2b

	mov R0, R10

	pop {R1-R12, PC}

/*Similar to key_getkey, but returns the ASCII code corresponding to the key press.
  This method blocks.  
  You should use a data structure in .rodata to map keys to characters.*/
		.global key_getchar
key_getchar:
	push {R1-R12, LR}

	bl key_getkey
	CMP R0, #0
	BEQ skipp

	SUB R0, R0, #1// keyNum-1 will be added to string addr
	LDR R1, =keys// string addr in R1
	ADD R1, R1, R0

	LDRB R0, [R1]//
skipp:
	pop {R1-R12, PC}


.section .data
keys:
	.asciz "123A456B789C*0#D"
.balign 4
