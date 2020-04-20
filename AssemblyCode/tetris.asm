// Based on PET TETRIS by Tim Howe
// https://www.youtube.com/watch?v=vJWDFWn8Kjc

// There are 7 different tetrominoes:
// Type I
//               #             #  
//       ####    #     ####    #  
//               #             #  
//               #             #  
// Type O
//        ##     ##     ##     ## 
//        ##     ##     ##     ## 
//                                
//                                
// Type T
//       ###      #           #   
//        #      ##     #     ##  
//                #    ###    #   
//                                
// Type S
//       ##       #            #  
//        ##     ##    ##     ##  
//               #      ##    #   
//                                
// Type Z
//        ##     #            #   
//       ##      ##     ##    ##  
//                #    ##      #  
//                                
// Type J
//       ###      #           ##  
//         #      #    #      #   
//               ##    ###    #   
//                                
// Type L
//       ###     ##           #   
//       #        #      #    #   
//                #    ###    ##  
//                                

// We play on a board with a legal area 10 cells wide and 20 tall.
// The actual board we play on is (for implementation purposes) 16 cells wide and 26 tall
// with the legal area occupying the central 10x20.
// The thick walls of non-legal area make for easier checks of legal moves as we can just set
// them as occupied and thus we just check for occupied cells and don't worry about explicitly
// checking for boundaries.
//
// Top left of the whole board is (0,0).
// Our start position is (8,3).
//
// The board is represented as 26 16 bit words.
// Set bits represent occupied cells, clear bits represent free bits.
// A 3 bit wide border is permenantly set to implement the walls/boundaries.
// 
// We allow 13 possible offsets with 0 being the top left corner of a tetromino being offset 0 from the left.
// (Technically they could be upto 16, but nothing would be legal in the last 3. One could argue none of
// the first 3 would be either, but its easier to have them than not).
// 
// We have 4 possible rotation values, 0..3, with each incrmenet being a 90 degree clockwise rotation.
//
// For each tetromino type we have we have sets definining their cell occupancies for each possible
// offset and rotation.
// This is done by 4 16 bit words with set bits representing cell occupancy. There are 4 words as a
// tetromino may be upto 4 cells deep.
// A legal move can therefore be determined by looking for any clashes between the cell pattern for
// the tetromino (for offset & rotation) against the board from the y position of the tetromino.
// These cell patterns are stored in tables with the name (?)_board_cell_sets, a table for each
// teromiono type.
//
// For display each board cell maps to a 3x3 bit (pixel) block within the internal RAM.
// In the x dimension the middle 10 playable cells (3..12) map to pixels 1..30.
// So cell x maps to pixels 3*(x-3)+1..3*(x-3)+3.
// In the Y direction the middle 10 playable cells (3..22) map to pixels 3..62
// So cell y maps to pixels 3*(y-3)+3..3*(y-3)+5
// These display patterns are stored in tables with the name (?)_display_pattern_sets, a table for each
// teromiono type.
//
// We have 2 possible instances of a teromino.
// CURRENT  : At the start of a "move" this holds the current state of the falling tet. We manipulate this with
//            speculative moves to check for legaility before accepting a move.
// PREVIOUS : This receives a copy of CURRENT at the start of a move so that of if we do accept a move we
//            can remeber where we were in order to remove the display

// *************************************
// Start with shared definitions...
include "Megaprocessor_defs.asm";

// *************************************
// tables and variables....
        org 0x10;
    
board_cell_sets:
        dw      I_board_cell_sets;
        dw      O_board_cell_sets;
        dw      T_board_cell_sets;
        dw      S_board_cell_sets;
        dw      Z_board_cell_sets;
        dw      J_board_cell_sets;
        dw      L_board_cell_sets;

display_pattern_sets:
        dw      I_display_pattern_sets;
        dw      O_display_pattern_sets;
        dw      T_display_pattern_sets;
        dw      S_display_pattern_sets;
        dw      Z_display_pattern_sets;
        dw      J_display_pattern_sets;
        dw      L_display_pattern_sets;

// We need a structure to hold data for a tetromino

INITIAL_X                       equ     8;
INITIAL_Y                       equ     3;
FULL_BOARD_SIZE                 equ     26*2;
FULL_ROW_MASK                   equ     0xFFFF;
N_FULL_ROW_CHECK                equ     20;
START_FULL_ROW_CHECK            equ     the_board + INITIAL_Y*2;
BOARD_WALLS                     equ     0xE007;
FIRST_BOARD_POSN                equ     START_FULL_ROW_CHECK;
FIRST_DISPLAY_POSN              equ     INT_RAM_START + (3 - 3*INITIAL_Y)*INT_RAM_BYTES_ACROSS;
FIRST_DISPLAY_ADDRESS           equ     INT_RAM_START + (3)*INT_RAM_BYTES_ACROSS;

// put tetromino data structure on simple addresses so we can look at it easily in the simulator
                                org     0x40;
current_type:                   db;
current_display_pattern_set:    dw;
current_cell_pattern_set:       dw;
current_rotn:                   db;
current_display_pattern:        dw;
current_display_posn_biased:    dw;
current_display_posn_raw:       dw;
current_X:                      db;
current_Y:                      db;
current_cell_pattern:           dw;
current_board_posn:             dw;

// need to record a few elements of a tet so can delete its previous display
prev_rotn:                      db;    //    <<<--<<<<< these fields must be same order/size as current
prev_display_pattern:           dw;    //    <<<--<<<<< 
prev_display_posn_biased:       dw;    //    <<<--<<<<< 
prev_display_posn_raw:          dw;    //    <<<--<<<<< 
prev_x:                         db;    //    <<<--<<<<< 
tet_move_data_len               equ 8;

the_board:                      ds       FULL_BOARD_SIZE;


game_over:                      db;
last_down_time:                 dw;
last_key_time:                  dw;
prev_key:                       dw;



MOVE_INTERVAL                   equ     100; // ??
KEY_REPEAT_TIME                 equ     100; // ??

FLAG_START                      equ     IO_SWITCH_FLAG_R1;

// **************************************
end_of_variables    equ $;

// **************************************
// vectors
            org  0;
reset:      jmp    start;
            nop;
ext_int:    reti;
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

// ********************************************
// The program....            
        org     end_of_variables;
start:
        // give ourselves a stack...
        ld.w    r0,#0x7FFF;
        move    sp,r0;
        
        jsr     init_board;

main_loop:
        jsr     play_game;
        
        ld.w    r2,#text_game;
        ld.w    r3,#INT_RAM_START + 10*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#16;
    ml_1:
        ld.w    r1,(r2++);
        st.w    (r3++),r1;
        dec     r0;
        bne     ml_1;
        ld.w    r2,#text_over;
        ld.w    r3,#INT_RAM_START + 20*INT_RAM_BYTES_ACROSS;
        ld.b    r0,#16;
    ml_2:
        ld.w    r1,(r2++);
        st.w    (r3++),r1;
        dec     r0;
        bne     ml_2;
        
        jmp     main_loop;

// *******************************************************
// The game loop consists simply of checking for a key press and then
// moving a teromino down if the drop time has elapsed
play_game:
    jsr     start_game;
    
game_loop:
    // Key checking
    jsr     check_key;
    // possible for game to end if do a drop and then next tet causes game end
    ld.b    r0,game_over;
    beq     gl_1;
    ret;
    
gl_1:
    // drop the Tetromino if enough time has passed since the last drop
    ld.w    r1,last_down_time;
    ld.w    r0,#MOVE_INTERVAL;
    add     r1,r0;
    ld.w    r0,TIME_BLK_COUNTER;
    cmp     r0,r1;
    bmi     game_loop;
    
    st.w    last_down_time,r0;
    jsr     move_tet_down;
    
    ld.b    r0,game_over;
    beq     game_loop;
    
    ret;
    
// *******************************************************
start_game:
    
    jsr     wait_for_start;
    
    jsr     init_board;
    
    // init state variables....
    clr     r0;
    st.b    game_over,r0;
    st.w    prev_key,r0;
    ld.w    r0,TIME_BLK_COUNTER;
    st.w    last_down_time,r0;
    
    ret;

// *******************************************************
// For the disolay we want to clear it, and then have a one opixel
// wide border on the sides and bottom.
// For the board we want it empty , but with the walls and bottom set.
// clear memory and set up the board

init_board:
    // clear board... clear middle, 3 bit wide set border
    ld.w    r2,#the_board;
    ld.w    r0,#BOARD_WALLS;
    ld.b    r1,#23;
init_1:
    st.w    (r2++),r0;
    dec     r1;
    bne     init_1;
    ld.w    r0,#0xFFFF;
    st.w    (r2++),r0;
    st.w    (r2++),r0;
    st.w    (r2++),r0;

    // draw the display
    // ==============
    clr     r0;
    ld.w    r2,#INT_RAM_START;
    st.w    (r2++),r0;
    st.w    (r2++),r0;
    st.w    (r2++),r0;
    st.w    (r2++),r0;
    st.w    (r2++),r0;
    st.w    (r2++),r0;
    ld.w    r1,#60;
clr_loop:
    ld.w    r0,#0x0001;
    st.w    (r2++),r0;
    ld.w    r0,#0x8000;
    st.w    (r2++),r0;
    dec     r1;
    bne     clr_loop;
    
    ld.w    r0,#0xFFFF;
    st.w    (r2++),r0;
    st.w    (r2++),r0;

    jsr     create_next_tet;

    ret;

// *******************************************************
// looking for an up, so must first wait for it being down
wait_for_start:
    ld.w    r1, #FLAG_START;
