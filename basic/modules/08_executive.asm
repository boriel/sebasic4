;	// SE Basic IV 4.2 Cordelia
;	// Copyright (c) 1999-2020 Source Solutions, Inc.

;	// SE Basic IV is free software: you can redistribute it and/or modify
;	// it under the terms of the GNU General Public License as published by
;	// the Free Software Foundation, either version 3 of the License, or
;	// (at your option) any later version.
;	// 
;	// SE Basic IV is distributed in the hope that it will be useful,
;	// but WITHOUT ANY WARRANTY; without even the implied warranty o;
;	// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;	// GNU General Public License for more details.
;	// 
;	// You should have received a copy of the GNU General Public License
;	// along with SE Basic IV. If not, see <http://www.gnu.org/licenses/>.

;	// --- EXECUTIVE ROUTINES --------------------------------------------------

;	// +-------+-------+-----------+---------+-----+---------+--
;	// | basic | basic | system    | channel | $80 | BASIC   |
;	// | (ROM) | (RAM) | variables | info    |     | program |
;	// +-------+-------+-----------+---------+-----+---------+--
;	// ^       ^       ^           ^               ^         ^
;	// $0000   $4000   $5BBA       $5CB6 (CHANS)   PROG      VARS

;	//  --+-----------+-----+------------+------+-----+-------+------+--
;	//    | variables | $80 | edit line  | new  | $80 | input | new  |
;	//    | area      |     | or command | line |     | data  | line |
;	//  --+-----------+-----+------------+------+-----+-------+------+--
;	//    ^                 ^                         ^
;	//    VARS              E_LINE                    WORKSP

;	//  --+------------+------------+-------+---------+---------+-----+-----+
;	//    | temporary  | calculator | Spare | machine | gosub   | $00 | $3e |
;	//    | work space | stack    > |       | stack < | stack < |     |     |
;	//  --+------------+------------+-------+---------+---------+-----+-----+
;	//    ^            ^            ^       ^                         ^     ^
;	//    WORKSP       STKBOT  STKEND       SP                   RAMTOP     P_RAMT

;	// FIXME - further optimization is possible

;	// NEW command
;	org $11b7;
new:
	di;									// interrupts off
	xor a;								// LD A, 0
	dec a;								// LD A, 255
	ld de, (ramtop);					// get sysvar
	exx;								// alternate register set
	ld bc, (p_ramt);					// store
	ld de, (rasp);						// system
	ld hl, (nmiadd);					// variables
	exx;								// main register set

;	// initialization routine
;	org $11cb;
start_new:;
	ex af, af';							// store A

	ld a, %00110110;					// yellow on blue (with no ULAplus), hi-res mode
	out (scld), a;						// set it

	ld bc, paging;						// HOME bank paging
	ld a, %00011000;					// ROM 1, FBUFF 1, HOME 0
	out (c), a;							// set it

	xor a;								// set I
	ld i, a;							// to $00(ff)

	ld iyh, d;							// ramtop
	ld iyl, e;							// to IY
	ex de, hl;							// swap pointers
	ld de, k_buff;						// start of keyboard buffer to DE
	sbc hl, de;							// bytes to clear
	ld c, l;							// byte count
	ld b, h;							// to BC
	ld l, e;							// start address
	ld h, d;							// to HL
	ld (hl), 0;							// store zero in first address
	inc e;								// start address plus one to DE
	ldir;								// wipe bytes
	exx;								// alternate register set
	ld (p_ramt), bc;					// restore p_ramt
	ld (rasp), de;						// restore rasp
	ld (nmiadd), hl;					// restore nmiadd
	exx;								// main resister set
	ex af, af';							// restore A
	inc a;								// NEW command?
	jr z, ram_set;						// jump if sp
	ld bc, $0040;						// set RASP to $40
	ld (rasp), bc;						// set PIP to 0
	ld (p_ramt), iy;					// set top of RAM
	ld hl, (p_ramt);					// p-ramt to HL

ram_set:
	ld (ramtop), hl;					// HL to ramtop

