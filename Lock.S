#Author: Alex Gerson
.syntax unified
	.cpu cortex-m4
  	.thumb
	.section .text

	.global main

	.equ GPIOA_BASE, 0x40020000
	.equ GPIOB_BASE, 0x40020400
	.equ GPIOC_BASE, 0x40020800

	.equ AFRL, 0x20 // alt func low reg Port 7..0
	.equ MODER, 0x00
	.equ PUPDR, 0x0C
	.equ IDR, 0x10
	.equ ODR, 0x14
	.equ BSRR, 0x18

	.equ RCC_BASE, 0x40023800
	.equ RCC_AHB1ENR, 0x30
	.equ RCC_APB1ENR, 0x40 // TIM3
	.equ GPIOA_EN, 0b1
	.equ GPIOB_EN, 0b10
	.equ GPIOC_EN, 0b100

	# timers
	.equ TIM3_BASE, 0x40000400
	.equ TIMx_ARR, 0x2C
	.equ TIMx_CCR1, 0x34
	.equ TIMx_CCMR1, 0x18
	.equ TIMx_CCER, 0x20
	.equ TIMx_CR1, 0


	/*prompt the user to enter a password
	  when the correct password is entered via the keypad,
	  energize an LED for 2 sec, ring suc tone.
	  if wrong password is entered, ring fail tone.
	 */
main:
	bl PIEZO_init
	bl LED_init
	bl key_init
	bl lcd_init
	bl lcd_clear
	bl lcd_home
	//function definitions:
loop:
	bl lcd_clear
	bl lcd_home

	LDR R0, =start
	bl lcd_print_string
	//line2 col5 display password
	MOV R0, #1
	MOV R1, #5
	bl lcd_set_position
	BL checkPass
	//R10=0 wrong, R10=1 CORRECT
	CMP R10, #1
	IT EQ
	BLEQ suc
	CMP R10, #0
	IT EQ
	BLEQ fail

	b loop

	#function definitions starts here
PIEZO_init:
	push {R0-R9, LR}
	//enable clock to PB4
	ldr r0, =RCC_BASE
	LDR R1, [R0, #RCC_AHB1ENR]
	orr r1, r1, #GPIOB_EN
	STR r1, [R0, #RCC_AHB1ENR]
	//enable clock to TIM3
	LDR R1, [R0, #RCC_APB1ENR]
	orr r1, r1, #0b10
	STR R1, [R0, #RCC_APB1ENR]
	#alternate function mode
	ldr r4, =GPIOB_BASE
	LDR r5, [r4, #MODER]
	mov r6, #0b10
	bfi r5, r6, #8, #2
	STR r5, [r4, #MODER]
	//AF2
	LDR r5, [r4, #AFRL]
	mov r6, #0b0010 //AF2
	bfi r5, r6, #16, #4
	STR r5, [r4, #AFRL]

	pop {R0-R9, PC}

checkPass:
	push {R0-R9, LR}
	//R1 hold password word(32bit)
	LDR R2, =password
	LDR R1, [R2]
	//R5 hold input char
	LDR R4, =enteredPASS
	#R9 sentinel value
	mov R9, #4
1:
	LDRB R5, [R4]

	bl key_getchar
	bl lcd_data
	MOV R5, R0
	STRB R5, [R4] //display input then write to mem

	ADD R4, R4, #1 // input char advance by 1

	subs R9, R9, #1
	bne 1b
	#compare input with "ABCD"
	LDR R4, =enteredPASS
	LDR R5, [R4]
	//R10 = 1 if password correct, otherwise 0
	CMP R5, R1
	ITE EQ
	MOVEQ R10, #1
	MOVNE R10, #0
	#clear input string after check
	MOVW R5, #0X2020
	MOVT R5, #0X2020

	STR R5, [R4]
	pop {R0-R9, PC}

tone:
	push {R0-R9, LR}
	//R10=0 wrong, R10=1 CORRECT
	LDR R4, =TIM3_BASE
	//1. SET CLOCK, default prescaler
	//2. write # of ticks to ARR CCR-CCR

	CMP R10, #1
	ITE EQ
	#4000 TICKS for 2000Hz
	moveq R5, #4000
	#16000 ticks for 500Hz
	movne R5, #16000
	str R5, [R4, #TIMx_ARR]
	str R5, [R4, #TIMx_CCR1]
	//3. set CCxIE and/or DE, no interrupt
	//4. select output mode - toggle
	movw R5, #(0b011<<4) //OCIM=011-TOGGLE ON MATCH
	STR R5, [R4, #TIMx_CCMR1]

	#compare output enable
	movw r5, #(1) // CC1E=1
	STR R5, [R4, #TIMx_CCER]

	//5. enable counter
	movw R5, #(1)//CEN=1
	STR R5, [R4, #TIMx_CR1]

	pop {R0-R9, PC}

suc:
	push {R0-R12, LR}
	BL sucLED
	bl tone

	movw R1, #0x8480 // 2 sec delay
	movt R1, #0x1E
	bl lcd_delay
	BL offLED
	pop {R0-R12, PC}

fail:
	push {R0-R12, LR}
	BL failLED
	bl tone

	movw R1, #0x8480 // 2 sec delay
	movt R1, #0x1E
	bl lcd_delay
	BL offLED
	pop {R0-R12, PC}

sucLED:
	push {R0-R12, LR}
	LDR R0, =GPIOB_BASE
	LDR R1, [R0, #ODR]
	//turn on B10..5 & B15..12
	mov R2, #0b111111
	BFI R1, R2, #5, #6
	BFI R1, R2, #12, #4
	STR R1, [R0, #ODR]
	pop {R0-R12, PC}
offLED:
	push {R0-R12, LR}
	LDR R0, =GPIOB_BASE
	LDR R1, [R0, #ODR]
	//turn OFF B10..5 & B15..12
	mov R2, #0
	BFI R1, R2, #5, #6
	BFI R1, R2, #12, #4
	STR R1, [R0, #ODR]
	pop {R0-R12, PC}
failLED:
	push {R0-R12, LR}
	LDR R0, =GPIOB_BASE
	LDR R1, [R0, #ODR]
	//001 pattern B10..5 & B15..12
	mov R2, #0b001001
	BFI R1, R2, #5, #6
	BFI R1, R2, #12, #4
	STR R1, [R0, #ODR]
	pop {R0-R12, PC}


	.section .data
start:
	.asciz "enter password"
keys:
	.asciz "123A456B789C*0#D"
err:
	.asciz "    wrong!!!"
password:
	.asciz "ABCD"
enteredPASS:
	.asciz "!!!!"
.balign 4
