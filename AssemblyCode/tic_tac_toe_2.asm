// Start with shared definitions...
include "Megaprocessor_defs.asm";

// *************************************
// tables and variables....
        org 0x4000;
        

// pieces are a bit mask with bit/place allocations as -
//
//         0 1 2
//         3 4 5
//         6 7 8

M_TOP_LEFT  EQU 1;
M_MID_TOP   EQU 1 << 1;
M_TOP_RIGHT EQU 1 << 2;
M_MID_LEFT  EQU 1 << 3;
M_CENTRE    EQU 1 << 4;
M_MID_RIGHT EQU 1 << 5;
M_BOT_LEFT  EQU 1 << 6;
M_MID_BOT   EQU 1 << 7;
M_BOT_RIGHT EQU 1 << 8;


ALL_PLACES  EQU 0x1FF;

LINE_H_TOP  EQU M_TOP_LEFT  + M_MID_TOP   + M_TOP_RIGHT;
LINE_H_MID  EQU M_MID_LEFT  + M_CENTRE    + M_MID_RIGHT;
LINE_H_BOT  EQU M_BOT_LEFT  + M_MID_BOT   + M_BOT_RIGHT;
LINE_V_LFT  EQU M_TOP_LEFT  + M_MID_LEFT  + M_BOT_LEFT;
LINE_V_MID  EQU M_MID_TOP   + M_CENTRE    + M_MID_BOT;
LINE_V_RGT  EQU M_TOP_RIGHT + M_MID_RIGHT + M_BOT_RIGHT;
LINE_D_LFT  EQU M_TOP_LEFT  + M_CENTRE    + M_BOT_RIGHT;
LINE_D_RGT  EQU M_TOP_RIGHT + M_CENTRE    + M_BOT_LEFT;

place_masks:    dw  0x001, 0x002, 0x004, 0x008, 0x010, 0x020, 0x040, 0x080, 0x100;

// *************************************
our_pieces:     dw;
their_pieces:   dw;
all_pieces:     dw;

is_our_move:    db;
our_mark:       db;
first_move:     db;

// results from search for line formation
cfl_n_candidates:   db;
cfl_candidate:      dw;

// =============================================================
// data to draw Xs
x_data_left:
        dw  0x0102;
        dw  0x0084;
        dw  0x0048;
        dw  0x0030;
        dw  0x0030;
        dw  0x0048;
        dw  0x0084;
        dw  0x0102;

x_data_mid:
        dw  0x0810;
        dw  0x0420;
        dw  0x0240;
        dw  0x0180;
        dw  0x0180;
        dw  0x0240;
        dw  0x0420;
        dw  0x0810;

x_data_right:
        dw  0x4080;
        dw  0x2100;
        dw  0x1200;
        dw  0x0C00;
        dw  0x0C00;
        dw  0x1200;
        dw  0x2100;
        dw  0x4080;

// data to draw Os
O_data_left:
        dw  0x0030;
        dw  0x0048;
        dw  0x0084;
        dw  0x0102;
        dw  0x0102;
        dw  0x0084;
        dw  0x0048;
        dw  0x0030;

O_data_mid:
        dw  0x0180;
        dw  0x0240;
        dw  0x0420;
        dw  0x0810;
        dw  0x0810;
        dw  0x0420;
        dw  0x0240;
        dw  0x0180;

O_data_right:
        dw  0x0C00;
        dw  0x1200;
        dw  0x2100;
        dw  0x4080;
        dw  0x4080;
        dw  0x2100;
        dw  0x1200;
        dw  0x0C00;

// data to draw ?s
Q_data_left:
        dw  0x0060;
        dw  0x0090;
        dw  0x0080;
        dw  0x0040;
        dw  0x0020;
        dw  0x0020;
        dw  0x0000;
        dw  0x0020;

Q_data_mid:
        dw  0x0300;
        dw  0x0480;
        dw  0x0400;
        dw  0x0200;
        dw  0x0100;
        dw  0x0100;
        dw  0x0000;
        dw  0x0100;

Q_data_right:
        dw  0x1800;
        dw  0x2400;
        dw  0x2000;
        dw  0x1000;
        dw  0x0800;
        dw  0x0800;
        dw  0x0000;
        dw  0x0800;

