/*
  * Mini2440  initialise
 *  Copyright (c) 2014 Lee <Tofulee@163.com>
 *
 * See file CREDITS for list of people who contributed to this
 * project.
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
#include <linux/stddef.h>
#define MEM_REG_BASE  ((volatile unsigned long *)0x48000000)
#define CLK_REG_BASE  ((volatile unsigned long *)0x4c000000)
/*clock registers*/
#define LOCKTIME      0
#define MPLLCON       1
#define UPLLCON        2
#define CLKCON          3
#define CLKSLOW       4
#define CLKDIVN        5

#define MPLL_400MHZ     ((0x5c<<12)|(0x01<<4)|(0x01))

 void setup_ram()
 {
	MEM_REG_BASE[0] = 0x22011110;    
	MEM_REG_BASE[1] = 0x00000700;     
	MEM_REG_BASE[2] = 0x00000700;    
	MEM_REG_BASE[3] = 0x00000700;    
	MEM_REG_BASE[4] = 0x00000700;   
	MEM_REG_BASE[5] = 0x00000700;     
	MEM_REG_BASE[6] = 0x00000700;    
	MEM_REG_BASE[7] = 0x00018005;     
	MEM_REG_BASE[8] = 0x00018005;     
	MEM_REG_BASE[9] = 0x008C07A3;     
	MEM_REG_BASE[10] = 0x000000B1;   
	MEM_REG_BASE[11] = 0x00000030;     
	MEM_REG_BASE[12] = 0x00000030;    
 }
 
 
static int is_boot_nor()
{
	#define TEST (*(volatile int *)0)
	int tmp = TEST;
	TEST = 0xabcdef;
	if (TEST == 0xabcdef){
		TEST = tmp;
		return 0;
	 }else{
		TEST = tmp;
		return 1;
	 }
}

void clear_bss(void)
{
        extern int __bss_start, __bss_end;
        int *p = &__bss_start;

        for (; p < &__bss_end; p++)
                *p = 0;
}

extern int nand_open(void*,void*);
extern int nand_read(unsigned int,void *,unsigned int);
void copy2ram(char *src, char *dest, unsigned int len)
{
    unsigned long cnt;
    if (is_boot_nor()){
        for (cnt = 0; cnt < len; cnt++){
            dest[cnt] = src[cnt];
        }
    }else{
	nand_open(NULL,NULL);
	nand_read(0,dest,len);
    }
}

void disable_wdg(void)
{
    #define WTDG_BASE (*(volatile unsigned long *)0x53000000)
    WTDG_BASE = 0;
}
