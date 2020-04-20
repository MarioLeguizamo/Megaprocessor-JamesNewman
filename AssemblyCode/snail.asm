// Start with shared definitions...
include "Megaprocessor_defs.asm";

// *****************************************            
// variables...
        org 0x4000;
head_x:     db;
head_y:     db;
tail_x:     db;
tail_y:     db;

// *****************************************            
// Code...
        org  0;
        
// *****************************************            
// vectors
reset:       jmp    start;
             nop;
ext_int:     reti;
             nop;
             nop;
             nop;        
div_zero:    reti;
             nop;
             nop;
             nop;        
illegal:     reti;
             nop;
             nop;
             nop;

// *****************************************            
start:
        // give ourselves a stack
        ld.w    r0,#0x2000;
        move    sp,r0;
        
        jsr init;

busy_loop:
        // head
        ld.b    r0,head_x;
        ld.b    r1,head_y;
        jsr advance_ptr;
        st.b    head_x,r0;
        st.b    head_y,r1;
        jsr draw_point;

        // tail
        ld.b    r0,tail_x;
        ld.b    r1,tail_y;
        jsr advance_ptr;
        st.b    tail_x,r0;
        st.b    tail_y,r1;
        jsr draw_point;
        
        jmp busy_loop;

// ***********************************************
// Initialisation. Start by clearing down the internal RAM, and set
// up first location of snail with head and tail ptrs.
init:
        // clear our RAM
        xor     r0,r0;
        ld.w    r2,#INT_RAM_START;
        ld.w    r1,#INT_RAM_LEN;
clr_loop:
        st.w    (r2++),r0;
        addq    r1,#-2;
        bne     clr_loop;

        ld.b    r0,#1;
        ld.b    r1,#23;
        ld.b    r3,#4;
        ld.w    r2,#INT_RAM_START + 4;
i1:
        st.b    (r2),r0;
        add r2,r3;
        addq    r1,#-1;
        bne i1;

        // set up head and tail ptrs...
        xor r0,r0;
        st.b    tail_x,r0;
        st.b    tail_y,r0;
        st.b    head_x,r0;
        ld.b    r0,#23;
        st.b    head_y,r0;

        ret;
        
// ********************************************************
// advance ptr....x in r0, y in r1
advance_ptr:
        ld.b    r2,#1;
        and r2,r0;
        bne ap1;
        
        // we're on an even column, head down unless at 63 when we move over
        ld.b    r2,#63;
        cmp r2,r1;
        beq ap2;
        addq    r1,#1;
        ret;
        
        // we're on an odd column, head up unless we're at 0 when we move over
ap1:
        test    r1;
        beq ap2;
        addq    r1,#-1;
        ret;
ap2:
        addq    r0,#1;
        ld.b    r2,#0x1F;
        and r0,r2;
        ret;
        
// ********************************************************
// draw point...x in r0, y in r1
draw_point:
        // first we construct the byte ptr
        move    r2,r0;
        ld.w    r3,#INT_RAM_START;
        lsr r2,#3; // bit address to byte
        add r3,r2;
        lsl r1,#2; // y os byte offset
        add r3,r1;
        // and now the mask
        ld.b    r1,#1;
        ld.b    r2,#7;
        and r0,r2;
        lsl r1,r0;
        
        // and now apply
        ld.b    r0,(r3);
        xor r0,r1;
        st.b    (r3),r0;
        
        ret;

// ********************************************************
