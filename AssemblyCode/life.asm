// Start with shared definitions...
include "Megaprocessor_defs.asm";

// *************************************
// variables....
        org 0x4000;
        
// We shall use two working arrays to hold two copies of our universe. The universe is 32 wide
// by 64 tall. It is wraparound. To deal with the wraparound we shall replicate the outside edge
// so our working arrays need to be 34 by 66.
world_a:    ds  34*66;
world_a_org equ world_a + 34 + 1;
world_b:    ds  34*66;
world_b_org equ world_b + 34 + 1;
use_b:      db;
dst_ptr:    dw;
src_ptr:    dw;
disp_ptr:   dw;
row_count:  db;
col_count:  db;

// **************************************
// code....
            org  0;
        
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

// *********************
// The program....            
start:
        // give ourselves a stck...
        ld.w    r0,#0x7000;
        move    sp,r0;

        jsr init;
        xor r0,r0;
        st.b    use_b,r0; // so start with A
main_loop:
        jsr display_world;
        jsr update_world;
        ld.b    r0,use_b;
        ld.b    r1,#1;
        xor r1,r0;
        st.b    use_b,r1;
        jmp main_loop;

// *********************
// To display a world we extract the core of the current world and format it
// for the internal RAM.
display_world:
        ld.w    r3,#world_a_org;
        ld.b    r0,use_b;
        beq dw1;
        ld.w    r3,#world_b_org;
dw1:
        ld.w    r2,#INT_RAM_START;
        st.w    disp_ptr,r2;
        xor r0,r0;
        st.b    row_count,r0;
dw4:
        // inner row loop
        xor r0,r0;  // r0 is loop counter
dw5:
        xor r2,r2;  // r2 is accumulator
dw3:
        lsr r2,#1;
        ld.b    r1,(r3++);
        beq dw2;
        ld.b    r1,#128;
        add r2,r1;
dw2:
        addq    r0,#1;
        // see if we have a byte to write
        ld.b    r1,#7;
        and r1,r0;
        bne dw3;    // no so do next bit
        
        // yes, so write it to display
        move    r1,r2;
        ld.w    r2,disp_ptr;
        st.b    (r2++),r1;
        st.w    disp_ptr,r2;
        
        // now see if done end of row
        ld.b    r1,#32;
        cmp r0,r1;
        bne dw5;    // no, so carry on.
        
        // end of row, so incr count and see if finished...
        addq    r3,#2;  // skip src ptr over replicating lines
        ld.b    r2,row_count;
        addq    r2,#1;
        st.b    row_count,r2;
        ld.b    r0,#64;
        cmp r0,r2;
        bne dw4;    // not finished yet
        
        // all done
        ret;
        
// ***********************************
// initialise world A to be blank with a blinker and a glider...
init:
        
            xor     r0,r0;
            ld.w    r2,#world_a;
            ld.w    r1,#34*66/2;
clr_loop:
            st.w    (r2++),r0;
            addq    r1,#-2;
            bne     clr_loop;
            
        ld.b    r0,#1;
        st.b    world_a_org + 10 + 10*34,r0;
        st.b    world_a_org + 11 + 10*34,r0;
        st.b    world_a_org + 12 + 10*34,r0;

        st.b    world_a_org + 20 + 10*34,r0;
        st.b    world_a_org + 20 + 11*34,r0;
        st.b    world_a_org + 20 + 12*34,r0;
        
        st.b    world_a_org + 17 + 30*34,r0;
        st.b    world_a_org + 15 + 31*34,r0;
        st.b    world_a_org + 17 + 31*34,r0;
        st.b    world_a_org + 16 + 32*34,r0;
        st.b    world_a_org + 17 + 32*34,r0;

        ret;

// ***********************************
// create a new generation in alternate universe
update_world:
        jsr init_update;
        
        ld.w    r0,#-35;
        jsr acc_field;
        ld.w    r0,#-34;
        jsr acc_field;
        ld.w    r0,#-33;
        jsr acc_field;
        
        ld.w    r0,#-1;
        jsr acc_field;
//      ld.b    r0,#0;
//      jsr acc_field;
        ld.b    r0,#1;
        jsr acc_field;
        
        ld.b    r0,#33;
        jsr acc_field;
        ld.b    r0,#34;
        jsr acc_field;
        ld.b    r0,#35;
        jsr acc_field;
        
        jsr life_death;
        
        ret;

// **********************************
// to init calculation we extend edges of world to handle
// wraparond, and init the accumulation to original world.
init_update:
        ld.w    r3,#world_a_org;
        ld.w    r2,#world_b_org;
        ld.b    r0,use_b;
        beq iu1;
        ld.w    r3,#world_b_org;
        ld.w    r2,#world_a_org;