wfs_1:
    ld.w    r0, GEN_IO_INPUT;
    and     r0,r1;
    bne     wfs_1;
    
    // it's down, now wait for an up
wfs_2:
    ld.w    r0, GEN_IO_INPUT;
    and     r0,r1;
    beq     wfs_2;
    
    ret;
    
// *******************************************************
// cretate a random tetromino in CURRENT.
create_next_tet:
    // get some random numbers based on time...
    // After div remainder is in R3 quotient is in R2
    ld.w    r0,TIME_BLK_COUNTER;
    ld.w    r1,#7;
    divu;
    ld.b    r0,#3;
    and     r2,r0;
    st.b    current_rotn,r2;
    st.b    current_type,r3;
    
    // must now set up the base data pointers we need on the basis of the tet type
    add     r3,r3; // make word offset
    ld.w    r2,#board_cell_sets;
    add     r2,r3;
    ld.w    r0,(r2);
    st.w    current_cell_pattern_set,r0;
    ld.w    r2,#display_pattern_sets;
    add     r2,r3;
    ld.w    r0,(r2);
    st.w    current_display_pattern_set,r0;
    
    // set the initial X,Y
    ld.b    r0,#INITIAL_X;
    st.b    current_X,r0;
    ld.b    r0,#INITIAL_Y;
    st.b    current_Y,r0;
    
    // finish off pointer calc
    jsr     calc_pointers;
    
    // and draw it
    ld.w    r3,#current_rotn;
    jsr     draw_tetromino;
    
    // at start of move previous should match current
    ld.w    r2,#current_rotn;
    ld.w    r3,#prev_rotn;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    
    ret;
    
// *******************************************************
// Move the falling tetromino down one line.
// If a collision would result then undo the move and handle a landing.
//R0 return 1 if landed, 0 otherwise
//****************************************************************************
move_tet_down:

    // start by assuming we can move it down....
    ld.b    r0,current_Y;
    inc     r0;
    st.b    current_Y,r0;

    jsr     test_collision;
    test    r0;
    bne     we_have_landed;
    jsr     move_tetromino;
    ret;

we_have_landed:
    // undo the failed drop
    ld.b    r0,current_Y;
    dec     r0;
    st.b    current_Y,r0;
    jsr     calc_pointers;
    
    // move Tet. onto board and remove rows
    jsr     tet_landed;
    
    ret;
    

// *******************************************************
check_key:
    jsr     extract_key;
    test    r0;
    bne     key_was_pressed;
    st.w    prev_key,r0;
    ret;

key_was_pressed:
    ld.w    r1,prev_key;
    cmp     r0,r1;
    bne     do_key_press;   // a different key
    
    // same key...is it time for auto repeat
    ld.w    r1,TIME_BLK_COUNTER;
    ld.w    r2,last_key_time;
    sub     r1,r2;
    ld.w    r2,#KEY_REPEAT_TIME;
    cmp     r1,r2;
    bpl     do_key_press;
    ret;
    
do_key_press:
    st.w    prev_key,r0;
    ld.w    r1,TIME_BLK_COUNTER;
    st.w    last_key_time,r1;
    jsr     (r0);
    test    r0;
    bne     key_needs_display_update;
    ret;
    
key_needs_display_update:
    jsr     move_tetromino;
    ret;

// *******************************************************
//  output key handler in R0
extract_key:
    ld.w    r0,GEN_IO_INPUT;
    ld.w    r2,#handle_left;   
    ld.w    r1, #IO_SWITCH_FLAG_LEFT;
    and     r1,r0;
    beq     there_is_a_key;

    ld.w    r2,#handle_right;   
    ld.w    r1, #IO_SWITCH_FLAG_RIGHT;
    and     r1,r0;
    beq     there_is_a_key;

    ld.w    r2,#handle_rot_left;   
    ld.w    r1, #IO_SWITCH_FLAG_SQUARE;
    and     r1,r0;
    beq     there_is_a_key;

    ld.w    r2,#handle_rot_right;   
    ld.w    r1, #IO_SWITCH_FLAG_TRIANGLE;
    and     r1,r0;
    beq     there_is_a_key;
    
    ld.w    r2,#handle_drop;   
    ld.w    r1, #IO_SWITCH_FLAG_L1;
    and     r1,r0;
    beq     there_is_a_key;
    
    clr     r0;
    ret;
there_is_a_key:
    move    r0,r2;
    ret;

// *******************************************************
// handles return non-0 in R0 if need display update
handle_left:
    ld.b    r0,current_X;
    dec     r0;
    st.b    current_X,r0;
    jsr     test_collision;
    test    r0;
    beq     handle_key_ok;
    // hit something, undo
    ld.b    r0,current_X;
    inc     r0;
    st.b    current_X,r0;
    clr     r0;
    ret;
    
handle_right:
    ld.b    r0,current_X;
    inc     r0;
    st.b    current_X,r0;
    jsr     test_collision;
    test    r0;
    beq     handle_key_ok;
    // hit something, undo
    ld.b    r0,current_X;
    dec     r0;
    st.b    current_X,r0;
    clr     r0;
    ret;
    
handle_rot_left:
    ld.b    r0,current_rotn;
    dec     r0;
    ld.b    r1,#3;
    and     r0,r1;
    st.b    current_rotn,r0;
    jsr     test_collision;
    test    r0;
    beq     handle_key_ok;
    // hit something, undo
    ld.b    r0,current_rotn;
    inc     r0;
    ld.b    r1,#3;
    and     r0,r1;
    st.b    current_rotn,r0;
    clr     r0;
    ret;
    
handle_rot_right:
    ld.b    r0,current_rotn;
    inc     r0;
    ld.b    r1,#3;
    and     r0,r1;
    st.b    current_rotn,r0;
    jsr     test_collision;
    test    r0;
    beq     handle_key_ok;
    // hit something, undo
    ld.b    r0,current_rotn;
    dec     r0;
    ld.b    r1,#3;
    and     r0,r1;
    st.b    current_rotn,r0;
    clr     r0;
    ret;
    
    // drop, drop till we hit something
handle_drop:
    ld.b    r0,current_Y;
    inc     r0;
    st.b    current_Y,r0;
    jsr     test_collision;
    test    r0;
    beq     handle_drop;
    
handle_drop_landed:
    // finally hit something, so rewind one
    ld.b    r0,current_Y;
    dec     r0;
    st.b    current_Y,r0;
    jsr     calc_pointers; // need the parameters updated...
    jsr     move_tetromino;    // draw the move...

    jsr     tet_landed;       //
    clr     r0; // do not need to update display again
    ret;

handle_key_ok:
    ld.b    r0,#1;
    ret;
    
/*****************************************************************************
* Copy the supplied tetromino into the board and test for completed rows.
* If rows are filled, mark them for deletion, then delete them
*   and update the stats.
*****************************************************************************/
    // move Tet. onto board and remove rows
tet_landed:
    /* Copy the tetromnio into the board */
    ld.w    r2,current_cell_pattern;
    ld.w    r3,current_board_posn;
    
    // The tetromino may span 4 lines
    ld.w    r0,(r2++);
    ld.w    r1,(r3);
    or      r0,r1;
    st.w    (r3++),r0;
    
    ld.w    r0,(r2++);
    ld.w    r1,(r3);
    or      r0,r1;
    st.w    (r3++),r0;
    
    ld.w    r0,(r2++);
    ld.w    r1,(r3);
    or      r0,r1;
    st.w    (r3++),r0;
    
    ld.w    r0,(r2++);
    ld.w    r1,(r3);
    or      r0,r1;
    st.w    (r3++),r0;
    
    // Now need to remove full rows.....
    // keep checking till none left
full_row_check:
    ld.w    r1,#FULL_ROW_MASK;
    ld.b    r3,#N_FULL_ROW_CHECK;
    ld.w    r2,#START_FULL_ROW_CHECK;
full_row_1:
    ld.w    r0,(r2++);
    xor     r0,r1;
    beq     have_full_row;
    
    dec     r3;
    bne     full_row_1;
    
    //  now get the next Tet and then look to see if game is over
    jsr     create_next_tet;

    jsr     test_collision; // if Tet hits immediately then game is over
    beq     tet_landed_end;
    ld.b    r0,#1;
    st.b    game_over,r0;
        
tet_landed_end:
    // reset drop timer
    ld.w    r0,TIME_BLK_COUNTER;
    st.w    last_down_time,r0;
    ret;


    // full row... remove it
    // =====================
have_full_row:
    ld.b    r0,#N_FULL_ROW_CHECK; // if the count is now n we must use N - n
    sub     r0,r3;
    push    r0;     // save count to use later
    // first work on the board
    beq     remove_full_row_4;
    addq    r2,#-2;    // must undo the post inc on reading the line
    move    r3,r2;
    addq    r2,#-2; // r2 will be our src
remove_full_row_1:
    ld.w    r1,(r2);
    st.w    (r3),r1;
    addq    r2,#-2;
    addq    r3,#-2;
    dec     r0;
    bne     remove_full_row_1;
    
    // now we must clear from the display
    pop     r0;     // lines done, mult by 12 to get offset from display start
    move    r1,r0;
    move    r2,r1;
    add     r1,r1;
    add     r1,r2;   // n_done *3
    add     r1,r1;
    add     r1,r1;  // n_done *12
    ld.w    r2,#FIRST_DISPLAY_ADDRESS + 10; //  10 as need end of data for pixel row
    add     r2,r1;  // r2 is dst of pixels (the full line we're clearing)
    move    r3,r2;
    ld.b    r1,#12;
    sub     r3,r1;  // r3 is src of pixels

    // must multiply the loop count by 6 as 3 display lines 
    // of 4 bytes per board row, but we do 2 at a time
    move    r1,r0;
    add     r0,r0;
    add     r0,r1;
    add     r0,r0;
