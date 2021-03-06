#
# Copyright 2002 Free Software Foundation, Inc.
#
# This file is part of GNU Radio
#
# GNU Radio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# GNU Radio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Radio; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street,
# Boston, MA 02110-1301, USA.
#


# input and taps are guarenteed to be 16 byte aligned.
# n_2_ccomplex_blocks is != 0
#
#
#  ccomplex_dotprod_generic (const float *input,
#                         const float *taps, unsigned n_2_ccomplex_blocks, float *result)
#  {
#    float sum0 = 0;
#    float sum1 = 0;
#    float sum2 = 0;
#    float sum3 = 0;
#
#    do {
#
#      sum0 += input[0] * taps[0] - input[1] * taps[1];
#      sum1 += input[0] * taps[1] + input[1] * taps[0];
#      sum2 += input[2] * taps[2] - input[3] * taps[3];
#      sum3 += input[2] * taps[3] + input[3] * taps[2];
#
#      input += 4;
#      taps += 4;
#
#    } while (--n_2_ccomplex_blocks != 0);
#
#
#    result[0] = sum0 + sum2;
#    result[1] = sum1 + sum3;
#  }
#

# TODO: prefetch and better scheduling

#include "assembly.h"

	.file	"ccomplex_dotprod_3dnowext.S"
	.version	"01.01"
.text
	.p2align 4
.globl GLOB_SYMB(ccomplex_dotprod_3dnowext)
	DEF_FUNC_HEAD(ccomplex_dotprod_3dnowext)
GLOB_SYMB(ccomplex_dotprod_3dnowext):
	pushl	%ebp
	movl	%esp, %ebp
	movl	8(%ebp), %eax		# input
	movl	12(%ebp), %edx		# taps
	movl	16(%ebp), %ecx		# n_2_ccomplex_blocks

	# zero accumulators

	pxor	%mm6, %mm6		# mm6 = 0 0
	pxor	%mm7, %mm7		# mm7 = 0 0

	movq	0(%eax), %mm0
	movq	0(%edx), %mm2

	shrl	$1, %ecx		# ecx = n_2_ccomplex_blocks / 2

	movq	8(%eax), %mm1
	movq	8(%edx), %mm3


	jmp	.L1_test

	#
	# 4 taps / loop
	# something like ?? cycles / loop
	#

	.p2align 4
.Loop1:

# complex prod: C += A * B,  w/ temp Z
#
#	movq	0(%eax), %mmA
#	movq	0(%edx), %mmB
#	pswapd	%mmA, %mmZ
#	pfmul	%mmB, %mmA
#	pfmul	%mmZ, %mmB
#	pfpnacc	%mmB, %mmA
#	pfadd	%mmA, %mmC


# A=mm0, B=mm2, Z=mm4
# A'=mm1, B'=mm3, Z'=mm5

	pswapd	%mm0, %mm4
	pfmul	%mm2, %mm0
	pswapd	%mm1, %mm5
	pfmul	%mm4, %mm2
	pfmul	%mm3, %mm1
	pfpnacc	%mm2, %mm0
	pfmul	%mm5, %mm3
	movq	16(%edx), %mm2
	pfpnacc	%mm3, %mm1
	movq	24(%edx), %mm3

	pfadd	%mm0, %mm6
	movq	16(%eax), %mm0
	pfadd	%mm1, %mm7
	movq	24(%eax), %mm1

# unroll

	pswapd	%mm0, %mm4
	pfmul	%mm2, %mm0
	pswapd	%mm1, %mm5
	pfmul	%mm4, %mm2
	pfmul	%mm3, %mm1
	pfpnacc	%mm2, %mm0
	pfmul	%mm5, %mm3
	movq	32(%edx), %mm2
	pfpnacc	%mm3, %mm1
	movq	40(%edx), %mm3

	pfadd	%mm0, %mm6
	movq	32(%eax), %mm0
	pfadd	%mm1, %mm7
	movq	40(%eax), %mm1

	addl	$32, %edx
	addl	$32, %eax

.L1_test:
	decl	%ecx
	jge	.Loop1

	# We've handled the bulk of multiplies up to here.
	# Let's see if original n_2_ccomplex_blocks was odd.
	# If so, we've got 2 more taps to do.

	movl	16(%ebp), %ecx		# n_2_ccomplex_blocks
	andl	$1, %ecx
	je	.Leven

	# The count was odd, do 2 more taps.
	# Note that we've already got mm0/mm2 & mm1/mm3 preloaded
	# from the main loop.

# A=mm0, B=mm2, Z=mm4
# A'=mm1, B'=mm3, Z'=mm5

	pswapd	%mm0, %mm4
	pfmul	%mm2, %mm0
	pswapd	%mm1, %mm5
	pfmul	%mm4, %mm2
	pfmul	%mm3, %mm1
	pfpnacc	%mm2, %mm0
	pfmul	%mm5, %mm3
	pfpnacc	%mm3, %mm1

	pfadd	%mm0, %mm6
	pfadd	%mm1, %mm7

.Leven:
	# at this point mm6 and mm7 contain partial sums

	pfadd	%mm7, %mm6

	movl	20(%ebp), %eax		# result
	movq	%mm6, (%eax)

	femms

	popl	%ebp
	ret

FUNC_TAIL(ccomplex_dotprod_3dnowext)
	.ident	"Hand coded x86 3DNow!Ext assembly"


#if defined(__linux__) && defined(__ELF__)
.section .note.GNU-stack,"",%progbits
#endif
