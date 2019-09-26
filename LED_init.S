#Author: Alex Gerson
#Assembler Directive
  	.syntax unified
  	.cpu cortex-m4
  	.thumb
 		.section .text

    .global LED_init

    .equ RCCBSE, 0x40023800
    .equ RCC_AHB1ENR, 0x40023830
    .equ GPIOBEN, 1<<1

    .equ GPIOB_MODE, 0x40020400
   #.equ GPIOB_ODR, 0x40020414
   #.equ GPIOB_BSRR, 0x40020418

#program entry point
LED_init:

	push {r0-r4, LR}

#Gather Initial Data Address

	#LED Pins: PB[15..12], PB[10..5]

#Enable Clock for GPIOB
	#r0<- RCC bse addr
	ldr r0, =RCC_AHB1ENR

	#RMW - enable GPIOBEN
	ldr r1, [r0]
	orr r1, r1, #GPIOBEN
	str r1, [r0]

#Set output Modes for GPIOB
	ldr r0, =GPIOB_MODE
	LDR R1, [R0]
	//output 01 for B10..5 & B15..12
	mov R2, #0b010101010101
	BFI R1, R2, #10, #12
	BFI R1, R2, #24, #8
	STR	R1, [R0]
	pop {r0-r4, PC}