remove_full_row_3:
    ld.w    r1,(r3);
    st.w    (r2),r1;
    addq    r2,#-2;
    addq    r3,#-2;
    dec     r0;
    bne     remove_full_row_3;


remove_full_row_4:
    // and clear top line of board
    ld.w    r1,#BOARD_WALLS;
    st.w    start_full_row_check,r1;
    // clear top pixel row
    ld.w    r0,#0x0001;
    st.w    FIRST_DISPLAY_ADDRESS +  0,r0;
    st.w    FIRST_DISPLAY_ADDRESS +  4,r0;
    st.w    FIRST_DISPLAY_ADDRESS +  8,r0;
    ld.w    r0,#0x8000;
    st.w    FIRST_DISPLAY_ADDRESS +  2,r0;
    st.w    FIRST_DISPLAY_ADDRESS +  6,r0;
    st.w    FIRST_DISPLAY_ADDRESS + 10,r0;
    // and then go round again...
    jmp     full_row_check;
    
// =================================================================
// look to see current trial position of tet will colide with something
// (board has occupied cells for previous tets AND walls and floor)
// Return non-zero in R0 for a collision
test_collision:
    // first calc pointers for trial position
    jsr     calc_pointers;

    // look to see if cell pattern for current position overlaps with current board.
    ld.w    r2,current_cell_pattern;
    ld.w    r3,current_board_posn;
    
    ld.w    r0,(r2++);
    ld.w    r1,(r3++);
    and     r0,r1;
    bne     is_coll;
    ld.w    r0,(r2++);
    ld.w    r1,(r3++);
    and     r0,r1;
    bne     is_coll;
    ld.w    r0,(r2++);
    ld.w    r1,(r3++);
    and     r0,r1;
    bne     is_coll;
    ld.w    r0,(r2++);
    ld.w    r1,(r3++);
    and     r0,r1;
    bne     is_coll;
    
    //R0 is clear for no collision
    ret;
    
is_coll:
    ld.b    r0,#1;
    ret;
    
// =================================================================
    // calculate (and store) pointers to things of interest for the
    // position of tetromino
    //
    // We can share some of the calculations for indxing into the 
    // cell pattern and board display tables
    // For both the entry we need is table[x*n_rot + rot].
    // for cell patterns each entry is 4 words = 8 bytes long
    // for display patterns they are also 4 words = 8 bytes
calc_pointers:
    ld.b    r3,current_X;
    add     r3,r3;
    add     r3,r3; // r3 = 4*x
    ld.b    r1,current_rotn;
    add     r3,r1;  // r3 = 4*x + rot
    
    add     r3,r3;
    add     r3,r3;
    add     r3,r3;    // r3 now has 8*index
    ld.w    r2,current_cell_pattern_set;
    add     r2,r3;
    st.w    current_cell_pattern,r2;

    ld.w    r2,current_display_pattern_set;
    add     r2,r3;
    st.w    current_display_pattern,r2;

    ld.b    r1,current_Y;
    add     r1,r1;      // board is 2 bytes wide
    ld.w    r3,#the_board;
    add     r1,r3;
    st.w    current_board_posn,r1;
    
    // cells are 3 pixels tall which corresponds to 12 bytes (4 bytes a line)
    ld.b    r1,current_Y;
    move    r3,r1;
    add     r1,r1;
    add     r3,r1;      // r3 = Y*3
    add     r3,r3;
    add     r3,r3;      // r3 = 12*y
    ld.w    r1,#FIRST_DISPLAY_POSN;
    add     r1,r3;
    st.w    current_display_posn_raw,r1;
    ld.b    r0,current_X;
    ld.w    r2,#display_biases;
    add     r2,r0;
    ld.b    r0,(r2);
    add     r1,r0;
    st.w    current_display_posn_biased,r1;
    
    ret;
    
// *******************************************************
// The Tet. has moved
// update display and data structures....
move_tetromino:
    //  delete in old position
    ld.w    r3,#prev_rotn;
    jsr     draw_tetromino;

    //  .., and draw in new
    ld.w    r3,#current_rotn;
    jsr     draw_tetromino;
    
    // make copy of pointer/position data ....
    ld.w    r2,#current_rotn;
    ld.w    r3,#prev_rotn;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    ld.w    r0,(r2++);
    st.w    (r3++),R0;
    
    ret;
    
// *******************************************************
// expect r3 points to descriptor
// draw the tetromino by XORing in a pattern onto the display.
// We use patterns of 4 32 bit words. Each word is applied to 3 lines of the display
draw_tetromino:
    ld.b    r1,(r3++);      // get in (and move past rotation)
    ld.b    r0,current_type;
    bne     draw_tet_not_0;
    ld.b    r0,#4;
    btst    r1,#0;
    bne     draw_tet_normal;

    //  So here we are dealing with a horizontal I teromino.
    // This works differently from the others as single row, but its full width
    // get the pointers to display position and pattern
    ld.w    r1,(r3++);
    ld.w    r1,(r3++);  // biased position...discard
    ld.w    r1,(r3++);  // raw_position...the one we use
    ld.b    r0,(r3++);  // X
    add     r0,r0;
    add     r0,r0;
    ld.w    r2,#horz_I_set;
    add     r2,r0;  // points to correct horiz I pattern
    move    r3,r1;      // position
    ld.b    r1,#12;     // horiz Z is always one cell down (=12 bytes)
    add     r3,r1;
    
    // and now do single row but do full width
    ld.w    r0,(r2++); 
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    ld.w    r0,(r2); 
    addq    r2,#-2;     // rewind to use mask of this row again
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;

    ld.w    r0,(r2++); 
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    ld.w    r0,(r2); 
    addq    r2,#-2;     // rewind to use mask of this row again
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;

    ld.w    r0,(r2++); 
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    ld.w    r0,(r2++);  // move forward to get mask for next row
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    ret;
    
    
draw_tet_not_0:
    ld.b    r0,#3;
draw_tet_normal:
    // get the pointers to display position and pattern
    ld.w    r1,(r3++);
    move    r2,r1;      // pattern
    ld.w    r1,(r3++);
    move    r3,r1;      // position (biased)

draw_tet_1:
    push    r0;

    ld.w    r0,(r2++); // Can use this pattern for 3 rows
    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    addq    r3,#2;      // need to move total of 4 bytes for next write

    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    addq    r3,#2;      // need to move total of 4 bytes for next write

    ld.w    r1,(r3);
    xor     r1,r0;
    st.w    (r3++),r1;
    addq    r3,#2;      // need to move total of 4 bytes for next write

    // stop if about to walk off end of RAM
    ld.w    r0,#INT_RAM_START + INT_RAM_LEN - INT_RAM_BYTES_ACROSS;
    cmp     r3,r0;
    bpl     quit_draw;
    
    // restore loop count and see if go round again
    pop     r0;
    dec     r0;
    bne     draw_tet_1;

    ret;

quit_draw:  // giving up, sort out stack and then return
    pop     r0;
    ret;
    
// **************************************
end_of_program equ  $;
// **************************************
// text
text_Game:
    db      0x38,       0x10,       0x82,       0xFE;
    db      0x44,       0x28,       0xC6,       0x02;
    db      0x82,       0x44,       0xAA,       0x02;
    db      0x02,       0x82,       0x92,       0x3E;
    db      0xF2,       0xFE,       0x82,       0x02;
    db      0x42,       0x82,       0x82,       0x02;
    db      0x44,       0x82,       0x82,       0x02;
    db      0x38,       0x82,       0x82,       0xFE;

text_over:
    db      0x10,       0x82,       0xFE,       0x7E;
    db      0x28,       0x82,       0x02,       0x82;
    db      0x44,       0x82,       0x02,       0x82;
    db      0x82,       0x82,       0x3E,       0x7E;
    db      0x82,       0x82,       0x02,       0x12;
    db      0x44,       0x44,       0x02,       0x22;
    db      0x28,       0x28,       0x02,       0x42;
    db      0x10,       0x10,       0xFE,       0x82;

// *******************************************************
// big data blocks
// *******************************************************
// These tables generated by tetris_data.cpp