x_data_table:
        dw  x_data_left, x_data_mid, x_data_right;
        dw  x_data_left, x_data_mid, x_data_right;
        dw  x_data_left, x_data_mid, x_data_right;
        
O_data_table:
        dw  O_data_left, O_data_mid, O_data_right;
        dw  O_data_left, O_data_mid, O_data_right;
        dw  O_data_left, O_data_mid, O_data_right;
        
Q_data_table:
        dw  Q_data_left, Q_data_mid, Q_data_right;
        dw  Q_data_left, Q_data_mid, Q_data_right;
        dw  Q_data_left, Q_data_mid, Q_data_right;

BOARD_TOP   EQU 1;        
cell_base_address:
        dw  INT_RAM_START + (BOARD_TOP +  1)*INT_RAM_BYTES_ACROSS + 0;
        dw  INT_RAM_START + (BOARD_TOP +  1)*INT_RAM_BYTES_ACROSS + 1;
        dw  INT_RAM_START + (BOARD_TOP +  1)*INT_RAM_BYTES_ACROSS + 2;
        dw  INT_RAM_START + (BOARD_TOP + 12)*INT_RAM_BYTES_ACROSS + 0;
        dw  INT_RAM_START + (BOARD_TOP + 12)*INT_RAM_BYTES_ACROSS + 1;
        dw  INT_RAM_START + (BOARD_TOP + 12)*INT_RAM_BYTES_ACROSS + 2;
        dw  INT_RAM_START + (BOARD_TOP + 23)*INT_RAM_BYTES_ACROSS + 0;
        dw  INT_RAM_START + (BOARD_TOP + 23)*INT_RAM_BYTES_ACROSS + 1;
        dw  INT_RAM_START + (BOARD_TOP + 23)*INT_RAM_BYTES_ACROSS + 2;
        
// **************************************
// data for line "I"
text_line_i:
    db  0x00, 0xC0, 0x01, 0x00;
    db  0x00, 0x80, 0x00, 0x00;
    db  0x00, 0x80, 0x00, 0x00;
    db  0x00, 0x80, 0x00, 0x00;
    db  0x00, 0x80, 0x00, 0x00;
    db  0x00, 0x80, 0x00, 0x00;
    db  0x00, 0x80, 0x00, 0x00;
    db  0x00, 0xC0, 0x01, 0x00;
    
// data for line "You"
text_line_you:
    db  0x10, 0x84, 0x21, 0x10;
    db  0x20, 0x42, 0x22, 0x10;
    db  0x40, 0x21, 0x24, 0x10;
    db  0x80, 0x10, 0x28, 0x10;
    db  0x80, 0x10, 0x28, 0x10;
    db  0x80, 0x20, 0x24, 0x10;
    db  0x80, 0x40, 0x22, 0x10;
    db  0x80, 0x80, 0xC1, 0x0F;
    
// data for line "won"
text_line_won:
    db  0x08, 0x84, 0x21, 0x10;
    db  0x08, 0x44, 0x62, 0x10;
    db  0x08, 0x24, 0xa4, 0x10;
    db  0x08, 0x14, 0x28, 0x11;
    db  0x08, 0x14, 0x28, 0x12;
    db  0xC8, 0x24, 0x24, 0x14;
    db  0x28, 0x45, 0x22, 0x18;
    db  0x18, 0x86, 0x21, 0x10;
    
// data for line "we"
text_line_we:
    db  0x80, 0x40, 0xFe, 0x0;
    db  0x80, 0x40, 0x02, 0x0;
    db  0x80, 0x40, 0x02, 0x0;
    db  0x80, 0x40, 0x3E, 0x0;
    db  0x80, 0x4C, 0x02, 0x0;
    db  0x80, 0x52, 0x02, 0x0;
    db  0x80, 0x61, 0x02, 0x0;
    db  0x80, 0x40, 0xfe, 0x0;
    
// data for line "drew"
text_line_drew:
    db  0x3F, 0x3F, 0x7F, 0x81;
    db  0x41, 0x41, 0x01, 0x81;
    db  0x41, 0x41, 0x01, 0x81;
    db  0x41, 0x3F, 0x1F, 0x81;
    db  0x41, 0x05, 0x01, 0x99;
    db  0x41, 0x09, 0x01, 0xa5;
    db  0x41, 0x11, 0x01, 0xc3;
    db  0x3F, 0x21, 0x7F, 0x81;
    

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
div_zero:   reti;
            nop;
            nop;
            nop;        
