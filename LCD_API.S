#Author: Alex Gerson
# LCD_API Routines
	.syntax unified
	.cpu cortex-m4
  	.thumb
	.section .text

	.global LCD_API

	.equ GPIOA_BASE, 0x40020000
	.equ GPIOC_BASE, 0x40020800
	.equ MODER_OFFSET, 0x0
	.equ IDR_OFFSET, 0x10
	.equ ODR_OFFSET, 0x14
	.equ BSRR_OFFSET, 0x18

	.equ RCC_BASE, 0x40023800
	.equ AHB1ENR_OFFSET, 0x30
	.equ GPIOA_EN, 0b1
	.equ GPIOC_EN, 0b100

	#lcd pins - for BSRR use
	.equ LCD_E_SET,  1<<10
	.equ LCD_RW_SET, 1<<9
	.equ LCD_RS_SET, 1<<8

	.equ LCD_E_CLR,  LCD_E_SET << 16
	.equ LCD_RW_CLR, LCD_RW_SET << 16
	.equ LCD_RS_CLR, LCD_RS_SET << 16


LCD_API:
	#NO MAIN FUNCTION!!!

	// function definitions starts here:

# clears the display, no arguments or return
# includes necessary delay*
		.global lcd_clear
lcd_clear: // DONE!!!!
	push {r0-r12, LR}
	mov R0, #1
	bl lcd_cmd
	mov R1, #1520
	bl lcd_delay
	pop  {r0-r12, PC}

# moves cursor to the home position, no arguments or return
# includes necessary delay*
		.global lcd_home
lcd_home:  // DONE!!!
	push {r0-r12, LR}
	mov R0, #0b11
	bl lcd_cmd
	mov R1, #1520
	bl lcd_delay
	pop  {r0-r12, PC}

# moves cursor to the position indicated,
# r0 is the zero-based row and r1 is the zero-based column
# no return value, includes necessary delay*
		.global lcd_set_position
lcd_set_position: //DONE!!!
	push {r0-r12, LR}
	#addr in R2
	movw R2, #1<<7
	LSL R0, R0, #6// row bit AC6
	ORR R2, R2, R0
	ORR R2, R2, R1// column in lower 4 bits

	MOV R0, R2
	bl lcd_cmd

	pop  {r0-r12, PC}

# prints a null terminated string to the display
# r0 contains the address of the null terminated string (usually located in .data or .rodata),
# returns the number of characters written to display in r0
# includes necessary delay*
		.global lcd_print_string
lcd_print_string: // DONE!!!
	push {r1-r12, LR}

	mov r3, r0 //increment addr in R3

	mov R5, #0 // R5 hold character count

proceed:
	#set position before print
	LDRB R2,[R3]//letters in R2
	mov R0, R2
	bl lcd_data

	CMP R2, #0 // NULL CHAR
	ITT NE
	ADDNE R3, R3, #1 // char addr+1
	ADDNE R5, R5, #1// char count+1

	BNE proceed

	mov R0, R5 // return char count

	pop  {r1-r12, PC}


# lcd_init - set up all GPIO pins, reset, and init display
# to 8-bit mode

	.global lcd_init