I_board_cell_sets        equ     $;
    dw    0x0000,   0x000F,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0002,   0x0002,   0x0002,   0x0002;     // Offset  0  Rot 1
    dw    0x0000,   0x000F,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0002,   0x0002,   0x0002,   0x0002;     // Offset  0  Rot 3
    dw    0x0000,   0x001E,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0004,   0x0004,   0x0004,   0x0004;     // Offset  1  Rot 1
    dw    0x0000,   0x001E,   0x0000,   0x0000;     // Offset  1  Rot 2
    dw    0x0004,   0x0004,   0x0004,   0x0004;     // Offset  1  Rot 3
    dw    0x0000,   0x003C,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0008,   0x0008,   0x0008,   0x0008;     // Offset  2  Rot 1
    dw    0x0000,   0x003C,   0x0000,   0x0000;     // Offset  2  Rot 2
    dw    0x0008,   0x0008,   0x0008,   0x0008;     // Offset  2  Rot 3
    dw    0x0000,   0x0078,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0010,   0x0010,   0x0010,   0x0010;     // Offset  3  Rot 1
    dw    0x0000,   0x0078,   0x0000,   0x0000;     // Offset  3  Rot 2
    dw    0x0010,   0x0010,   0x0010,   0x0010;     // Offset  3  Rot 3
    dw    0x0000,   0x00F0,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0020,   0x0020,   0x0020,   0x0020;     // Offset  4  Rot 1
    dw    0x0000,   0x00F0,   0x0000,   0x0000;     // Offset  4  Rot 2
    dw    0x0020,   0x0020,   0x0020,   0x0020;     // Offset  4  Rot 3
    dw    0x0000,   0x01E0,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x0040,   0x0040,   0x0040,   0x0040;     // Offset  5  Rot 1
    dw    0x0000,   0x01E0,   0x0000,   0x0000;     // Offset  5  Rot 2
    dw    0x0040,   0x0040,   0x0040,   0x0040;     // Offset  5  Rot 3
    dw    0x0000,   0x03C0,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0080,   0x0080,   0x0080,   0x0080;     // Offset  6  Rot 1
    dw    0x0000,   0x03C0,   0x0000,   0x0000;     // Offset  6  Rot 2
    dw    0x0080,   0x0080,   0x0080,   0x0080;     // Offset  6  Rot 3
    dw    0x0000,   0x0780,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0100,   0x0100,   0x0100,   0x0100;     // Offset  7  Rot 1
    dw    0x0000,   0x0780,   0x0000,   0x0000;     // Offset  7  Rot 2
    dw    0x0100,   0x0100,   0x0100,   0x0100;     // Offset  7  Rot 3
    dw    0x0000,   0x0F00,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0200,   0x0200,   0x0200,   0x0200;     // Offset  8  Rot 1
    dw    0x0000,   0x0F00,   0x0000,   0x0000;     // Offset  8  Rot 2
    dw    0x0200,   0x0200,   0x0200,   0x0200;     // Offset  8  Rot 3
    dw    0x0000,   0x1E00,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0400,   0x0400,   0x0400,   0x0400;     // Offset  9  Rot 1
    dw    0x0000,   0x1E00,   0x0000,   0x0000;     // Offset  9  Rot 2
    dw    0x0400,   0x0400,   0x0400,   0x0400;     // Offset  9  Rot 3
    dw    0x0000,   0x3C00,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x0800,   0x0800,   0x0800,   0x0800;     // Offset 10  Rot 1
    dw    0x0000,   0x3C00,   0x0000,   0x0000;     // Offset 10  Rot 2
    dw    0x0800,   0x0800,   0x0800,   0x0800;     // Offset 10  Rot 3
    dw    0x0000,   0x7800,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x1000,   0x1000,   0x1000,   0x1000;     // Offset 11  Rot 1
    dw    0x0000,   0x7800,   0x0000,   0x0000;     // Offset 11  Rot 2
    dw    0x1000,   0x1000,   0x1000,   0x1000;     // Offset 11  Rot 3
    dw    0x0000,   0xF000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x2000,   0x2000,   0x2000,   0x2000;     // Offset 12  Rot 1
    dw    0x0000,   0xF000,   0x0000,   0x0000;     // Offset 12  Rot 2
    dw    0x2000,   0x2000,   0x2000,   0x2000;     // Offset 12  Rot 3

O_board_cell_sets        equ     $;
    dw    0x0006,   0x0006,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0006,   0x0006,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0006,   0x0006,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0006,   0x0006,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x000C,   0x000C,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000C,   0x000C,   0x0000,   0x0000;     // Offset  1  Rot 1
    dw    0x000C,   0x000C,   0x0000,   0x0000;     // Offset  1  Rot 2
    dw    0x000C,   0x000C,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x0018,   0x0018,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0018,   0x0018,   0x0000,   0x0000;     // Offset  2  Rot 1
    dw    0x0018,   0x0018,   0x0000,   0x0000;     // Offset  2  Rot 2
    dw    0x0018,   0x0018,   0x0000,   0x0000;     // Offset  2  Rot 3
    dw    0x0030,   0x0030,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0030,   0x0030,   0x0000,   0x0000;     // Offset  3  Rot 1
    dw    0x0030,   0x0030,   0x0000,   0x0000;     // Offset  3  Rot 2
    dw    0x0030,   0x0030,   0x0000,   0x0000;     // Offset  3  Rot 3
    dw    0x0060,   0x0060,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0060,   0x0060,   0x0000,   0x0000;     // Offset  4  Rot 1
    dw    0x0060,   0x0060,   0x0000,   0x0000;     // Offset  4  Rot 2
    dw    0x0060,   0x0060,   0x0000,   0x0000;     // Offset  4  Rot 3
    dw    0x00C0,   0x00C0,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x00C0,   0x00C0,   0x0000,   0x0000;     // Offset  5  Rot 1
    dw    0x00C0,   0x00C0,   0x0000,   0x0000;     // Offset  5  Rot 2
    dw    0x00C0,   0x00C0,   0x0000,   0x0000;     // Offset  5  Rot 3
    dw    0x0180,   0x0180,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0180,   0x0180,   0x0000,   0x0000;     // Offset  6  Rot 1
    dw    0x0180,   0x0180,   0x0000,   0x0000;     // Offset  6  Rot 2
    dw    0x0180,   0x0180,   0x0000,   0x0000;     // Offset  6  Rot 3
    dw    0x0300,   0x0300,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0300,   0x0300,   0x0000,   0x0000;     // Offset  7  Rot 1
    dw    0x0300,   0x0300,   0x0000,   0x0000;     // Offset  7  Rot 2
    dw    0x0300,   0x0300,   0x0000,   0x0000;     // Offset  7  Rot 3
    dw    0x0600,   0x0600,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0600,   0x0600,   0x0000,   0x0000;     // Offset  8  Rot 1
    dw    0x0600,   0x0600,   0x0000,   0x0000;     // Offset  8  Rot 2
    dw    0x0600,   0x0600,   0x0000,   0x0000;     // Offset  8  Rot 3
    dw    0x0C00,   0x0C00,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0C00,   0x0C00,   0x0000,   0x0000;     // Offset  9  Rot 1
    dw    0x0C00,   0x0C00,   0x0000,   0x0000;     // Offset  9  Rot 2
    dw    0x0C00,   0x0C00,   0x0000,   0x0000;     // Offset  9  Rot 3
    dw    0x1800,   0x1800,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x1800,   0x1800,   0x0000,   0x0000;     // Offset 10  Rot 1
    dw    0x1800,   0x1800,   0x0000,   0x0000;     // Offset 10  Rot 2
    dw    0x1800,   0x1800,   0x0000,   0x0000;     // Offset 10  Rot 3
    dw    0x3000,   0x3000,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x3000,   0x3000,   0x0000,   0x0000;     // Offset 11  Rot 1
    dw    0x3000,   0x3000,   0x0000,   0x0000;     // Offset 11  Rot 2
    dw    0x3000,   0x3000,   0x0000,   0x0000;     // Offset 11  Rot 3
    dw    0x6000,   0x6000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x6000,   0x6000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x6000,   0x6000,   0x0000,   0x0000;     // Offset 12  Rot 2
    dw    0x6000,   0x6000,   0x0000,   0x0000;     // Offset 12  Rot 3

T_board_cell_sets        equ     $;
    dw    0x0007,   0x0002,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0004,   0x0006,   0x0004,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0002,   0x0007,   0x0000;     // Offset  0  Rot 2
    dw    0x0001,   0x0003,   0x0001,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x0004,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0008,   0x000C,   0x0008,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0004,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0002,   0x0006,   0x0002,   0x0000;     // Offset  1  Rot 3
    dw    0x001C,   0x0008,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0010,   0x0018,   0x0010,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x0008,   0x001C,   0x0000;     // Offset  2  Rot 2
    dw    0x0004,   0x000C,   0x0004,   0x0000;     // Offset  2  Rot 3
    dw    0x0038,   0x0010,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0020,   0x0030,   0x0020,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0010,   0x0038,   0x0000;     // Offset  3  Rot 2
    dw    0x0008,   0x0018,   0x0008,   0x0000;     // Offset  3  Rot 3
    dw    0x0070,   0x0020,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0040,   0x0060,   0x0040,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0020,   0x0070,   0x0000;     // Offset  4  Rot 2
    dw    0x0010,   0x0030,   0x0010,   0x0000;     // Offset  4  Rot 3
    dw    0x00E0,   0x0040,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x0080,   0x00C0,   0x0080,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x0040,   0x00E0,   0x0000;     // Offset  5  Rot 2
    dw    0x0020,   0x0060,   0x0020,   0x0000;     // Offset  5  Rot 3
    dw    0x01C0,   0x0080,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0100,   0x0180,   0x0100,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x0080,   0x01C0,   0x0000;     // Offset  6  Rot 2
    dw    0x0040,   0x00C0,   0x0040,   0x0000;     // Offset  6  Rot 3
    dw    0x0380,   0x0100,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0200,   0x0300,   0x0200,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x0100,   0x0380,   0x0000;     // Offset  7  Rot 2
    dw    0x0080,   0x0180,   0x0080,   0x0000;     // Offset  7  Rot 3
    dw    0x0700,   0x0200,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0400,   0x0600,   0x0400,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0200,   0x0700,   0x0000;     // Offset  8  Rot 2
    dw    0x0100,   0x0300,   0x0100,   0x0000;     // Offset  8  Rot 3
    dw    0x0E00,   0x0400,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0800,   0x0C00,   0x0800,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0400,   0x0E00,   0x0000;     // Offset  9  Rot 2
    dw    0x0200,   0x0600,   0x0200,   0x0000;     // Offset  9  Rot 3
    dw    0x1C00,   0x0800,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x1000,   0x1800,   0x1000,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x0800,   0x1C00,   0x0000;     // Offset 10  Rot 2
    dw    0x0400,   0x0C00,   0x0400,   0x0000;     // Offset 10  Rot 3
    dw    0x3800,   0x1000,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x2000,   0x3000,   0x2000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x1000,   0x3800,   0x0000;     // Offset 11  Rot 2
    dw    0x0800,   0x1800,   0x0800,   0x0000;     // Offset 11  Rot 3
    dw    0x7000,   0x2000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x4000,   0x6000,   0x4000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x2000,   0x7000,   0x0000;     // Offset 12  Rot 2
    dw    0x1000,   0x3000,   0x1000,   0x0000;     // Offset 12  Rot 3