;	// default NMI routine
initial:
	call flush_kb;						// flush the keyboard buffer

	ld hl, (ramtop);					// ramtop to HL
	ld (hl), $3e;						// set it to the GOSUB end marker
	dec hl;
	ld sp, hl;							// point stack to same location
	dec hl;								// (pointer moves down during PUSH)
	dec hl;								// skip two locations
	ld (err_sp), hl;					// set sysvar
	im 1;								// interrupt mode 1
	ld iy, err_nr;						// Set IY offset into sysvars
	ei;									// interrupts on
	ld a, (chans);						// coming from
	and a;								// start or new?
	ld (iy - _onerr_h), 255;			// signal on error stop
	ld a, msg_break + 1;				// prepare error
	jp nz, main_g;						// jump if NMI Break
	ld bc, 21;							// byte count
	ld de, init_chan;					// destination
	ld hl, channels;					// source
	ld (chans), hl;						// set system variable
	ex de, hl;							// swap pointers
	ldir;								// copy initial channel table
	ex de, hl;							// swap pointers
	dec hl;								// last location of channel data
	ld (datadd), hl;					// store it in sysvar
	inc hl;								// next location
	ld (vars), hl;						// store address in
	ld (prog), hl;						// vars and prog
	ld (hl), end_marker;				// store variables end marker
	inc hl;								// next location
	ld (e_line), hl;					// store address in sysvar
	ld a, %01110001;					// light gray foreground, dark blue background
	ld (bordcr), a;						// set border color
	ld (attr_p), a;						// set permanent attribute
	ld hl, $031e;						// set initial values (repdel = 30, repper = 3)
	ld (repdel), hl;					// for repdel and repper
	ld hl, initial;						// address of routine to jump to on NMI
	ld (nmiadd), hl;					// set sysvar
	dec (iy - _kstate_4);				// set kstate_4 to 255
	dec (iy - _kstate);					// set kstate to 255
	ld c, 12;							// byte count
	ld de, strms;						// destination
	ld hl, init_strm;					// source
	ldir;								// copy initial streams table
	ld (iy + _df_sz), 1;				// set lower display size
	call init_path;						// initialize path

	ld de, $ffbf;						// d=data, e=reg
	ld a, 30;							// foreground (ULAplus)
	ld bc, $bf3b;						// register select
	out (c), a;							// select it
	ld b, d;							// data select
	ld a, %10110110;					// light gray
	out (c),a;							// set it

	ld a, 22;							// foreground (Uno)
	ld b, e;							// register select
	out (c), a;							// select it
	ld b, d;							// data select
	ld a, %10110110;					// light gray
	out (c),a;							// set it

	ld a, 25;							// background
	ld b, e;							// register select
	out (c), a;							// select it
	ld a, %00000010;					// blue
	ld b, d;							// data select
	out (c),a;							// set it

	call cls;							// clear screen
	call set_min;						// set up workspace
	ld a, 2;							// channel S
	call chan_open;						// open it
	ld de, copyright;					// copyright message
	call po_asciiz_0;					// print it

	ld hl, (ramtop);					// get top of BASIC RAM
	ld de, (prog);						// get bottom of BASIC RAM
	sbc hl, de;							// subtract bottom from top
	ld b, h;							// copy result
	ld c, l;							// to BC
	call stack_bc;						// stack free RAM
	call print_fp;						// output value

	ld de, bytes_free;					// bytes free message
	call po_asciiz_0;					// print it

	xor a;								// LD A, 0; channel K
	call chan_open;						// open it
	ld de, ready;						// ready message

	call po_asciiz_0;					// print it

	call msg_pause;						// pause in case of NEW

	set 3, (iy + _flags2);				// enable CAPS LOCK

	jp main_1;							// immediate jump

;	// main execution loop
main_exec:
	ld (iy + _df_sz), 1;				// set lower screen
	call auto_list;						// auto list

main_1:
	call set_min;						// set minimum

main_2:
	xor a;								// LD A, 0;
	call chan_open;						// open channel K
	call tokenizer;						// tokenize input
	call line_scan;						// check syntax
	bit 7, (iy + _err_nr);				// correct?
	jr nz, main_3;						// jump if so
	call bell;							// error sound
	bit 4, (iy + _flags2);				// channel K?
	jr z, main_4;						// jump if not
	ld hl, (e_line);					// address error
	call remove_fp;						// remove floating point forms
	ld (iy + _err_nr), ok;				// reset error
	jr main_2;							// jump back

main_3:
	call e_line_no;						// get line number
	ld a, c;							// valid
	or b;								// line?
	jp nz, main_add;					// jump if so
	rst get_char;						// else get character
	cp ctrl_cr;							// carriage return?
	jr z, main_exec;					// jump if so
	bit 0, (iy + _flags2);				// clear whole display?
	call nz, cl_all;					// call if so
	call cls_lower;						// clear lower display
	ld a, 25;							// scroll counter value
	sub (iy + _s_posn_h);				// subtract to get true count
	ld (scr_ct), a;						// current count to A
	set 7, (iy + _flags);				// signal line execution
	ld (iy + _nsppc), 1;				// first statement
	ld (iy + _err_nr), 255;				// signal no error
	call line_run;						// interpret line

main_4:
	ld a, (err_nr);						// error number to A
	call onerr_test;					// test for ON ERROR
	ld a, (err_nr);						// get error number again
	inc a;								// increment it

main_g:
	push af;							// stack report code
	ld hl, 0;							// zero
	ld (defadd), hl;					// HL to defadd
	ld (iy + _x_ptr_h), l;				// x_ptr_h
	ld (iy + _flagx), l;				//  and flagx
	inc hl;								// LD HL, 1
	ld (strms_00), hl;					// point to channel K
	call set_min;						// clear all work areas and calculator stack
	call cls_lower;						// clear lower screen
	pop af;								// restore report code
	set 5, (iy + _vdu_flag);			// signal lower screen in use
	push af;							// store A
	ld de, rpt_mesgs;					// message table
	call po_asciiz;						// print message
	pop af;								// restore A
	and a;								// "Ok"?
	jr z, no_ln_num;					// jump if so
	ld bc, (ppc);						// get line number
	inc bc;								// line zero is stored
	inc bc;								// as $fffe
	ld a, c;							// test for
	or b;								// zero
	jr z, no_ln_num;					// jump if so
	ld de, sp_in_sp;					// address message
	call po_asciiz_0;					// print it
	ld bc, (ppc);						// get line number again
	call out_num_1;						// print it