illegal:    reti;
            nop;
            nop;
            nop;

// *********************
// The program....            
start:
        // give ourselves a stack...
        ld.w    r0,#0x7000;
        move    sp,r0;

        ld.b    r0,#1;
        st.b    our_mark,r0;
        st.b    first_move,r0;
main_loop:
        ld.b    r0,first_move;
        st.b    is_our_move,r0;
        st.b    our_mark,r0;
        ld.b    r1,#1;
        xor     r0,r1;
        st.b    first_move,r0;
        jsr     play_game;
        jmp     main_loop;

// *******************************************************
// we expect our_mark and our_move to be set up
play_game:
        jsr     wait_for_start;
        jsr     init;
        
pg_1:
        // check for a draw...
        ld.w    r0,all_pieces;
        ld.w    r1,#ALL_PLACES;
        cmp     r0,r1;
        beq     a_draw;
        
        // work out if our or their move
        ld.b    r0,is_our_move;
        beq     pg_2;
        
        jsr     make_our_move;
        ld.w    r0,our_pieces;
        jsr     is_line;
        test    r0;
        bne     we_won;
        jmp     pg_3;
pg_2:
        jsr     make_their_move;
        ld.w    r0,their_pieces;
        jsr     is_line;
        test    r0;
        bne     they_won;

pg_3:
        ld.b    r0,is_our_move;
        ld.b    r1,#1;
        xor     r0,r1;
        st.b    is_our_move,r0;

        jmp     pg_1;       
        
we_won:
        ld.w    r2,#text_line_i;
        ld.w    r3,#INT_RAM_START + 40*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#4*8;
ww1:
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        dec r0;
        bne ww1;
        ld.w    r2,#text_line_won;
        ld.w    r3,#INT_RAM_START + 50*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#4*8;
ww2:
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        dec r0;
        bne ww2;
        ret;
they_won:
        ld.w    r2,#text_line_you;
        ld.w    r3,#INT_RAM_START + 40*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#4*8;
tw1:
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        dec r0;
        bne tw1;
        ld.w    r2,#text_line_won;
        ld.w    r3,#INT_RAM_START + 50*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#4*8;
tw2:
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        dec r0;
        bne tw2;
        ret;
a_draw:
        ld.w    r2,#text_line_we;
        ld.w    r3,#INT_RAM_START + 40*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#4*8;
ad1:
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        dec r0;
        bne ad1;
        ld.w    r2,#text_line_drew;
        ld.w    r3,#INT_RAM_START + 50*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#4*8;
ad2:
        ld.b    r1,(r2++);
        st.b    (r3++),r1;
        dec r0;
        bne ad2;
        ret;
        
// *******************************************************
// clear memory and set up the board
init:
    // clear pieces
    xor     r0,r0;
    st.w    our_pieces,r0;
    st.w    their_pieces,r0;
    st.w    all_pieces,r0;
    
    // draw the board
    // ==============
    // clear
    xor     r0,r0;
    ld.w    r2,#INT_RAM_START;
    ld.w    r1,#INT_RAM_LEN;
clr_loop:
    st.w    (r2++),r0;
    addq    r1,#-2;
    bne     clr_loop;

    // vertical ...
    ld.b    r0,#32;
    ld.w    r1,#0x2004;
    ld.w    r2,#INT_RAM_START + (BOARD_TOP)*INT_RAM_BYTES_ACROSS + 1;
vert_loop:
    st.w    (r2++),r1;
    addq    r2,#2;
    dec     r0;
    bne     vert_loop;
    
    // horizontal....
    ld.w    r0,#0xFFFF;
    st.w    INT_RAM_START + (BOARD_TOP + 10)*INT_RAM_BYTES_ACROSS + 0,R0;
    st.w    INT_RAM_START + (BOARD_TOP + 21)*INT_RAM_BYTES_ACROSS + 0,R0;
    ld.w    r0,#0xFFFF;
    st.w    INT_RAM_START + (BOARD_TOP + 10)*INT_RAM_BYTES_ACROSS + 2,R0;
    st.w    INT_RAM_START + (BOARD_TOP + 21)*INT_RAM_BYTES_ACROSS + 2,R0;
    
    ret;
    