S_board_cell_sets        equ     $;
    dw    0x0003,   0x0006,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0004,   0x0006,   0x0002,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0003,   0x0006,   0x0000;     // Offset  0  Rot 2
    dw    0x0002,   0x0003,   0x0001,   0x0000;     // Offset  0  Rot 3
    dw    0x0006,   0x000C,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0008,   0x000C,   0x0004,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0006,   0x000C,   0x0000;     // Offset  1  Rot 2
    dw    0x0004,   0x0006,   0x0002,   0x0000;     // Offset  1  Rot 3
    dw    0x000C,   0x0018,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0010,   0x0018,   0x0008,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x000C,   0x0018,   0x0000;     // Offset  2  Rot 2
    dw    0x0008,   0x000C,   0x0004,   0x0000;     // Offset  2  Rot 3
    dw    0x0018,   0x0030,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0020,   0x0030,   0x0010,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0018,   0x0030,   0x0000;     // Offset  3  Rot 2
    dw    0x0010,   0x0018,   0x0008,   0x0000;     // Offset  3  Rot 3
    dw    0x0030,   0x0060,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0040,   0x0060,   0x0020,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0030,   0x0060,   0x0000;     // Offset  4  Rot 2
    dw    0x0020,   0x0030,   0x0010,   0x0000;     // Offset  4  Rot 3
    dw    0x0060,   0x00C0,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x0080,   0x00C0,   0x0040,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x0060,   0x00C0,   0x0000;     // Offset  5  Rot 2
    dw    0x0040,   0x0060,   0x0020,   0x0000;     // Offset  5  Rot 3
    dw    0x00C0,   0x0180,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0100,   0x0180,   0x0080,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x00C0,   0x0180,   0x0000;     // Offset  6  Rot 2
    dw    0x0080,   0x00C0,   0x0040,   0x0000;     // Offset  6  Rot 3
    dw    0x0180,   0x0300,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0200,   0x0300,   0x0100,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x0180,   0x0300,   0x0000;     // Offset  7  Rot 2
    dw    0x0100,   0x0180,   0x0080,   0x0000;     // Offset  7  Rot 3
    dw    0x0300,   0x0600,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0400,   0x0600,   0x0200,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0300,   0x0600,   0x0000;     // Offset  8  Rot 2
    dw    0x0200,   0x0300,   0x0100,   0x0000;     // Offset  8  Rot 3
    dw    0x0600,   0x0C00,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0800,   0x0C00,   0x0400,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0600,   0x0C00,   0x0000;     // Offset  9  Rot 2
    dw    0x0400,   0x0600,   0x0200,   0x0000;     // Offset  9  Rot 3
    dw    0x0C00,   0x1800,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x1000,   0x1800,   0x0800,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x0C00,   0x1800,   0x0000;     // Offset 10  Rot 2
    dw    0x0800,   0x0C00,   0x0400,   0x0000;     // Offset 10  Rot 3
    dw    0x1800,   0x3000,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x2000,   0x3000,   0x1000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x1800,   0x3000,   0x0000;     // Offset 11  Rot 2
    dw    0x1000,   0x1800,   0x0800,   0x0000;     // Offset 11  Rot 3
    dw    0x3000,   0x6000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x4000,   0x6000,   0x2000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x3000,   0x6000,   0x0000;     // Offset 12  Rot 2
    dw    0x2000,   0x3000,   0x1000,   0x0000;     // Offset 12  Rot 3

Z_board_cell_sets        equ     $;
    dw    0x0006,   0x0003,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0002,   0x0006,   0x0004,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0006,   0x0003,   0x0000;     // Offset  0  Rot 2
    dw    0x0001,   0x0003,   0x0002,   0x0000;     // Offset  0  Rot 3
    dw    0x000C,   0x0006,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0004,   0x000C,   0x0008,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x000C,   0x0006,   0x0000;     // Offset  1  Rot 2
    dw    0x0002,   0x0006,   0x0004,   0x0000;     // Offset  1  Rot 3
    dw    0x0018,   0x000C,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0008,   0x0018,   0x0010,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x0018,   0x000C,   0x0000;     // Offset  2  Rot 2
    dw    0x0004,   0x000C,   0x0008,   0x0000;     // Offset  2  Rot 3
    dw    0x0030,   0x0018,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0010,   0x0030,   0x0020,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0030,   0x0018,   0x0000;     // Offset  3  Rot 2
    dw    0x0008,   0x0018,   0x0010,   0x0000;     // Offset  3  Rot 3
    dw    0x0060,   0x0030,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0020,   0x0060,   0x0040,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0060,   0x0030,   0x0000;     // Offset  4  Rot 2
    dw    0x0010,   0x0030,   0x0020,   0x0000;     // Offset  4  Rot 3
    dw    0x00C0,   0x0060,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x0040,   0x00C0,   0x0080,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x00C0,   0x0060,   0x0000;     // Offset  5  Rot 2
    dw    0x0020,   0x0060,   0x0040,   0x0000;     // Offset  5  Rot 3
    dw    0x0180,   0x00C0,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0080,   0x0180,   0x0100,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x0180,   0x00C0,   0x0000;     // Offset  6  Rot 2
    dw    0x0040,   0x00C0,   0x0080,   0x0000;     // Offset  6  Rot 3
    dw    0x0300,   0x0180,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0100,   0x0300,   0x0200,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x0300,   0x0180,   0x0000;     // Offset  7  Rot 2
    dw    0x0080,   0x0180,   0x0100,   0x0000;     // Offset  7  Rot 3
    dw    0x0600,   0x0300,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0200,   0x0600,   0x0400,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0600,   0x0300,   0x0000;     // Offset  8  Rot 2
    dw    0x0100,   0x0300,   0x0200,   0x0000;     // Offset  8  Rot 3
    dw    0x0C00,   0x0600,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0400,   0x0C00,   0x0800,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0C00,   0x0600,   0x0000;     // Offset  9  Rot 2
    dw    0x0200,   0x0600,   0x0400,   0x0000;     // Offset  9  Rot 3
    dw    0x1800,   0x0C00,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x0800,   0x1800,   0x1000,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x1800,   0x0C00,   0x0000;     // Offset 10  Rot 2
    dw    0x0400,   0x0C00,   0x0800,   0x0000;     // Offset 10  Rot 3
    dw    0x3000,   0x1800,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x1000,   0x3000,   0x2000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x3000,   0x1800,   0x0000;     // Offset 11  Rot 2
    dw    0x0800,   0x1800,   0x1000,   0x0000;     // Offset 11  Rot 3
    dw    0x6000,   0x3000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x2000,   0x6000,   0x4000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x6000,   0x3000,   0x0000;     // Offset 12  Rot 2
    dw    0x1000,   0x3000,   0x2000,   0x0000;     // Offset 12  Rot 3

J_board_cell_sets        equ     $;
    dw    0x0007,   0x0004,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0004,   0x0004,   0x0006,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0001,   0x0007,   0x0000;     // Offset  0  Rot 2
    dw    0x0003,   0x0001,   0x0001,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x0008,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0008,   0x0008,   0x000C,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0002,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0006,   0x0002,   0x0002,   0x0000;     // Offset  1  Rot 3
    dw    0x001C,   0x0010,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0010,   0x0010,   0x0018,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x0004,   0x001C,   0x0000;     // Offset  2  Rot 2
    dw    0x000C,   0x0004,   0x0004,   0x0000;     // Offset  2  Rot 3
    dw    0x0038,   0x0020,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0020,   0x0020,   0x0030,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0008,   0x0038,   0x0000;     // Offset  3  Rot 2
    dw    0x0018,   0x0008,   0x0008,   0x0000;     // Offset  3  Rot 3
    dw    0x0070,   0x0040,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0040,   0x0040,   0x0060,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0010,   0x0070,   0x0000;     // Offset  4  Rot 2
    dw    0x0030,   0x0010,   0x0010,   0x0000;     // Offset  4  Rot 3
    dw    0x00E0,   0x0080,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x0080,   0x0080,   0x00C0,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x0020,   0x00E0,   0x0000;     // Offset  5  Rot 2
    dw    0x0060,   0x0020,   0x0020,   0x0000;     // Offset  5  Rot 3
    dw    0x01C0,   0x0100,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0100,   0x0100,   0x0180,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x0040,   0x01C0,   0x0000;     // Offset  6  Rot 2
    dw    0x00C0,   0x0040,   0x0040,   0x0000;     // Offset  6  Rot 3
    dw    0x0380,   0x0200,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0200,   0x0200,   0x0300,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x0080,   0x0380,   0x0000;     // Offset  7  Rot 2
    dw    0x0180,   0x0080,   0x0080,   0x0000;     // Offset  7  Rot 3
    dw    0x0700,   0x0400,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0400,   0x0400,   0x0600,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0100,   0x0700,   0x0000;     // Offset  8  Rot 2
    dw    0x0300,   0x0100,   0x0100,   0x0000;     // Offset  8  Rot 3
    dw    0x0E00,   0x0800,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0800,   0x0800,   0x0C00,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0200,   0x0E00,   0x0000;     // Offset  9  Rot 2
    dw    0x0600,   0x0200,   0x0200,   0x0000;     // Offset  9  Rot 3
    dw    0x1C00,   0x1000,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x1000,   0x1000,   0x1800,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x0400,   0x1C00,   0x0000;     // Offset 10  Rot 2
    dw    0x0C00,   0x0400,   0x0400,   0x0000;     // Offset 10  Rot 3
    dw    0x3800,   0x2000,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x2000,   0x2000,   0x3000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x0800,   0x3800,   0x0000;     // Offset 11  Rot 2
    dw    0x1800,   0x0800,   0x0800,   0x0000;     // Offset 11  Rot 3
    dw    0x7000,   0x4000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x4000,   0x4000,   0x6000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x1000,   0x7000,   0x0000;     // Offset 12  Rot 2
    dw    0x3000,   0x1000,   0x1000,   0x0000;     // Offset 12  Rot 3