no_ln_num:
	call clear_sp;						// clear editing area
	ld a, (err_nr);						// restore error number
	inc a;								// increase it
	jr z, main_9;						// immediate jump if successful
	ld hl, nsppc;						// HL addresses nsppc
	ld de, osppc;						// destination
	ld bc, 3;							// byte count
	bit 7, (hl);						// BREAK before jump?
	jr z, main_8;						// jump if not
	add hl, bc;							// source to subppc

main_8:
	lddr;								// copy bytes

main_9:
	ld (iy + _nsppc), 255;				// signal no jump
	jp main_2;							// immediate jump

report_ln_bf_overflow:
	ld a, line_buffer_overflow + 1;		// change message
	jp main_g;							// jump back

;	// main add subroutine
main_add:
	ld (e_ppc), bc;						// make new line current line
	ld hl, (ch_add);					// sysvar to HL
	ex de, hl;							// store it in DE
	ld hl, report_ln_bf_overflow;		// set report
	push hl;							// as return address
	ld hl, (worksp);					// worksp to HL
	scf;								// set carry flag
	sbc hl, de;							// length from end of line number to end
	push hl;							// stack length
	ld l, c;							// transfer
	ld h, b;							// to BC
	call line_addr;						// line number exists?
	jr nz, main_add1;					// jump if not
	call next_one;						// get length of old line
	call reclaim_2;						// and reclaim it

main_add1:
	pop bc;								// get length of new line in BC
	ld a, c;							// test for A
	dec a;								// line number followed
	or b;								// by carriage return
	jr z, main_add2;					// jump if so
	push bc;							// stack BC
	inc bc;								// add four
	inc bc;								// locations
	inc bc;								// for number
	inc bc;								// and length
	dec hl;								// location before destination to HL
	ld de, (prog);						// prog to DE
	push de;							// stack it
	call make_room;						// make space
	pop hl;								// unstack prog to HL
	ld (prog), hl;						// restore prog
	pop bc;								// unstack length without parameters
	push bc;							// restack
	inc de;								// end location to DE
	ld hl, (worksp);					// worksp to HL
	dec hl;								// point to
	dec hl;								// carriage return
	lddr;								// copy over line
	ld hl, (e_ppc);						// line number to HL
	ex de, hl;							// swap pointers
	pop bc;								// unstack length
	ld (hl), b;							// most significant byte of length
	dec hl;								// next
	ld (hl), c;							// least significant byte of length
	dec hl;								// next
	ld (hl), e;							// most significant byte of line number
	dec hl;								// next
	ld (hl), d;							// least significant byte of line number

main_add2:
	pop af;								// discard report return address
	jp main_exec;						// immediate jump

report_bad_io_dev:
	rst error;
	defb bad_io_device;

;	// wait key subroutine
wait_key:
	bit 5, (iy + _vdu_flag);			// does lower screen require clearing?
	jr nz, wait_key1;					// jump if not
	set 3, (iy + _vdu_flag);			// signal mode change

wait_key1:
	call input_ad;						// call input subroutine
	ret c;								// return with valid result
	jr z, wait_key1;					// loop if no key pressed
	rst error;							// else
	defb input_past_end;				// error

;	// input address subroutine
input_ad:
	exx;								// alternate register set
	push hl;							// stack HL'
	ld hl, (curchl);					// current channel to HL'
	inc hl;								// skip output
	inc hl;								// address
	jr call_sub;						// immediate jump

;	// main printing subroutine
out_code:
	ld e, '0';							// convert number
	add a, e;							// value to ASCII

print_a_2:
	exx;								// alternate register set
	push hl;							// stack HL'
	ld hl, (curchl);					// current channel to HL'

call_sub:
	ld e, (hl);							// address
	inc hl;								// to
	ld d, (hl);							// DE
	ex de, hl;							// swap pointers
	call call_jump;						// call subroutine
	pop hl;								// unstack HL'
	exx;								// main register set
	ret;								// end of subroutine

;	// channels routines
	org $1500;							// FIXME: temporary address until routines complete

;	// open stream lookup table
op_str_lu:
	defb 'K', open_k - 1 - $;			// keyboard
	defb 'S', open_s - 1 - $;			// screen
	defb 0;								// null terminator

;	// opne K subroutine
open_k:
	ld e, 1;							// data bytes 1, 0
	jr open_end;						// immediate jump

;	// opne S subroutine
open_s:
	ld e, 6;							// data bytes 6, 0
	jr open_end;						// immediate jump

open_end:
	dec bc;								// reduce length
	ld a, c;							// single
	or b;								// character?
	jp nz, report_undef_chan;			// error if not
	ld d, a;							// clear D
	pop hl;								// unstack HL
	ret;								// end of subroutine

;	// close stream lookup table
cl_str_lu:
	defb 'K', close_str - 1 - $;		// keyboard
	defb 'S', close_str - 1 - $;		// screen
	defb 0;								// null termniator

close_str:
	pop hl;								// unstack channel information pointer
	ret;								// end of routine

;	// channel code lookup table
chn_cd_lu:
	defb 'K', chan_k - 1 - $;			// keyboard
	defb 'S', chan_s - 1 - $;			// screen
	defb 0;								// null terminator

;	// channel K flag subroutine
chan_k:
	set 4, (iy + _flags2);				// signal using channel K
	set 0, (iy + _vdu_flag);			// signal lower screen
	xor a;								// clear A
	ret;								// end of subroutine

