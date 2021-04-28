#include "mul.h"
#include <stdio.h> 
#include <utility>

int bit_extract(int addr, int high, int low)  // this range is inclusive
{
    int mask = high == 31 ? 0xFFFFFFFF : (1 << (high + 1)) - 1;
    mask = mask - ((1 << low) - 1);
    return ((mask & addr) >> low);
}

void mulBF16(int a, int b, int & c) {

#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE s_axilite port=a
#pragma HLS INTERFACE s_axilite port=b
#pragma HLS INTERFACE s_axilite port=c

	int a_t, b_t, c_t;
	int exponent_a = 0, exponent_b = 0, exponent_c = 0, exponent_c_raw = 0;
	int mantissa_a = 0, mantissa_b = 0, mantissa_c = 0, raw_m_ab = 0;
	int sign_bit_a = 0, sign_bit_b = 0, sign_bit_c = 0; 

	a_t = a;
	b_t = b;

/* you need to complete this code */
	sign_bit_a = bit_extract(a_t, 15, 15);
	sign_bit_b = bit_extract(b_t, 15, 15);
	exponent_a = bit_extract(a_t, 14, 7);
	exponent_b = bit_extract(b_t, 14, 7);
	// exponent_a = ((a_t >> 7) & 0xff);
	// exponent_b = ((a_t >> 7) & 0xff);

	mantissa_a = (1 << 7) | bit_extract(a_t, 6, 0);
	mantissa_b = (1 << 7) | bit_extract(b_t, 6, 0);

	sign_bit_c = sign_bit_a ^ sign_bit_b;
	exponent_c = (exponent_a + exponent_b - 127) & 0xFF;
	mantissa_c = mantissa_a * mantissa_b;

	if ((mantissa_c >> 15) & 1 == 1) {
		exponent_c += 1;
		mantissa_c = (mantissa_c >> 8) & 0x7f;
	} else {
		mantissa_c = (mantissa_c >> 7) & 0x7f;
	}


	c_t = (sign_bit_c << 15) | (exponent_c << 7) | mantissa_c;

	// handles one operand being zero
	if (a_t == 0 || a_t == 0x8000 || b_t == 0 || b_t == 0x8000) {
		c_t = 0;
	}

	c = c_t;

	return;
}

void mulFP(float a, float b, float &c) {

	c = a*b;
}