L_board_cell_sets        equ     $;
    dw    0x0007,   0x0001,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0006,   0x0004,   0x0004,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0004,   0x0007,   0x0000;     // Offset  0  Rot 2
    dw    0x0001,   0x0001,   0x0003,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x0002,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000C,   0x0008,   0x0008,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0008,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0002,   0x0002,   0x0006,   0x0000;     // Offset  1  Rot 3
    dw    0x001C,   0x0004,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0018,   0x0010,   0x0010,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x0010,   0x001C,   0x0000;     // Offset  2  Rot 2
    dw    0x0004,   0x0004,   0x000C,   0x0000;     // Offset  2  Rot 3
    dw    0x0038,   0x0008,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0030,   0x0020,   0x0020,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0020,   0x0038,   0x0000;     // Offset  3  Rot 2
    dw    0x0008,   0x0008,   0x0018,   0x0000;     // Offset  3  Rot 3
    dw    0x0070,   0x0010,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0060,   0x0040,   0x0040,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0040,   0x0070,   0x0000;     // Offset  4  Rot 2
    dw    0x0010,   0x0010,   0x0030,   0x0000;     // Offset  4  Rot 3
    dw    0x00E0,   0x0020,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x00C0,   0x0080,   0x0080,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x0080,   0x00E0,   0x0000;     // Offset  5  Rot 2
    dw    0x0020,   0x0020,   0x0060,   0x0000;     // Offset  5  Rot 3
    dw    0x01C0,   0x0040,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0180,   0x0100,   0x0100,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x0100,   0x01C0,   0x0000;     // Offset  6  Rot 2
    dw    0x0040,   0x0040,   0x00C0,   0x0000;     // Offset  6  Rot 3
    dw    0x0380,   0x0080,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0300,   0x0200,   0x0200,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x0200,   0x0380,   0x0000;     // Offset  7  Rot 2
    dw    0x0080,   0x0080,   0x0180,   0x0000;     // Offset  7  Rot 3
    dw    0x0700,   0x0100,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0600,   0x0400,   0x0400,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0400,   0x0700,   0x0000;     // Offset  8  Rot 2
    dw    0x0100,   0x0100,   0x0300,   0x0000;     // Offset  8  Rot 3
    dw    0x0E00,   0x0200,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0C00,   0x0800,   0x0800,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0800,   0x0E00,   0x0000;     // Offset  9  Rot 2
    dw    0x0200,   0x0200,   0x0600,   0x0000;     // Offset  9  Rot 3
    dw    0x1C00,   0x0400,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x1800,   0x1000,   0x1000,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x1000,   0x1C00,   0x0000;     // Offset 10  Rot 2
    dw    0x0400,   0x0400,   0x0C00,   0x0000;     // Offset 10  Rot 3
    dw    0x3800,   0x0800,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x3000,   0x2000,   0x2000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x2000,   0x3800,   0x0000;     // Offset 11  Rot 2
    dw    0x0800,   0x0800,   0x1800,   0x0000;     // Offset 11  Rot 3
    dw    0x7000,   0x1000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x6000,   0x4000,   0x4000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x4000,   0x7000,   0x0000;     // Offset 12  Rot 2
    dw    0x1000,   0x1000,   0x3000,   0x0000;     // Offset 12  Rot 3

horz_I_set        equ     $;
    dl    0x0000000E;
    dl    0x0000007E;
    dl    0x000003FE;
    dl    0x00001FFE;
    dl    0x0000FFF0;
    dl    0x0007FF80;
    dl    0x003FFC00;
    dl    0x01FFE000;
    dl    0x0FFF0000;
    dl    0x7FF80000;
    dl    0x7FC00000;
    dl    0x7E000000;
    dl    0x70000000;

display_biases        equ     $;
    db    0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 2, 3, 3;


I_display_pattern_sets        equ     $;
    dw    0x0000,   0x000E,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x000E,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x0000,   0x007E,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x007E,   0x0000,   0x0000;     // Offset  1  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x0000,   0x03FE,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x000E,   0x000E,   0x000E,   0x000E;     // Offset  2  Rot 1
    dw    0x0000,   0x03FE,   0x0000,   0x0000;     // Offset  2  Rot 2
    dw    0x000E,   0x000E,   0x000E,   0x000E;     // Offset  2  Rot 3
    dw    0x0000,   0x1FFE,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0070,   0x0070,   0x0070,   0x0070;     // Offset  3  Rot 1
    dw    0x0000,   0x1FFE,   0x0000,   0x0000;     // Offset  3  Rot 2
    dw    0x0070,   0x0070,   0x0070,   0x0070;     // Offset  3  Rot 3
    dw    0x0000,   0xFFF0,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0380,   0x0380,   0x0380,   0x0380;     // Offset  4  Rot 1
    dw    0x0000,   0xFFF0,   0x0000,   0x0000;     // Offset  4  Rot 2
    dw    0x0380,   0x0380,   0x0380,   0x0380;     // Offset  4  Rot 3
    dw    0x0000,   0xFF80,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x1C00,   0x1C00,   0x1C00,   0x1C00;     // Offset  5  Rot 1
    dw    0x0000,   0xFF80,   0x0000,   0x0000;     // Offset  5  Rot 2
    dw    0x1C00,   0x1C00,   0x1C00,   0x1C00;     // Offset  5  Rot 3
    dw    0x0000,   0x3FFC,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x00E0,   0x00E0,   0x00E0,   0x00E0;     // Offset  6  Rot 1
    dw    0x0000,   0x3FFC,   0x0000,   0x0000;     // Offset  6  Rot 2
    dw    0x00E0,   0x00E0,   0x00E0,   0x00E0;     // Offset  6  Rot 3
    dw    0x0000,   0xFFE0,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0700,   0x0700,   0x0700,   0x0700;     // Offset  7  Rot 1
    dw    0x0000,   0xFFE0,   0x0000,   0x0000;     // Offset  7  Rot 2
    dw    0x0700,   0x0700,   0x0700,   0x0700;     // Offset  7  Rot 3
    dw    0x0000,   0x0FFF,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0038,   0x0038,   0x0038,   0x0038;     // Offset  8  Rot 1
    dw    0x0000,   0x0FFF,   0x0000,   0x0000;     // Offset  8  Rot 2
    dw    0x0038,   0x0038,   0x0038,   0x0038;     // Offset  8  Rot 3
    dw    0x0000,   0x7FF8,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x01C0,   0x01C0,   0x01C0,   0x01C0;     // Offset  9  Rot 1
    dw    0x0000,   0x7FF8,   0x0000,   0x0000;     // Offset  9  Rot 2
    dw    0x01C0,   0x01C0,   0x01C0,   0x01C0;     // Offset  9  Rot 3
    dw    0x0000,   0x7FC0,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x0E00,   0x0E00,   0x0E00,   0x0E00;     // Offset 10  Rot 1
    dw    0x0000,   0x7FC0,   0x0000,   0x0000;     // Offset 10  Rot 2
    dw    0x0E00,   0x0E00,   0x0E00,   0x0E00;     // Offset 10  Rot 3
    dw    0x0000,   0x007E,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0070,   0x0070,   0x0070,   0x0070;     // Offset 11  Rot 1
    dw    0x0000,   0x007E,   0x0000,   0x0000;     // Offset 11  Rot 2
    dw    0x0070,   0x0070,   0x0070,   0x0070;     // Offset 11  Rot 3
    dw    0x0000,   0x0070,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0070,   0x0000,   0x0000;     // Offset 12  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 3