;	// channel S flag subroutine
chan_s:
	res 0, (iy + _vdu_flag);			// signal main screen
	xor a;								// clear A
	ret;								// end of subroutine

; 	// OPEN # command
open:
	rst get_char;						// get character
	cp ',';								// test for comma
	jr nz, open_nf;						// jump if no filename provided
	rst next_char;						// next character
	call expt_exp;						// expect string expression

open_nf:
	call check_end;						// end of syntax checking

	fwait;								// enter calculator
	fxch;								// swap stream number and channel code
	fce;								// exit calculator
	call str_data;						// get stream data, zero flag set if stream closed
	ld a, c;							// stream
	or b;								// closed?
	jr z, open_1;						// jump if so
	ex de, hl;							// swap pointers
	ld hl, (chans);						// base address of channel
	add hl, bc;							// channel address to HL
	inc hl;								// skip to
	inc hl;								// channel
	inc hl;								// letter
	ld a, (hl);							// put it in A

	ex de, hl;							// swap pointers
	cp 'K';								// keyboard?
	jr z, open_1;						// jump if so
	cp 'S';								// screen?
	jp nz, report_undef_strm;			// error if not

open_1:
	call open_2;						// channel address to DE
	ld (hl), e;							// store it
	inc hl;								// in
	ld (hl), d;							// stream
	ret;								// and return

open_2:
	push hl;							// stack HL
	call stk_fetch;						// get parameters
	ld a, c;							// letter
	or b;								// provided?
	jr nz, open_3;						// jump if so

report_undef_chan:
	rst error;							// else
	defb undefined_channel;				// error

open_3:
	push bc;							// stack length
	ld a, (de);							// get first character
	and %11011111;						// make upper case
	ld c, a;							// store in C
	ld hl, op_str_lu;					// address look up table
	call indexer;						// get offset
	jr nc, report_undef_chan;			// error if not found
	ld c, (hl);							// offset
	ld b, 0;							// to BC
	add hl, bc;							// real address to HL
	pop bc;								// unstack length
	jp (hl);							// immediate jump

	org $15ff
chan_open_fe:
	ld a, 254;							// open channel $fe

;	// channel open subroutine
;	// UnoDOS 3 entry point
	org $1601;
chan_open:
	add a, a;							// A * 2
	add a, 22;							// 16 + A * 2
	ld l, a;							// stream address
	ld h, kstate / 256;					// to HL
	ld e, (hl);							// output
	inc hl;								// address
	ld d, (hl);							// to DE
	ld a, e;							// stream
	or d;								// exists?
	jr nz, chan_op_1;					// jump if so

report_undef_strm:
	rst error;							// else
	defb undefined_stream;				// error

chan_op_1:
	dec de;								// reduce base address
	ld hl, (chans);						// chans to HL
	add hl, de;							// channel base address to HL

;	// channel flag subroutine
chan_flag:
	res 4, (iy + _flags2);				// signal using channel K
	ld (curchl), hl;					// base address for channel to curchl
	inc hl;								// skip
	inc hl;								// past
	inc hl;								// input
	inc hl;								// address
	ld c, (hl);							// letter to C
	ld hl, chn_cd_lu;					// HL points to lookup table
	call indexer;						// get offset for a valid code
	ret nc;								// return if not valid
	ld e, (hl);							// offset
	ld d, 0;							// to DE
	add hl, de;							// address of routine
	jp (hl);							// immediate jump

;	// make string subroutine
make_string:
	call var_end_hl;					// point to locatino before variables end marker
	push bc;							// stack BC
	call make_room;						// make room
	pop bc;								// unstack BC
	ret;								// end of subroutine

;	// make room subroutine
make_room:
	push hl;							// stack pointer
	call test_room;						// check available memory
	pop hl;								// unstack pointer
	call pointers;						// alter pointers
	ld hl, (stkend);					// new stack end to HL
	ex de, hl;							// swap pointers
	lddr;								// make room
	ret;								// end of subroutine

;	// pointers subroutine
pointers:
	push af;							// stack AF
	push hl;							// and HL
	ld hl, vars;						// address system variable
	ld a, 14;							// fourteen system pointers

ptr_next:
	ld e, (hl);							// two bytes of
	inc hl;								// current pointer
	ld d, (hl);							// to DE
	ex (sp), hl;						// swap with address of position
	and a;								// prepare for subtraction
	sbc hl, de;							// set carry if address requires updating
	add hl, de;							// restore HL
	ex (sp), hl;						// restore address of position
	jr nc, ptr_done;					// jump if no change
	push de;							// stack old value
	ex de, hl;							// swap pointers
	add hl, bc;							// add value in BC to old value
	ex de, hl;							// swap pointers
	ld (hl), d;							// store new
	dec hl;								// value in
	ld (hl), e;							// system variable
	inc hl;								// point to next system variable
	pop de;								// unstack old value

ptr_done:
	inc hl;								// point to next system variable
	dec a;								// reduce count
	jr nz, ptr_next;					// loop until done
	ex de, hl;							// old stkend to HL
	pop de;								// unstack DE
	pop af;								// unstack AF
	and a;								// prepare for subtraction
	sbc hl, de;							// difference of old stkend and position
	ld c, l;							// put it
	ld b, h;							// in BC
	inc bc;								// add one for the inclusive byte
	add hl, de;							// restore HL
	ex de, hl;							// swap pointers
	ret;								// end of subroutine

