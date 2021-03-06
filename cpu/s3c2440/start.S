/*
 *  Copyright (c) 2014	Lee <TofuleeSoil@163.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

/*
 *                                      (offset)
 *       --------------------------     
 *       |     Stack     (215KB)  |
 *       --------------------------          
 *       |     IRQ Stack  (4KB)   | <------------------------ CONFIG
 *       --------------------------     
 *       |     FIQ Stack  (4KB)   | <------------------------ CONFIG
 *       --------------------------     
 *       |     BAD STACK  (4KB)   |
 *       --------------------------     
 *       |     BSS and Reserved   |
 *       --------------------------     
 *       |         U-Boot         |
 *       --------------------------     0x30000000
 */

#include <config.h>

#define MPLL_400MHZ     ((0x5c<<12)|(0x01<<4)|(0x01))
#define WTREG_BASE	0x53000000
#define SDRAM_BASE	0x30000000
#define MEM_CTL_BASE	0x48000000

.global _start
_start: b       reset
        ldr     pc, _undefined_instruction
        ldr     pc, _software_interrupt
        ldr     pc, _prefetch_abort
        ldr     pc, _data_abort
        ldr     pc, _not_used
        ldr     pc, _irq
        ldr     pc, _fiq

_undefined_instruction: .word undefined_instruction
_software_interrupt:    .word software_interrupt
_prefetch_abort:        .word prefetch_abort
_data_abort:            .word data_abort
_not_used:              .word not_used
_irq:                   .word irq
_fiq:                   .word fiq

        .balignl 16,0xdeadbeef

.globl SVC_STACK_START
SVC_STACK_START:
	.word __stack + SVC_STACK_SIZE/*215KB*/

.globl IRQ_STACK_START
IRQ_STACK_START:
        .word SVC_STACK_START + IRQ_STACK_SIZE/*4KB*/

.globl FIQ_STACK_START
FIQ_STACK_START:
        .word IRQ_STACK_START + FIQ_STACK_SIZE/*4KB*/
.globl BAD_STACK_START
BAD_STACK_START:
	.word FIQ_STACK_START + BAD_STACK_SIZE/*4KB*/
.globl START
START:
	.word _start
.globl _bss_start
_bss_start:
	.word __bss_start

reset:
    ldr	    r0,=WTREG_BASE
    mov	    r1,#0
    str	    r1,[r0]
    
    mrs     r0, cpsr
    bic     r0, r0, #0x1f
    orr     r0, r0, #0xd3
    msr     cpsr, r0
   
    bl	   uart_open 
    ldr    r0, =0x4c000014
    mov    r1, #0x05;			
    str    r1, [r0]
    mrc	   p15, 0, r1, c1, c0, 0		
    orr	   r1, r1, #0xc0000000			

    mcr	   p15, 0, r1, c1, c0, 0		
    ldr    r0, =0x4c000004
    ldr    r1, =MPLL_400MHZ
    str    r1, [r0]
    
    ldr	   sp,SVC_STACK_START
    bl	   setup_ram   
 
    adr	   r0,_start
    ldr    r1,START
    ldr    r2,_bss_start
    sub    r2,r2,r1
    cmp	   r0,r1
    blne   copy2ram

  
    bl     clear_bss
    ldr    pc,=user_main

@
@ IRQ stack frame.
@
#define S_FRAME_SIZE	72

#define S_OLD_R0	68
#define S_PSR		64
#define S_PC		60
#define S_LR		56
#define S_SP		52

#define S_IP		48
#define S_FP		44
#define S_R10		40
#define S_R9		36
#define S_R8		32
#define S_R7		28
#define S_R6		24
#define S_R5		20
#define S_R4		16
#define S_R3		12
#define S_R2		8
#define S_R1		4
#define S_R0		0

#define MODE_SVC	0x13
#define I_BIT		0x80

/*
 * use bad_save_user_regs for abort/prefetch/undef/swi ...
 * use irq_save_user_regs / irq_restore_user_regs for IRQ/FIQ handling
 */

	.macro	bad_save_user_regs

	sub	sp, sp, #S_FRAME_SIZE
	stmia	sp, {r0 - r12}			@ Calling r0-r12
	ldr	r2, IRQ_STACK_START

	ldmia	r2, {r2 - r3}			@ get pc, cpsr

	add	r0, sp, #S_FRAME_SIZE		@ restore sp_SVC

	add	r5, sp, #S_SP
	mov	r1, lr

	stmia	r5, {r0 - r3}			@ save sp_SVC, lr_SVC, pc, cpsr
	mov	r0, sp
	.endm

	.macro	irq_save_user_regs
	sub	sp, sp,#S_FRAME_SIZE
	stmia	sp, {r0 - r12}			@ Calling r0-r12
	add	r7, sp, #S_PC
	stmdb	r7, {sp, lr}^			@ Calling SP, LR
	str	lr, [r7, #0]			@ Save calling PC
	mrs	r6, spsr
	str	r6, [r7, #4]			@ Save CPSR
	str	r0, [r7, #8]			@ Save OLD_R0
	mov	r0, sp
	.endm

	.macro	irq_restore_user_regs
	ldmia	sp, {r0 - lr}^			@ Calling r0 - lr
	mov	r0, r0
	ldr	lr, [sp, #S_PC]			@ Get PC
	/* return & move spsr_svc into cpsr */
	subs	pc, lr, #4
	.endm

	.macro get_bad_stack
	
	ldr	r13, BAD_STACK_START		@ setup our mode stack

	str	lr, [r13]			@ save caller lr / spsr
	mrs	lr, spsr
	str	lr, [r13, #4]			@ save spsr
	
	mov	r13, #MODE_SVC			@ prepare SVC-Mode
	@ msr	spsr_c, r13
	msr	spsr, r13
	mov	lr, pc
	movs	pc, lr
	.endm

	.macro get_irq_stack			@ setup IRQ stack
	ldr	sp, IRQ_STACK_START
	.endm

	.macro get_fiq_stack			@ setup FIQ stack
	ldr	sp, FIQ_STACK_START
	.endm

/*
 * exception handlers
 */
	.align  5
undefined_instruction:
	/*get our satck pointer*/
	get_bad_stack
	bad_save_user_regs
	bl	do_undefined_instruction

	.align	5
software_interrupt:
	get_bad_stack
	bad_save_user_regs
	bl	do_software_interrupt

	.align	5
prefetch_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_prefetch_abort

	.align	5
data_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_data_abort

	.align	5
not_used:
	get_bad_stack
	bad_save_user_regs
	bl	do_not_used


	.align	5
irq:
	get_irq_stack
	irq_save_user_regs
	bl	do_irq
	irq_restore_user_regs

	.align	5
fiq:
	get_fiq_stack
	/* someone ought to write a more effiction fiq_save_user_regs */
	irq_save_user_regs
	bl	do_fiq
	irq_restore_user_regs