O_display_pattern_sets        equ     $;
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 1
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 2
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x007E,   0x007E,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x007E,   0x007E,   0x0000,   0x0000;     // Offset  2  Rot 1
    dw    0x007E,   0x007E,   0x0000,   0x0000;     // Offset  2  Rot 2
    dw    0x007E,   0x007E,   0x0000,   0x0000;     // Offset  2  Rot 3
    dw    0x03F0,   0x03F0,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x03F0,   0x03F0,   0x0000,   0x0000;     // Offset  3  Rot 1
    dw    0x03F0,   0x03F0,   0x0000,   0x0000;     // Offset  3  Rot 2
    dw    0x03F0,   0x03F0,   0x0000,   0x0000;     // Offset  3  Rot 3
    dw    0x1F80,   0x1F80,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x1F80,   0x1F80,   0x0000,   0x0000;     // Offset  4  Rot 1
    dw    0x1F80,   0x1F80,   0x0000,   0x0000;     // Offset  4  Rot 2
    dw    0x1F80,   0x1F80,   0x0000,   0x0000;     // Offset  4  Rot 3
    dw    0xFC00,   0xFC00,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0xFC00,   0xFC00,   0x0000,   0x0000;     // Offset  5  Rot 1
    dw    0xFC00,   0xFC00,   0x0000,   0x0000;     // Offset  5  Rot 2
    dw    0xFC00,   0xFC00,   0x0000,   0x0000;     // Offset  5  Rot 3
    dw    0x07E0,   0x07E0,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x07E0,   0x07E0,   0x0000,   0x0000;     // Offset  6  Rot 1
    dw    0x07E0,   0x07E0,   0x0000,   0x0000;     // Offset  6  Rot 2
    dw    0x07E0,   0x07E0,   0x0000,   0x0000;     // Offset  6  Rot 3
    dw    0x3F00,   0x3F00,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x3F00,   0x3F00,   0x0000,   0x0000;     // Offset  7  Rot 1
    dw    0x3F00,   0x3F00,   0x0000,   0x0000;     // Offset  7  Rot 2
    dw    0x3F00,   0x3F00,   0x0000,   0x0000;     // Offset  7  Rot 3
    dw    0x01F8,   0x01F8,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x01F8,   0x01F8,   0x0000,   0x0000;     // Offset  8  Rot 1
    dw    0x01F8,   0x01F8,   0x0000,   0x0000;     // Offset  8  Rot 2
    dw    0x01F8,   0x01F8,   0x0000,   0x0000;     // Offset  8  Rot 3
    dw    0x0FC0,   0x0FC0,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0FC0,   0x0FC0,   0x0000,   0x0000;     // Offset  9  Rot 1
    dw    0x0FC0,   0x0FC0,   0x0000,   0x0000;     // Offset  9  Rot 2
    dw    0x0FC0,   0x0FC0,   0x0000,   0x0000;     // Offset  9  Rot 3
    dw    0x7E00,   0x7E00,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x7E00,   0x7E00,   0x0000,   0x0000;     // Offset 10  Rot 1
    dw    0x7E00,   0x7E00,   0x0000,   0x0000;     // Offset 10  Rot 2
    dw    0x7E00,   0x7E00,   0x0000,   0x0000;     // Offset 10  Rot 3
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 1
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 2
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 3
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 3

T_display_pattern_sets        equ     $;
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000E,   0x000E,   0x000E,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0000,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x007E,   0x000E,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0070,   0x007E,   0x0070,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x000E,   0x007E,   0x0000;     // Offset  2  Rot 2
    dw    0x0000,   0x000E,   0x0000,   0x0000;     // Offset  2  Rot 3
    dw    0x03FE,   0x0070,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0380,   0x03F0,   0x0380,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0070,   0x03FE,   0x0000;     // Offset  3  Rot 2
    dw    0x000E,   0x007E,   0x000E,   0x0000;     // Offset  3  Rot 3
    dw    0x1FF0,   0x0380,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x1C00,   0x1F80,   0x1C00,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0380,   0x1FF0,   0x0000;     // Offset  4  Rot 2
    dw    0x0070,   0x03F0,   0x0070,   0x0000;     // Offset  4  Rot 3
    dw    0xFF80,   0x1C00,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0xE000,   0xFC00,   0xE000,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x1C00,   0xFF80,   0x0000;     // Offset  5  Rot 2
    dw    0x0380,   0x1F80,   0x0380,   0x0000;     // Offset  5  Rot 3
    dw    0x07FC,   0x00E0,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0700,   0x07E0,   0x0700,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x00E0,   0x07FC,   0x0000;     // Offset  6  Rot 2
    dw    0x001C,   0x00FC,   0x001C,   0x0000;     // Offset  6  Rot 3
    dw    0x3FE0,   0x0700,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x3800,   0x3F00,   0x3800,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x0700,   0x3FE0,   0x0000;     // Offset  7  Rot 2
    dw    0x00E0,   0x07E0,   0x00E0,   0x0000;     // Offset  7  Rot 3
    dw    0x01FF,   0x0038,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x01C0,   0x01F8,   0x01C0,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0038,   0x01FF,   0x0000;     // Offset  8  Rot 2
    dw    0x0007,   0x003F,   0x0007,   0x0000;     // Offset  8  Rot 3
    dw    0x0FF8,   0x01C0,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0E00,   0x0FC0,   0x0E00,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x01C0,   0x0FF8,   0x0000;     // Offset  9  Rot 2
    dw    0x0038,   0x01F8,   0x0038,   0x0000;     // Offset  9  Rot 3
    dw    0x7FC0,   0x0E00,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x7000,   0x7E00,   0x7000,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x0E00,   0x7FC0,   0x0000;     // Offset 10  Rot 2
    dw    0x01C0,   0x0FC0,   0x01C0,   0x0000;     // Offset 10  Rot 3
    dw    0x007E,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0000,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x0070,   0x007E,   0x0000;     // Offset 11  Rot 2
    dw    0x000E,   0x007E,   0x000E,   0x0000;     // Offset 11  Rot 3
    dw    0x0070,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0000,   0x0070,   0x0000;     // Offset 12  Rot 2
    dw    0x0070,   0x0070,   0x0070,   0x0000;     // Offset 12  Rot 3

S_display_pattern_sets        equ     $;
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x0000,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0000,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x000E,   0x007E,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0070,   0x007E,   0x000E,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x000E,   0x007E,   0x0000;     // Offset  2  Rot 2
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  2  Rot 3
    dw    0x007E,   0x03F0,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0380,   0x03F0,   0x0070,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x007E,   0x03F0,   0x0000;     // Offset  3  Rot 2
    dw    0x0070,   0x007E,   0x000E,   0x0000;     // Offset  3  Rot 3
    dw    0x03F0,   0x1F80,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x1C00,   0x1F80,   0x0380,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x03F0,   0x1F80,   0x0000;     // Offset  4  Rot 2
    dw    0x0380,   0x03F0,   0x0070,   0x0000;     // Offset  4  Rot 3
    dw    0x1F80,   0xFC00,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0xE000,   0xFC00,   0x1C00,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x1F80,   0xFC00,   0x0000;     // Offset  5  Rot 2
    dw    0x1C00,   0x1F80,   0x0380,   0x0000;     // Offset  5  Rot 3
    dw    0x00FC,   0x07E0,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0700,   0x07E0,   0x00E0,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x00FC,   0x07E0,   0x0000;     // Offset  6  Rot 2
    dw    0x00E0,   0x00FC,   0x001C,   0x0000;     // Offset  6  Rot 3
    dw    0x07E0,   0x3F00,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x3800,   0x3F00,   0x0700,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x07E0,   0x3F00,   0x0000;     // Offset  7  Rot 2
    dw    0x0700,   0x07E0,   0x00E0,   0x0000;     // Offset  7  Rot 3
    dw    0x003F,   0x01F8,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x01C0,   0x01F8,   0x0038,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x003F,   0x01F8,   0x0000;     // Offset  8  Rot 2
    dw    0x0038,   0x003F,   0x0007,   0x0000;     // Offset  8  Rot 3
    dw    0x01F8,   0x0FC0,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0E00,   0x0FC0,   0x01C0,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x01F8,   0x0FC0,   0x0000;     // Offset  9  Rot 2
    dw    0x01C0,   0x01F8,   0x0038,   0x0000;     // Offset  9  Rot 3
    dw    0x0FC0,   0x7E00,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x7000,   0x7E00,   0x0E00,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x0FC0,   0x7E00,   0x0000;     // Offset 10  Rot 2
    dw    0x0E00,   0x0FC0,   0x01C0,   0x0000;     // Offset 10  Rot 3
    dw    0x007E,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0000,   0x0070,   0x0070,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x007E,   0x0070,   0x0000;     // Offset 11  Rot 2
    dw    0x0070,   0x007E,   0x000E,   0x0000;     // Offset 11  Rot 3
    dw    0x0070,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0070,   0x0000,   0x0000;     // Offset 12  Rot 2
    dw    0x0000,   0x0070,   0x0070,   0x0000;     // Offset 12  Rot 3