;	// collect a line number subroutine
line_zero:
	defw 0;								// zero

line_no_a:
	ex de, hl;							// swap pointers
	ld de, line_zero;					// point to line-zero

line_no:
	ld a, (hl);							// most significant byte to A
	and %11000000;						// test it
	jr nz, line_no_a;					// jump if not suitable
	ld d, (hl);							// line
	inc hl;								// number
	ld e, (hl);							// to HL
	ret;								// end of subroutine

;	// reserve subroutine
reserve:
	ld hl, (stkbot);					// stkbot to HL
	dec hl;								// last location of workspace to HL
	call make_room;						// make number of spaces in BC
	inc hl;								// point to second
	inc hl;								// new space
	pop bc;								// unstack old worksp
	ld (worksp), bc;					// restore it
	pop bc;								// unstack number of spaces
	ex de, hl;							// swap pointers
	inc hl;								// HL points to first displaced byte
	ret;								// end of subroutine

;	// set minimum subroutine
;	// UnoDOS 3 entry point
	org $16b0;
set_min:
	ld hl, (e_line);					// sysvar to HL
	ld (k_cur), hl;						// store it in k_cur
	ld (hl), ctrl_cr;					// store a carriage return
	inc hl;								// next
	ld (hl), end_marker;				// store the end marker
	inc hl;								// next
	ld (worksp), hl;					// update worksp

;	// UnoDOS 3 entry point
	org $16bf;
set_work:
	ld hl, (worksp);					// clear
	ld (stkbot), hl;					// workspace

set_stk:
	ld hl, (stkbot);					// clear
	ld (stkend), hl;					// the stack
	push hl;							// stack stkend
	ld hl, membot;						// address system variable
	ld (mem), hl;						// store it in mem
	pop hl;								// unstack stkend
	ret;								// end of subroutine

;	// test trace subroutine
test_trace:
	bit 7, (iy + _flags);				// checking syntax?
	jr z, set_work;						// jump if so
	bit 7, (iy + _flags2);				// or trace off?
	jr z, set_work;						// jump if so
	ld bc, (ppc);						// is it
	and b;								// a direct command?
	jr nz, set_work;					// jump if so
	push af;							// store A
	ld hl, vdu_flag;					// address VDU flag
	ld d, (hl);							// get a copy in D
	res 0, (hl);						// clear bit 0 of VDU flag
	ld a, '[';
	rst print_a;						// print it
	call out_num_1;						// the line number
	ld a, ']';
	rst print_a;						// print it
	pop af;								// restore A
	ld (iy + _vdu_flag), d;				// restore VDU flag
	jr set_work;						// immediate jump

;	// indexer subroutine
indexer_0:
	ld c, a;							// A to
	ld b, 0;							// BC

indexer_1:
	inc hl;								// next

indexer:
	ld a, (hl);							// first pair to A
	and a;								// null termniator?
	ret z;								// return if so
	cp c;								// matching code?
	inc hl;								// next
	jr nz, indexer_1;					// jump with incorrect code
	scf;								// set carry flag
	ret;								// end of subroutine

;	// CLOSE command
close:
	call str_data;						// get stream data

	ld d, a;							// stream to D
	ld a, c;							// is stream
	or b;								// open?
	ld a, d;							// restore stream to A

	jr nz, close_valid;					// continue if stream open
	rst error;							// else 
	defb undefined_stream;				// error

close_valid:
	call close_2;						// perform channel specific actions
	ld bc, 0;							// signal stream not in use
	ld de, $a4e2;						// handle streams 0 to 2
	ex de, hl;							// swap pointers
	add hl, de;							// set carry with streams 3 to 15
	jr c, close_1;						// jump if carry set
	ld bc, init_strm + 12;				// address table
	add hl, bc;							// find entry
	ld c, (hl);							// address
	inc hl;								// to
	ld b, (hl);							// BC

close_1:
	ex de, hl;							// swap pointers
	ld (hl), c;							// close streams 3 to 15
	inc hl;								// or set initial values
	ld (hl), b;							// for streams 0 to 2
	ret;								// end of subroutine

;	// close 2 subroutine
close_2:
	push hl;							// stack stream data address
	ld hl, (chans);						// base address of channel to HL
	add hl, bc;							// channel address

	dec hl;								// point to first byte
	ld (curchl), hl;					// update current channel
	push hl;							// HL
	pop ix;								// to IX
	ld e, c;							// offset
	ld d, b;							// to DE
	ld a, (ix + 4);						// channel leter to A

	ld hl, cl_str_lu - 1;				// address lookup table
	call indexer_0;						// get offset
	jp (hl);							// immediate jump

;	// stream data subroutine
str_data:
	call find_int1;						// get stream number
	cp 16;								// in range (0 to 15)?
	jr c, str_data1;					// jump if so
	rst error;							// else
	defb undefined_stream;				// error

str_data1:
	add a, 3;							// adjust (3 to 18)
	rlca;								// range  (6 to 36)
	ld hl, strms;						// base address of streams
	ld c, a;							// offset
	ld b, 0;							// to BC
	add hl, bc;							// stream address to HL
	ld c, (hl);							// data
	inc hl;								// bytes
	ld b, (hl);							// to BC
	dec hl;								// point to first data byte
	ret;								// end of subroutine