// *******************************************************
// looking for an up, so must first wait for it being down
wait_for_start:
    ld.w    r1, #IO_SWITCH_FLAG_SQUARE;
wfs_1:
    ld.w    r0, GEN_IO_INPUT;
    and     r0,r1;
    beq     wfs_1;
    
    // its down, now wait for an up
wfs_2:
    ld.w    r0, GEN_IO_INPUT;
    and     r0,r1;
    bne     wfs_2;
    
    ret;
    
// *******************************************************
// preserve registers, index in R0
draw_X:
    push    r0;
    push    r1;
    push    r2;
    push    r3;
    
    add     r0,r0;
    ld.w    r2,#x_data_table;
    add     r2,r0;
    ld.w    r1,(r2);
    move    r2,r1;
    ld.w    r3,#cell_base_address;
    add     r3,r0;
    ld.w    r1,(r3);
    move    r3,r1;
    jmp     draw_X_O;
    
    
draw_O:
    push    r0;
    push    r1;
    push    r2;
    push    r3;
    
    add     r0,r0;
    ld.w    r2,#O_data_table;
    add     r2,r0;
    ld.w    r1,(r2);
    move    r2,r1;
    ld.w    r3,#cell_base_address;
    add     r3,r0;
    ld.w    r1,(r3);
    move    r3,r1;
    jmp     draw_X_O;
    
draw_X_O:
    ld.b    r0,#8;
dx0_1:
    push    r0;
    ld.w    r0,(r3);
    ld.w    r1,(r2++);
    or      r1,r0;
    st.w    (r3++),r1;
    addq    r3,#2;
    pop     r0;
    dec     r0;
    bne     dx0_1;
    
    pop     r3;
    pop     r2;
    pop     r1;
    pop     r0;
    ret;
    
    
draw_Q:
    push    r0;
    push    r1;
    push    r2;
    push    r3;
    
    add     r0,r0;
    ld.w    r2,#Q_data_table;
    add     r2,r0;
    ld.w    r1,(r2);
    move    r2,r1;
    ld.w    r3,#cell_base_address;
    add     r3,r0;
    ld.w    r1,(r3);
    move    r3,r1;

    ld.b    r0,#8;
dq_1:
    push    r0;
    ld.w    r0,(r3);
    ld.w    r1,(r2++);
    xor     r1,r0;
    st.w    (r3++),r1;
    addq    r3,#2;
    pop     r0;
    dec     r0;
    bne     dq_1;
    
    pop     r3;
    pop     r2;
    pop     r1;
    pop     r0;
    ret;
    
    
    
// *******************************************************
draw_our_pieces:
    ld.w    r0,our_pieces;
    ld.b    r1,our_mark;
    beq     dop_1;
    jsr     draw_Xs;
    ret;
dop_1:
    jsr     draw_Os;
    ret;

draw_their_pieces:
    ld.w    r0,their_pieces;
    ld.b    r1,our_mark;
    bne     dtp_1;
    jsr     draw_Xs;
    ret;
dtp_1:
    jsr     draw_Os;
    ret;


draw_Xs:
    move    r2,r0;  // put piecse mask in R2
    ld.b    r1,#1;  // test
    xor     r0,r0;  // index
    
dx_2:
    move    r3,r2;
    and     r3,r1;
    beq     dx_1;
    jsr     draw_x;
dx_1:
    add     r1,r1;  // move to next
    inc     r0;
    ld.b    r3,#9;
    cmp     r3,r0;
    bne     dx_2;
    
    ret;
    
draw_Os:
    move    r2,r0;  // put piecse mask in R2
    ld.b    r1,#1;  // test
    xor     r0,r0;  // index
    
do_2:
    move    r3,r2;
    and     r3,r1;
    beq     do_1;
    jsr     draw_o;
do_1:
    add     r1,r1;  // move to next
    inc     r0;
    ld.b    r3,#9;
    cmp     r3,r0;
    bne     do_2;
    
    ret;
    
// *******************************************************
// put a query in the first available position, then let them move it round on each
// 01 edge on the joystick bits
// use the fire flag to make the selection
make_their_move:
    ld.b    r0,#0;  // starting pos test
    ld.b    r2,#1;
mtm_1:
    ld.w    r1,all_pieces;
    and     r1,r2;
    beq     mtm_2;
    inc     r0;
    add     r2,r2;  // move to next
    jmp     mtm_1;