Z_display_pattern_sets        equ     $;
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x0000,   0x000E,   0x000E,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x007E,   0x000E,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x000E,   0x007E,   0x0070,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x007E,   0x000E,   0x0000;     // Offset  2  Rot 2
    dw    0x0000,   0x000E,   0x000E,   0x0000;     // Offset  2  Rot 3
    dw    0x03F0,   0x007E,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0070,   0x03F0,   0x0380,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x03F0,   0x007E,   0x0000;     // Offset  3  Rot 2
    dw    0x000E,   0x007E,   0x0070,   0x0000;     // Offset  3  Rot 3
    dw    0x1F80,   0x03F0,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x0380,   0x1F80,   0x1C00,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x1F80,   0x03F0,   0x0000;     // Offset  4  Rot 2
    dw    0x0070,   0x03F0,   0x0380,   0x0000;     // Offset  4  Rot 3
    dw    0xFC00,   0x1F80,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0x1C00,   0xFC00,   0xE000,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0xFC00,   0x1F80,   0x0000;     // Offset  5  Rot 2
    dw    0x0380,   0x1F80,   0x1C00,   0x0000;     // Offset  5  Rot 3
    dw    0x07E0,   0x00FC,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x00E0,   0x07E0,   0x0700,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x07E0,   0x00FC,   0x0000;     // Offset  6  Rot 2
    dw    0x001C,   0x00FC,   0x00E0,   0x0000;     // Offset  6  Rot 3
    dw    0x3F00,   0x07E0,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x0700,   0x3F00,   0x3800,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x3F00,   0x07E0,   0x0000;     // Offset  7  Rot 2
    dw    0x00E0,   0x07E0,   0x0700,   0x0000;     // Offset  7  Rot 3
    dw    0x01F8,   0x003F,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x0038,   0x01F8,   0x01C0,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x01F8,   0x003F,   0x0000;     // Offset  8  Rot 2
    dw    0x0007,   0x003F,   0x0038,   0x0000;     // Offset  8  Rot 3
    dw    0x0FC0,   0x01F8,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x01C0,   0x0FC0,   0x0E00,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0FC0,   0x01F8,   0x0000;     // Offset  9  Rot 2
    dw    0x0038,   0x01F8,   0x01C0,   0x0000;     // Offset  9  Rot 3
    dw    0x7E00,   0x0FC0,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x0E00,   0x7E00,   0x7000,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x7E00,   0x0FC0,   0x0000;     // Offset 10  Rot 2
    dw    0x01C0,   0x0FC0,   0x0E00,   0x0000;     // Offset 10  Rot 3
    dw    0x0070,   0x007E,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x0070,   0x007E,   0x0000;     // Offset 11  Rot 2
    dw    0x000E,   0x007E,   0x0070,   0x0000;     // Offset 11  Rot 3
    dw    0x0000,   0x0070,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0000,   0x0070,   0x0000;     // Offset 12  Rot 2
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 12  Rot 3

J_display_pattern_sets        equ     $;
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x000E,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000E,   0x000E,   0x000E,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x0000,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x007E,   0x0070,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x0070,   0x0070,   0x007E,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x0000,   0x007E,   0x0000;     // Offset  2  Rot 2
    dw    0x000E,   0x0000,   0x0000,   0x0000;     // Offset  2  Rot 3
    dw    0x03FE,   0x0380,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x0380,   0x0380,   0x03F0,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x000E,   0x03FE,   0x0000;     // Offset  3  Rot 2
    dw    0x007E,   0x000E,   0x000E,   0x0000;     // Offset  3  Rot 3
    dw    0x1FF0,   0x1C00,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x1C00,   0x1C00,   0x1F80,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x0070,   0x1FF0,   0x0000;     // Offset  4  Rot 2
    dw    0x03F0,   0x0070,   0x0070,   0x0000;     // Offset  4  Rot 3
    dw    0xFF80,   0xE000,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0xE000,   0xE000,   0xFC00,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0x0380,   0xFF80,   0x0000;     // Offset  5  Rot 2
    dw    0x1F80,   0x0380,   0x0380,   0x0000;     // Offset  5  Rot 3
    dw    0x07FC,   0x0700,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x0700,   0x0700,   0x07E0,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x001C,   0x07FC,   0x0000;     // Offset  6  Rot 2
    dw    0x00FC,   0x001C,   0x001C,   0x0000;     // Offset  6  Rot 3
    dw    0x3FE0,   0x3800,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x3800,   0x3800,   0x3F00,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x00E0,   0x3FE0,   0x0000;     // Offset  7  Rot 2
    dw    0x07E0,   0x00E0,   0x00E0,   0x0000;     // Offset  7  Rot 3
    dw    0x01FF,   0x01C0,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x01C0,   0x01C0,   0x01F8,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x0007,   0x01FF,   0x0000;     // Offset  8  Rot 2
    dw    0x003F,   0x0007,   0x0007,   0x0000;     // Offset  8  Rot 3
    dw    0x0FF8,   0x0E00,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0E00,   0x0E00,   0x0FC0,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0038,   0x0FF8,   0x0000;     // Offset  9  Rot 2
    dw    0x01F8,   0x0038,   0x0038,   0x0000;     // Offset  9  Rot 3
    dw    0x7FC0,   0x7000,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x7000,   0x7000,   0x7E00,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x01C0,   0x7FC0,   0x0000;     // Offset 10  Rot 2
    dw    0x0FC0,   0x01C0,   0x01C0,   0x0000;     // Offset 10  Rot 3
    dw    0x007E,   0x0000,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0000,   0x0000,   0x0070,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x000E,   0x007E,   0x0000;     // Offset 11  Rot 2
    dw    0x007E,   0x000E,   0x000E,   0x0000;     // Offset 11  Rot 3
    dw    0x0070,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0070,   0x0070,   0x0000;     // Offset 12  Rot 2
    dw    0x0070,   0x0070,   0x0070,   0x0000;     // Offset 12  Rot 3

L_display_pattern_sets        equ     $;
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 1
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  0  Rot 3
    dw    0x000E,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 0
    dw    0x000E,   0x000E,   0x000E,   0x0000;     // Offset  1  Rot 1
    dw    0x0000,   0x000E,   0x000E,   0x0000;     // Offset  1  Rot 2
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset  1  Rot 3
    dw    0x007E,   0x0000,   0x0000,   0x0000;     // Offset  2  Rot 0
    dw    0x007E,   0x0070,   0x0070,   0x0000;     // Offset  2  Rot 1
    dw    0x0000,   0x0070,   0x007E,   0x0000;     // Offset  2  Rot 2
    dw    0x0000,   0x0000,   0x000E,   0x0000;     // Offset  2  Rot 3
    dw    0x03FE,   0x000E,   0x0000,   0x0000;     // Offset  3  Rot 0
    dw    0x03F0,   0x0380,   0x0380,   0x0000;     // Offset  3  Rot 1
    dw    0x0000,   0x0380,   0x03FE,   0x0000;     // Offset  3  Rot 2
    dw    0x000E,   0x000E,   0x007E,   0x0000;     // Offset  3  Rot 3
    dw    0x1FF0,   0x0070,   0x0000,   0x0000;     // Offset  4  Rot 0
    dw    0x1F80,   0x1C00,   0x1C00,   0x0000;     // Offset  4  Rot 1
    dw    0x0000,   0x1C00,   0x1FF0,   0x0000;     // Offset  4  Rot 2
    dw    0x0070,   0x0070,   0x03F0,   0x0000;     // Offset  4  Rot 3
    dw    0xFF80,   0x0380,   0x0000,   0x0000;     // Offset  5  Rot 0
    dw    0xFC00,   0xE000,   0xE000,   0x0000;     // Offset  5  Rot 1
    dw    0x0000,   0xE000,   0xFF80,   0x0000;     // Offset  5  Rot 2
    dw    0x0380,   0x0380,   0x1F80,   0x0000;     // Offset  5  Rot 3
    dw    0x07FC,   0x001C,   0x0000,   0x0000;     // Offset  6  Rot 0
    dw    0x07E0,   0x0700,   0x0700,   0x0000;     // Offset  6  Rot 1
    dw    0x0000,   0x0700,   0x07FC,   0x0000;     // Offset  6  Rot 2
    dw    0x001C,   0x001C,   0x00FC,   0x0000;     // Offset  6  Rot 3
    dw    0x3FE0,   0x00E0,   0x0000,   0x0000;     // Offset  7  Rot 0
    dw    0x3F00,   0x3800,   0x3800,   0x0000;     // Offset  7  Rot 1
    dw    0x0000,   0x3800,   0x3FE0,   0x0000;     // Offset  7  Rot 2
    dw    0x00E0,   0x00E0,   0x07E0,   0x0000;     // Offset  7  Rot 3
    dw    0x01FF,   0x0007,   0x0000,   0x0000;     // Offset  8  Rot 0
    dw    0x01F8,   0x01C0,   0x01C0,   0x0000;     // Offset  8  Rot 1
    dw    0x0000,   0x01C0,   0x01FF,   0x0000;     // Offset  8  Rot 2
    dw    0x0007,   0x0007,   0x003F,   0x0000;     // Offset  8  Rot 3
    dw    0x0FF8,   0x0038,   0x0000,   0x0000;     // Offset  9  Rot 0
    dw    0x0FC0,   0x0E00,   0x0E00,   0x0000;     // Offset  9  Rot 1
    dw    0x0000,   0x0E00,   0x0FF8,   0x0000;     // Offset  9  Rot 2
    dw    0x0038,   0x0038,   0x01F8,   0x0000;     // Offset  9  Rot 3
    dw    0x7FC0,   0x01C0,   0x0000,   0x0000;     // Offset 10  Rot 0
    dw    0x7E00,   0x7000,   0x7000,   0x0000;     // Offset 10  Rot 1
    dw    0x0000,   0x7000,   0x7FC0,   0x0000;     // Offset 10  Rot 2
    dw    0x01C0,   0x01C0,   0x0FC0,   0x0000;     // Offset 10  Rot 3
    dw    0x007E,   0x000E,   0x0000,   0x0000;     // Offset 11  Rot 0
    dw    0x0070,   0x0000,   0x0000,   0x0000;     // Offset 11  Rot 1
    dw    0x0000,   0x0000,   0x007E,   0x0000;     // Offset 11  Rot 2
    dw    0x000E,   0x000E,   0x007E,   0x0000;     // Offset 11  Rot 3
    dw    0x0070,   0x0070,   0x0000,   0x0000;     // Offset 12  Rot 0
    dw    0x0000,   0x0000,   0x0000,   0x0000;     // Offset 12  Rot 1
    dw    0x0000,   0x0000,   0x0070,   0x0000;     // Offset 12  Rot 2
    dw    0x0070,   0x0070,   0x0070,   0x0000;     // Offset 12  Rot 3