;	// auto list routine
auto_list:
	ld (iy + _vdu_flag), 16;			// signal automatic listing
	ld (list_sp), sp;					// store stack pointer
	call cl_all;						// clear main screen
	ld b, (iy + _df_sz);				// lower screen display file size
	set 0, (iy + _vdu_flag);			// signal lower screen
	call cl_line;						// clear lower screen
	res 0, (iy + _vdu_flag);			// signal main screen
	set 0, (iy + _flags2);				// signal screen clear
	ld de, (s_top);						// automatic line number to DE
	ld hl, (e_ppc);						// current line number to HL
	and a;								// prepare for subtraction
	sbc hl, de;							// current line number less than automatic?
	add hl, de;							// restore current line number
	jr c, auto_l_2;						// jump to update automatic number
	push de;							// stack automatic number
	call line_addr;						// get line address
	ld de, $02c0;						// start of current line
	ex de, hl;							// swap pointers
	sbc hl, de;							// estimate address
	ex (sp), hl;						// result to stack
	call line_addr;						// get line address
	pop bc;								// unstack result

auto_l_1:
	push bc;							// stack result
	call next_one;						// address of next line
	pop bc;								// unstack result
	add hl, bc;							// finished?
	jr c, auto_l_3;						// jump if so
	ex de, hl;							// swap pointers
	ld d, (hl);							// get line
	inc hl;								// number
	ld e, (hl);							// in DE
	dec hl;								// decrease pointer
	ld (s_top), de;						// store line number in sysvar
	jr auto_l_1;						// immediate jump

auto_l_2:
	ld (s_top), hl;						// store line number in sysvar

auto_l_3:
	ld hl, (s_top);						// get line number
	call line_addr;						// get address
	jr z, auto_l_4;						// jump if found
	ex de, hl;							// else use DE

auto_l_4:
	call list_all;						// exit when screen full
	res 4, (iy + _vdu_flag);			// signal automatic listing finished
	ret;								// end of subroutine

;	// LIST command
c_list:
	ld a, 2;							// use stream #2
	ld (iy + _vdu_flag), 0;				// signal normal listing
	call syntax_z;						// checking syntax?
	call nz, chan_open;					// open channel if not
	rst get_char;						// get character
	call str_alter;						// change stream?
	jr c, list_2;						// jump if unchanged
	rst get_char;						// get character
	cp ';';								// semi-colon?
	jr nz, list_9;						// jump if not
	rst next_char;						// next character

list_2:
	rst get_char;						// get character
	cp ':';								// colon?
	jr z, list_9;						// jump if so
	cp ctrl_cr;							// carraige return?
	jr z, list_9;						// jump if so
	cp ',';								// comma?
	jr z, list_3;						// jump if so
	call expt_1num;						// get number
	jr list_4;							// immediate jump

list_3:
	call use_zero;						// default start at zero
	rst get_char;						// get character

list_4:
	cp ',';								// comma?
	jr nz, list_6;						// jump if not
	rst next_char;						// next character
	call fetch_num;						// get number
	call check_end;						// check end of statement
	call find_line;						// also performs LD A, B
	or c;								// both zero?
	jr nz, list_5;						// jump if not
	ld bc, $4000;						// else BC = 16384

list_5:
	ld (t_addr), bc;					// BC to temporary pointer to parameter table
	call find_line;						// valid line number to HL and BC
	ld (strlen), bc;					// BC to string length
	jr list_7;							// immediate jump

list_6:
	call check_end;						// check end of statement
	call find_line;						// valid line number to HL and BC
	ld (strlen), bc;					// BC to string length
	ld (t_addr), bc;					// BC to temporary pointer to parameter table

list_7:
	ld hl, (strlen);					// string length to HL
	ld (e_ppc), hl;						// strlen to e_ppc
	call line_addr;						// get address of line number

list_8:
	ld de, 0;							// clear DE
	res 7, (iy + _flags);				// force edit mode
	call out_line;						// print a BASIC line
	rst print_a;						// print carriage return
	set 7, (iy + _flags);				// force runtime mode
	ld bc, (t_addr);					// emporary pointer to parameter table to BC
	call cp_lines;						// match or line after
	jr c, list_8;						// jump
	jr z, list_8;						// if so
	ret;								// else done

list_9:
	call check_end;						// check end of statement
	ld bc, 16383;						// last possible line
	ld (t_addr), bc;					// BC to temporary pointer to parameter table
	ld bc, 0;							// cleasr BC
	ld (strlen), bc;					// clear string length
	jr list_7;							// immediate jump

list_all:
	ld e, 1;							// current line not yet printed

list_all_2:
	res 7, (iy + _flags);				// force edit mode
	call out_line;						// print a BASIC line
	rst print_a;						// print carriage return
	bit 4, (iy + _vdu_flag);			// automatic listing?
	jr z, list_all_2;					// jump if not
	ld a, (df_sz);						// get display file size
	sub (iy + _s_posn_h);				// subtract current line number
	jr nz, list_all_2;					// jump until screen full
	xor e;								// e = 1 if edit line not printed
	ret z;								// jump if screen full and line printed
	push hl;							// stack poiner address
	push de;							// stack E
	ld hl, s_top;						// get sysvar
	call ln_fetch;						// next line to s_top
	pop de;								// unstack E
	pop hl;								// unstack address of next line
	jr list_all_2;						// immediate jump