mtm_2:
    // we have an empty slot in R0
    jsr     draw_q;
    
    // now we loop around looking for either a fire or a joystick move
    // first wait till cleared
mtm_loop:
    ld.w    r3,#0xFFFF;
mtm_lx:
    ld.w    r1,GEN_IO_INPUT;
    cmp     r1,r3;
    bne     mtm_lx;
    
    // cleared now loop looking for signal
mem_wait_for_signal:
    ld.w    r1,GEN_IO_INPUT;
    ld.w    r2,#IO_SWITCH_FLAG_R1;
    and     r2,r1;
    beq     mtm_go;              // got a GO
    
    ld.w    r3,#-1;
    ld.w    r2,#IO_SWITCH_FLAG_LEFT;
    and     r2,r1;
    beq     do_move;

    ld.w    r3,#+1;
    ld.w    r2,#IO_SWITCH_FLAG_RIGHT;
    and     r2,r1;
    bne     mem_wait_for_signal;              // not right, not anything
    
do_move:
    // first delete the Q
    jsr     draw_Q;
    
    // now do the move, R3 has the increment, we need to keep going it till we have a space
mtm_search:
    add     r0,r3;      // new position
    bpl     mtm_10;
    ld.b    r0,#8;
    jmp     mtm_11;
mtm_10:
    ld.b    r2,#9;
    cmp     r0,r2;
    bne     mtm_11;
    clr     r0;
mtm_11:
    ld.w    r2,#place_masks;                  // check free
    add     r2,r0;
    add     r2,r0;
    ld.w    r1,(r2);                // mask for new place
    ld.w    r2,all_pieces;
    and     r1,r2;
    bne     mtm_search; // need to try next place
    // space is clear, 
    jsr     draw_Q;
    jmp     mtm_loop;
    
    // said go
mtm_go:    
    jsr     draw_Q;
    ld.w    r2,#place_masks;                  // need to set flag
    add     r2,r0;
    add     r2,r0;
    ld.w    r1,(r2);
    ld.w    r0,their_pieces;
    or      r0,r1;
    st.w    their_pieces,r0;
    ld.w    r0,all_pieces;
    or      r0,r1;
    st.w    all_pieces,r0;
    jsr     draw_their_pieces;
    ret;

// *******************************************************
// if opponent has won, or we have a draw then we will not come here
make_our_move:

    // 6. centre... whether or not we're first we'll play in the middle if we can, so might as well check it first.
    ld.w    r0,#M_CENTRE;
    ld.w    r1,all_pieces;
    and     r1,r0;
    beq     fm_1;
    
    // 1. can I win
    ld.w    r0,our_pieces;
    ld.w    r1,all_pieces;
    jsr     can_form_line;
    ld.w    r0,cfl_candidate;
    ld.b    r1,cfl_n_candidates;
    bne fm_1;

    // 2. block opponent
    ld.w    r0,their_pieces;
    ld.w    r1,all_pieces;
    jsr     can_form_line;
    ld.w    r0,cfl_candidate;
    ld.b    r1,cfl_n_candidates;
    bne     fm_1;

    // 3. can I create a fork ?
    jsr     fork_for_me;
    test    r0;
    bne     fm_1;
    
    // 4. can we create 2 in a row that does not force opponent to create a fork ?
    jsr     two_for_me;
    test    r0;
    bne     fm_1;
    
    // 5. stop opponent creating a fork
    jsr     stop_fork_for_them;
    test    r0;
    bne     fm_1;
    
    // 7. opposite corner
    jsr     find_opposite_corner;
    test    r0;
    bne     fm_1;
    
    // 8. corner
    jsr     find_corner;
    test    r0;
    bne     fm_1;
    
    // 9. side
    jsr     find_empty_side; // must succeed
    //test  r0;
    //bne   fm_1;
    
fm_1:   // we have a move, mask value in r0
    ld.w    r1,our_pieces;
    or      r1,r0;
    st.w    our_pieces,r1;
    ld.w    r1,all_pieces;
    or      r1,r0;
    st.w    all_pieces,r1;
    
    jsr     draw_our_pieces;
    
    ret;

// *******************************************************
// look to see if can start to form a line somewhere
// (but need to check that the forced response of our opponnent
// isn't a fork).
two_for_me:
    ld.b    r3,#1;      // test mask
    ld.b    r2,#9;      // test 9 places