lcd_init: // STARTER CODE!!!
	push {r4-r6,lr}

	movw r1, #5000	// power-on delay
	bl lcd_delay

	# enable GPIOA and GPIOC
	ldr r4,=RCC_BASE
	ldr r5,[r4,#AHB1ENR_OFFSET]
	orr r5,r5,#(GPIOA_EN|GPIOC_EN)
	str r5,[r4,#AHB1ENR_OFFSET]

	# set PC8-10 to output
	ldr r4,=GPIOC_BASE
	ldr r5,[r4,#MODER_OFFSET]

	# clear low 6 bits
	bfc r5, #16, #6
	# set 010101
	orr r5, r5, #(0b010101)<<16
	str r5,[r4,#MODER_OFFSET]

	# set PA4-11 to output
	ldr r4,=GPIOA_BASE
	ldr r5,[r4,#MODER_OFFSET]

	# clear bits 16-23
	bfc r5, #8, #16
	# set 0101010101010101 byte
	ldr r6, =(0x5555<<8)
	orr r5, r5, r6
	str r5,[r4,#MODER_OFFSET]

	# ports are setup, ready to init display
	mov r0, #0x38  // 8-bit mode
	bl lcd_cmd
	mov r0, #0x01	// clear
	bl lcd_cmd
	movw r1, #1500	// clear needs extra time
	bl lcd_delay
	mov r0, #0x02	// home
	bl lcd_cmd
	bl lcd_delay	// home needs extra time
	mov r0, #0x06	// Entry mode, move right, no shift
	bl lcd_cmd
	mov r0, #0x0F	// Display on, cursor
	bl lcd_cmd

	pop {r4-r6,pc}


	.global lcd_cmd
# command byte comes in LSB of R0
lcd_cmd: // DONE!!!
	# stack
	push {R0-R12, LR}
	# make sure rw(PC9) and rs(PC8) are low, C[9..8]=00
	LDR R2, =GPIOC_BASE
	LDR R3, [R2, #ODR_OFFSET]
	movw R4, #0b00
	BFI R3, R4, #8, #2
	STR R3, [R2, #ODR_OFFSET]

	bl lcd_exec

	# return
	pop {R0-R12, PC}

# data byte comes in LSB of R0
	.global lcd_data
lcd_data: // DONE!!!
	# stack
	push {R0-R12, LR}
	# make sure rw(PC9) is low, and rs(PC8) is high, bring E high
	//c[9..8]=01
	LDR R2, =GPIOC_BASE
	LDR R3, [R2, #ODR_OFFSET]
	movw R4, #0b01
	BFI R3, R4, #8, #2
	STR R3, [R2, #ODR_OFFSET]

	bl lcd_exec

	# return
	pop {R0-R12, PC}

# command or data byte comes in LSB of R0
# only called from lcd_cmd or lcd_data
lcd_exec: // QUESTIONS!!!
	# stack
	push {R0-R12, LR}

	# place byte of command/data byte on output
	bl lcd_set

	bl lcd_latch

	mov r1, #40	// delay 40 uS
	bl lcd_delay

	# return
	pop {R0-R12, PC}

# subroutine places command or data in R0
# onto PA4-PA11
lcd_set: // DONE!!!
	push {R0-R12, LR}

	LDR R2, =GPIOA_BASE
	LDR R3, [R2, #ODR_OFFSET]
	BFI R3, R0, #4, #8
	STR R3, [R2, #ODR_OFFSET]

	mov r1, #40	// delay 40 uS
	bl lcd_delay

	pop {R0-R12, PC}

# subroutine to pulse E
lcd_latch: // DONE!!!
	push {R0-R12, LR}
	# bring E high C[10]=1
	LDR R2, =GPIOC_BASE
	LDR R3, [R2, #ODR_OFFSET]
	ORR R3, R3, #1<<10
	STR R3, [R2, #ODR_OFFSET]

	mov r1, #1	// about 1 us
	bl lcd_delay

	# bring E low to latch C[10]=0
	MOVW R4, #1<<10
	BIC R3, R3, R4
	STR R3, [R2, #ODR_OFFSET]

	mov r1, #1	// about 1 us
	bl lcd_delay	// about 1 us

	pop {R0-R12, PC}

# about r1 mircoseonds
		.global lcd_delay
lcd_delay: // STARTER CODE!!!
	# stack
	push {r1,lr}
	lsl r1, r1, #3
1:
	subs r1, r1, #1
	bne 1b
	# return
	pop {r1,pc}

.section .data
text0:
	.asciz "restart"
Err:
	.asciz "Err"
number:
	.asciz "9876543210"

.balign 4