;	// print a whole BASIC line subroutine
list_cursor:
	bit 4, (iy + _vdu_flag);			// automatic listing?
	ret z;								// return if not
	ld d, '>';							// set cursor
	scf;								// set carry flag
	ret;								// done

out_line:
	ld bc, (e_ppc);						// line number
	call cp_lines;						// match or line after
	ld de, 0;							// no line cursor
	call z, list_cursor;				// call with match
	rl e;								// carry in E if line before current else zero

out_line1:
	ld (iy + _breg), e;					// store line marker
	ld a, (hl);							// most significant byte of line number to A
	cp $40;								// in range? (0 to 16383)
	pop bc;								// unstack BC
	ret nc;								// return if listing finished
	push bc;							// stack BC
	call out_num_2;						// print line number with leading spaces
	inc hl;								// point to
	inc hl;								// first
	inc hl;								// command

	res 0, (iy + _flags);				// require leading spaces
	ld a, d;							// cursor to A
	and a;								// test for zero
	jr z, out_line3;					// jump if no cursor to print
	rst print_a;						// print current line cursor

out_line2:
	set 0, (iy + _flags);				// suppress leading space

out_line3:
	push de;							// stack E
	ex de, hl;							// address to DE
	res 2, (iy + _flags2);				// signal not in quotes

out_line4:
	call out_curs;						// cursor reached?
	ex de, hl;							// swap pointers
	ld a, (hl);							// character to A
	call number;						// test for hidden number marker
	inc hl;								// next
	cp ctrl_cr;							// carriage return?
	jr z, out_line5;					// jump if so
	ex de, hl;							// swap pointers
	call out_char;						// print character
	jr out_line4;						// loop until done

out_line5:
	pop de;								// unstack DE
	ret;								// end of subroutine

;	// number subroutine
number:
	cp number_mark;						// hidden number marker?
	ret nz;								// return if not
	inc hl;								// advance pointer six times
	inc hl;
	inc hl;
	inc hl;
	inc hl;
	inc hl;
	ld a, (hl);							// code to A
	ret;								// end of subroutine

;	// print cursor subroutine
out_curs:
	ld hl, (k_cur);						// address cursor
	and a;								// correct
	sbc hl, de;							// position?
	ret nz;								// return if not
	ld a, '_';							// use underline as cursor (for ncurses)
	exx;								// alternate register set
	ld hl, p_flag;						// address sysvar
	ld d, (hl);							// p_flag to D
	push de;							// stack it
	ld (hl), %00001100;					// set p_flag to inverse
	call print_out;						// print cursor
	pop hl;								// unstack p_flag to H
	ld (iy + _p_flag), h;				// restore p_flag
	exx;								// main register set
	ret;								// end of subroutine

;	// line fetch subroutine
ln_fetch:
	ld e, (hl);							// line
	inc hl;								// number
	ld d, (hl);							// to DE
	push hl;							// stack pointer (to s_top or e_ppc)
	ex de, hl;							// line number to HL
	inc hl;								// increase line number
	call line_addr;						// get address of line number
	call line_no;						// get line number
	pop hl;								// unstack pointer to system variable

ln_store:
	bit 5, (iy + _flagx);				// INPUT mode?
	ret nz;								// return if so
	ld (hl), d;							// store line
	dec hl;								// number in 
	ld (hl), e;							// system variable
	ret;								// end of subroutine

;	// printing characters in a BASIC line subroutine
out_sp_2:
	ld a, e;							// space or 255
	and a;								// test it
	ret m;								// return if no space
	jr out_char;						// print a space

out_sp_no:
	xor a;								// LD A, 0

out_sp_1:
	add hl, bc;							// trial subtraction
	inc a;								// increase A
	jr c, out_sp_1;						// loop until done
	sbc hl, bc;							// restore HL
	dec a;								// decrease A
	jr z, out_sp_2;						// jump if no subtraction possible
	jp out_code;						// immediate jump

out_char:
	cp '"';";							// quote?
	jr nz, out_ch_1;					// jump if not
	push af;							// stack character
	ld a, (flags2);						// sysvar to A
	xor %00000100;						// toggle in quotes flag
	ld (flags2), a;						// store sysvar
	pop af;								// unstack character

out_ch_1:
	rst print_a;						// print character
	ret;								// end of subroutine

;	// line address subroutine
;	// UnoDOS 3 entry point
	org $196e;
line_addr:
	push hl;							// stack line number
	ld hl, (prog);						// prog to HL
	ld e, l;							// HL to
	ld d, h;							// to DE

;	org $1974;
line_ad_1:
	pop bc;								// unstack line number in BC
	call cp_lines;						// compare with addressed line
	ret nc;								// return if carry clear
	push bc;							// stack line number
	call next_one;						// address next line
	ex de, hl;							// swap pointers
	jr line_ad_1;						// immediate jump

;	org $1980;
cp_lines:
	ld a, (hl);							// high byte of addressed number to A
	cp b;								// compare with B
	ret nz;								// return if no match
	inc hl;								// address low byte
	ld a, (hl);							// low byte to A
	dec hl;								// restore pointer
	cp c;								// compare with C
	ret;								// end of subroutine