tfm_1:  // main loop
    ld.w    r0,all_pieces;
    and     r0,r3;
    bne     tfm_2;      // already occupied
    
    // so there is a space here, see if we could win if we played here
    ld.w    r0,our_pieces;
    ld.w    r1,all_pieces;
    or      r0,r3;
    or      r1,r3;
    jsr     can_form_line;
    ld.b    r0,cfl_n_candidates;
    beq     tfm_2;      // no
    
    // yes, check that we're not forcing opponent to create a fork
    // our candidate move is R3, if they want to stop us they play cfl_candidate
    // so would they have a fork then ?
    push    r3; // cretae some workspace
    ld.w    r1, all_pieces;  // r1 is all pieces, include our candidate
    or      r1,r3;
    ld.w    r0, their_pieces;   // load in their proposed play into r0
    ld.w    r3,cfl_candidate;
    or      r0,r3;
    or      r1,r3;
    pop     r3;
    jsr     can_form_line;
    ld.b    r0,cfl_n_candidates;
    ld.b    r1,#2;
    cmp     r0,r1;
    bpl     tfm_2;  // opponent will create a fork with his required response,
            // so don't do this
            
    // looking good, go for it
    move    r0,r3;
    ret;
    
tfm_2:
    add     r3,r3;
    dec     r2;
    bne     tfm_1;
    
    clr     r0;
    
    ret;
    
// *******************************************************
// look if there is sokewhere thy could go that would be a fork,
// if so then go there to top them
stop_fork_for_them:
    ld.b    r3,#1;      // test mask
    ld.b    r2,#9;      // test 9 places

sffm_1: // main loop
    ld.w    r0,all_pieces;
    and     r0,r3;
    bne     sffm_2;     // already occupied
    
    // so there is a space here, see if would be fork for them
    ld.w    r0,their_pieces;
    ld.w    r1,all_pieces;
    or      r0,r3;
    or      r1,r3;
    jsr     can_form_line;
    ld.b    r0,cfl_n_candidates;
    ld.b    r1,#2;
    cmp     r0,r1;
    bmi     sffm_2; // no
    
    // it does, so we must go there
    move    r0,r3;
    ret;
    
sffm_2:
    add     r3,r3;
    dec     r2;
    bne     sffm_1;
    clr     r0;
    
    ret;


// *******************************************************
// look to see if I can create a fork
fork_for_me:

    ld.w    r0,our_pieces;
    ld.w    r1,all_pieces;
    jsr     create_a_fork;
    ret;
    
// *******************************************************
// look to see if can create a fork
// r0 is set for player
// r1 is the occupied set
// preserve r2,r3
create_a_fork:
    push    r2;
    push    r3;
    ld.b    r3,#1;      // test mask
    ld.b    r2,#9;      // test 9 places
    
caf_1:  // the main loop
    push    r0;     // need to save r0/1 across loop
    push    r1;
    
    and     r1,r3;
    bne     caf_2;
    // there is a space...try adding it to the set and see if can get a fork
    or      r0,r3;
    pop     r1;
    push    r1;
    or      r1,r3;
    jsr     can_form_line;
    ld.b    r0,cfl_n_candidates;
    ld.b    r1,#2;
    cmp     r0,r1;
    bmi     caf_2;
    
    // we have a fork !
    pop     r1;
    pop     r0;
    move    r0,r3;
    pop     r3;
    pop     r2;
    ret;
    
caf_2:  // loop around
    pop     r1;
    pop     r0;
    add     r3,r3;
    dec     r2;
    bne     caf_1;
    
    pop     r3;
    pop     r2;
    clr     r0;
    ret;
    
// *******************************************************
// see if opponent is in one corner whilst the opposite is free, if so take it.
find_opposite_corner:
    ld.w    r1,their_pieces;
    ld.w    r0,#M_BOT_RIGHT;
    and     r0,r1;
    beq     foc_10;
    ld.w    r1,all_pieces;
    ld.w    r0,#M_TOP_LEFT;
    and     r1,r0;
    beq     foc_1;
foc_10:

    ld.w    r1,their_pieces;
    ld.w    r0,#M_BOT_LEFT;
    and     r0,r1;
    beq     foc_20;
    ld.w    r1,all_pieces;
    ld.w    r0,#M_TOP_RIGHT;
    and     r1,r0;
    beq     foc_1;