iu1:
        st.w    src_ptr,R3;
        st.w    dst_ptr,R2;

        // TL corner comes from BR
        ld.w    r1,#63*34+31;
        move    r2,r3;
        add r2,r1;
        ld.b    r0,(r2);
        ld.w    r1,#-35;
        move    r2,r3;
        add r2,r1;
        st.b    (r2),r0;

        // TR corner comes from BL
        ld.w    r1,#64*34;
        move    r2,r3;
        add r2,r1;
        ld.b    r0,(r2);
        ld.w    r1,#-2;
        move    r2,r3;
        add r2,r1;
        st.b    (r2),r0;

        // BL corner comes from TR
        ld.w    r1,#31;
        move    r2,r3;
        add r2,r1;
        ld.b    r0,(r2);
        ld.w    r1,#64*34-1;
        move    r2,r3;
        add r2,r1;
        st.b    (r2),r0;

        // BR corner comes from TL
        ld.w    r1,#0;
        move    r2,r3;
        add r2,r1;
        ld.b    r0,(r2);
        ld.w    r1,#64*34+32;
        move    r2,r3;
        add r2,r1;
        st.b    (r2),r0;

        // top edge goes to bottom
        ld.w    r2,src_ptr;
        ld.w    r3,src_ptr;
        ld.w    r1,#64*34;
        add r3,r1;
        ld.b    r1,#32;
iu2:
        ld.b    r0,(r2++);
        st.b    (r3++),r0;
        addq    r1,#-1;
        bne iu2;

        // bottom edge goes to top
        ld.w    r2,src_ptr;
        ld.w    r1,#63*34;
        add r2,r1;
        ld.w    r3,src_ptr;
        ld.w    r1,#-34;
        add r3,r1;
        ld.b    r1,#32;
iu3:
        ld.b    r0,(r2++);
        st.b    (r3++),r0;
        addq    r1,#-1;
        bne iu3;

        // left edge goes to right
        ld.w    r2,src_ptr;
        ld.w    r3,src_ptr;
        ld.w    r1,#32;
        add r3,r1;
        ld.b    r1,#64;
iu4:
        ld.b    r0,(r2);
        st.b    (r3),r0;
        ld.b    r0,#34;
        add r2,r0;
        add r3,r0;
        addq    r1,#-1;
        bne iu4;

        // right edge goes to left
        ld.w    r2,src_ptr;
        ld.w    r1,#31;
        add r2,r1;
        ld.w    r3,src_ptr;
        ld.w    r1,#-1;
        add r3,r1;
        ld.b    r1,#64;
iu5:
        ld.b    r0,(r2);
        st.b    (r3),r0;
        ld.b    r0,#34;
        add r2,r0;
        add r3,r0;
        addq    r1,#-1;
        bne iu5;


        // now copy core of src world to dst to act as init of accum
        ld.w    r2,src_ptr;
        ld.w    r3,dst_ptr;
        ld.b    r0,#64;
        st.b    row_count,r0;
iu6:
        ld.b    r0,#16; // we'll do copy as words so tice as quick
iu7:
        ld.w    r1,(r2++);
        st.w    (r3++),r1;
        addq    r0,#-1;
        bne iu7;
        addq    r2,#+2;
        addq    r3,#2;
        ld.b    r1,row_count;
        addq    r1,#-1;
        st.b    row_count,r1;
        bne iu6;
        
        ret;
        
// *****************************************
// here we accumulate counts from neighbours...
// The offset will be in R0.
acc_field:
        ld.w    r2,src_ptr;
        add r2,r0;
        ld.w    r3,dst_ptr;
        ld.b    r0,#64;
        st.b    row_count,r0;
af1:
        ld.b    r0,#16; // we'll do copy as words so twice as quick
        st.b    col_count,r0;
af2:
        ld.w    r1,(r2++);
        ld.w    r0,(r3);
        add r1,r0;  // we can add the two bytes in parallel as a word as there is no danger of overflow
        st.w    (r3++),r1;
        ld.b    r0,col_count;
        addq    r0,#-1;
        st.w    col_count,r0;
        bne af2;
        addq    r2,#+2;
        addq    r3,#2;
        ld.b    r1,row_count;
        addq    r1,#-1;
        st.b    row_count,r1;
        bne af1;
        
        ret;

// ***********************************
// here we look at the accumulator to see if we have life or death..
life_death:
        ld.w    r2,src_ptr;
        ld.w    r3,dst_ptr;
        ld.b    r0,#64;
        st.b    row_count,r0;
ld1:
        ld.b    r0,#32;
        st.b    col_count,r0;
ld2:
        ld.b    r1,(r3);
        ld.b    r0,#3;
        cmp r0,r1;
        bne ld3;
        // a count of 3 is live
        ld.b    r0,#1;
        st.b    (r3++),r0;
        addq    r2,#1;
        jmp ld4;
ld3:
        // a count of 4 means retain current
        ld.b    r0,#4;
        cmp r0,r1;
        bne ld5;
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        jmp ld4;
ld5:
        // a count not 3 or 4 meqns death
        xor r1,r1;
        st.b    (r3++),r1;
        addq    r2,#1;
        // drop thru...

ld4:
        ld.b    r0,col_count;
        addq    r0,#-1;
        st.b    col_count,r0;
        bne ld2;
        
        addq    r2,#2;
        addq    r3,#2;
        
        ld.b    r0,row_count;
        addq    r0,#-1;
        st.b    row_count,r0;
        bne ld1;
        
        ret;
        
// *******************************************************