;	// find each statement subroutine
;	// UnoDOS 3 entry point
	org $198b;
each_stmt:
	ld (ch_add), hl;					// set sysvar
	ld c, 0;							// signal quotes off

each_s_1:
	dec d;								// statement found?
	ret z;								// return if so
	rst next_char;						// next character
	cp e;								// token match?
	jr nz, each_s_3;					// jump if not
	and a;								// else clear zero and carry flags
	ret;								// and return

each_s_2:
	inc hl;								// increase pointer
	ld a, (hl);							// next code to A

each_s_3:
	call number;						// skip numbers
	ld (ch_add), hl;					// update sysvar
	cp '"';";							// quote?
	jr nz, each_s_4;					// jump if not
	dec c;								// signal quotes on

each_s_4:
	cp ':';								// colon?
	jr z, each_s_5;						// jump if so
	cp tk_then;							// THEN?
	jr nz, each_s_6;					// jump if not

each_s_5:
	bit 0, c;							// test quotes flag
	jr z, each_s_1;						// jump at statement end

each_s_6:
	cp ctrl_cr;							// carriage return?
	jr nz, each_s_2;					// jump if not
	dec d;								// decrease statement counter
	scf;								// set carry flag
	ret;								// end of subroutine

;	// next one subroutine
next_one:
	push hl;							// stack address
	ld a, (hl);							// first byte to A
	cp 64;								// next line?
	jr c, next_o_3;						// jump if so
	bit 5, a;							// next string or array variable?
	jr z, next_o_4;						// jump if so
	add a, a;							// FOR-NEXT variable?
	jp m, next_o_1;						// jump if so
	ccf;								// else long name variable

next_o_1:
	ld bc, 5;							// five locations required
	jr nc, next_o_2;					// jump if not FOR-NEXT
	ld c, 18;							// else 18 locations required

next_o_2:
	rla;								// clear carry for long name variables
	inc hl;								// increase pointer
	ld a, (hl);							// get character
	jr nc, next_o_2;					// loop unless last character
	jr next_o_5;						// immediate jump

next_o_3:
	inc hl;								// skip low byte

next_o_4:
	inc hl;								// skip high byte
	ld c, (hl);							// length
	inc hl;								// to
	ld b, (hl);							// BC
	inc hl;								// advance pointer

next_o_5:
	add hl, bc;							// point to first byte of next item
	pop de;								// unstack address of previous item

;	// difference subroutine
differ:
	and a;								// prepare for subtraction
	sbc hl, de;							// get length
	ld c, l;							// length
	ld b, h;							// to BC
	add hl, de;							// restore HL
	ex de, hl;							// swap pointers
	ret;								// end of subroutine

;	// reclaiming subroutine
reclaim_1:
	call differ;						// get required values in HL and BC

reclaim_2:
	push bc;							// stack number of bytes to reclaim
	ld a, b;							// B to A
	cpl;								// one's complement
	ld b, a;							// A to B
	ld a, c;							// C to A
	cpl;								// one's complement
	ld c, a;							// A to C
	inc bc;								// two's complement
	call pointers;						// get pointers
	ex de, hl;							// swap pointers
	pop hl;								// unstack bytes to reclaim
	add hl, de;							// address to HL
	push de;							// stack first location
	ldir;								// reclaim bytes
	pop hl;								// unstack first location
	ret;								// end of subroutine

;	// E line number subroutine
;	// UnoDOS 3 entry point
	org $19fb;
e_line_no:
	call var_end_hl;					// varaibles end marker location to HL
	ld (ch_add), hl;					// one character
	rst next_char;						// get next code
	ld hl, membot;						// address membot
	ld (stkend), hl;					// use membot as temporary stack
	call int_to_fp;						// test for digit
	call fp_to_bc;						// read digits
	jr c, e_l_1;						// number from temporary stack to BC
	ld hl, 16384;						// line range is 0 to 16383
	add hl, bc;							// add to line number in BC

e_l_1:
	jp c, report_syntax_err;			// error if overflow
	jp set_stk;							// else immediate jump

;	// report and line number printing subroutine
out_num_1:
	push de;							// stack DE
	push hl;							// and HL
	xor a;								// LD A, 0
	bit 7, b;							// edit line?
	jr nz, out_num_4;					// jump if so
	ld l, c;							// BC
	ld h, b;							// to HL
	ld e, 255;							// signal no leading spaces
	jr out_num_3;						// immediate jump

out_num_2:
	push de;							// stack DE
	ld d, (hl);							// number
	inc hl;								// to
	ld e, (hl);							// DE
	push hl;							// stack HL
	ex de, hl;							// number to HL
;	ld e, ' ';							// leading space
	ld e, $ff;							// don't print leading spaces

out_num_3:
	ld bc, -10000;						// fist digit
	call out_sp_no;						// print it
	ld bc, -1000;						// second digit
	call out_sp_no;						// print it
	ld bc, -100;						// third digit
	call out_sp_no;						// print it
	ld c, -10;							// fourth digit
	call out_sp_no;						// print it
	ld a, l;							// fifth digit

out_num_4:
	call out_code;						// print it
	pop hl;								// unstack HL
	pop de;								// and DE
	ret;								// end of subroutine