foc_20:
    
    ld.w    r1,their_pieces;
    ld.w    r0,#M_TOP_RIGHT;
    and     r0,r1;
    beq     foc_30;
    ld.w    r1,all_pieces;
    ld.w    r0,#M_BOT_LEFT;
    and     r1,r0;
    beq     foc_1;
foc_30:
    
    ld.w    r1,their_pieces;
    ld.w    r0,#M_TOP_LEFT;
    and     r0,r1;
    beq     foc_40;
    ld.w    r1,all_pieces;
    ld.w    r0,#M_BOT_RIGHT;
    and     r1,r0;
    beq     foc_1;
    
foc_40: nop;
    // no opposite corner
    xor     r0,r0;
    nop;
    
foc_1:
    ret;

// *******************************************************
// if there is an empty corner return it in r0, otherwise return 0
find_corner:
    ld.w    r1,all_pieces;
    ld.w    r0,#M_TOP_LEFT;
    and     r1,r0;
    beq     fc_1;
    
    ld.w    r1,all_pieces;
    ld.w    r0,#M_TOP_RIGHT;
    and     r1,r0;
    beq     fc_1;
    
    ld.w    r1,all_pieces;
    ld.w    r0,#M_BOT_LEFT;
    and     r1,r0;
    beq     fc_1;
    
    ld.w    r1,all_pieces;
    ld.w    r0,#M_BOT_RIGHT;
    and     r1,r0;
    beq     fc_1;

    // no spare corner
    xor     r0,r0;
    nop;
fc_1:
    ret;

// *******************************************************
// if there is an empty side return it in r0, otherwise return 0
find_empty_side:
    ld.w    r1,all_pieces;
    ld.w    r0,#M_MID_TOP;
    and     r1,r0;
    beq     fe_1;
    
    ld.w    r1,all_pieces;
    ld.w    r0,#M_MID_BOT;
    and r1,r0;
    beq fe_1;
    
    ld.w    r1,all_pieces;
    ld.w    r0,#M_MID_LEFT;
    and     r1,r0;
    beq     fe_1;
    
    ld.w    r1,all_pieces;
    ld.w    r0,#M_MID_RIGHT;
    and     r1,r0;
    beq     fe_1;

    // no spare edge
//    nop;
    clr     r0;
fe_1:
    ret;

// *******************************************************
// look to see how many lines can be formed
// player mask value in r0, all occupied in r1
// Results stored in cfl_candidate & cfl_n_candidates
// (If there are multiple lines that can be formed we store the inex of the last one).
// Preserves r1,r2,r3
can_form_line:
    push    r2;
    push    r3;

    clr     r3;
    st.b    cfl_n_candidates,r3;
    ld.b    r3,#1;      // test mask
    ld.b    r2,#9;      // test 9 places
    
cfl_3:  // the main loop
    push    r1; // save across loop
    and     r1,r3;
    bne     cfl_1;  // skip if already occupied
    
    // there is a space...
    push    r0;
    or      r0,r3;      // form candidate
    jsr     is_line;
    test    r0;
    beq     cfl_2;
    // can form a line, update count and store candidate
    st.w    cfl_candidate,r3;
    ld.b    r1,cfl_n_candidates;
    inc     r1;
    st.b    cfl_n_candidates,r1;
cfl_2:
    pop r0;
    
cfl_1:  // loop around
    pop     r1;
    add     r3,r3;
    dec     r2;
    bne     cfl_3;
    
    // restore registers
    pop     r3;
    pop     r2;
    
    ret;
    
// *******************************************************
// mask value in r0, return 1 if is a line, 0 if not.
// preserve other registers
is_line:
    push    r1;
    push    r2;
    
    move    r1,r0;
    ld.w    r2,#LINE_H_TOP;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_H_MID;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_H_BOT;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_V_LFT;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_V_MID;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_V_RGT;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_D_LFT;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

    move    r1,r0;
    ld.w    r2,#LINE_D_RGT;
    and     r1,r2;
    cmp     r1,r2;
    beq     il_1;

// no matches
    clr     r0;
il_2:
    pop     r2;
    pop     r1;
    ret;
    
il_1:
    ld.b    r0,#1;
    jmp     il_2;
    
// *******************************************************