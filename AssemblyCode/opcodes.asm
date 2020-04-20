
        org  10;
        
        ds   5,3;
        
x       equ 3;
        db      x;
        
        // go through instruction set numerically
        // MOVER
        sxt     r0;
        move    r1,r0;
        move    r2,r0;
        move    r3,r0;
        move    r0,r1;
        sxt     r1;
        move    r2,r1;
        move    r3,r1;
        move    r0,r2;
        move    r1,r2;
        sxt     r2;
        move    r3,r2;
        move    r0,r3;
        move    r1,r3;
        move    r2,r3;
        sxt     r3;

        // AND
        test    r0;
        and     r1,r0;
        and     r2,r0;
        and     r3,r0;
        and     r0,r1;
        test    r1;
        and     r2,r1;
        and     r3,r1;
        and     r0,r2;
        and     r1,r2;
        test    r2;
        and     r3,r2;
        and     r0,r3;
        and     r1,r3;
        and     r2,r3;
        test    r3;

        // XOR
        xor     r0,r0;
        xor     r1,r0;
        xor     r2,r0;
        xor     r3,r0;
        xor     r0,r1;
        xor     r1,r1;
        xor     r2,r1;
        xor     r3,r1;
        xor     r0,r2;
        xor     r1,r2;
        xor     r2,r2;
        xor     r3,r2;
        xor     r0,r3;
        xor     r1,r3;
        xor     r2,r3;
        xor     r3,r3;


        // OR
        inv     r0;
        or      r1,r0;
        or      r2,r0;
        or      r3,r0;
        or      r0,r1;
        inv     r1;
        or      r2,r1;
        or      r3,r1;
        or      r0,r2;
        or      r1,r2;
        inv     r2;
        or      r3,r2;
        or      r0,r3;
        or      r1,r3;
        or      r2,r3;
        inv     r3;

        // ADD
        add     r0,r0;
        add     r1,r0;
        add     r2,r0;
        add     r3,r0;
        add     r0,r1;
        add     r1,r1;
        add     r2,r1;
        add     r3,r1;
        add     r0,r2;
        add     r1,r2;
        add     r2,r2;
        add     r3,r2;
        add     r0,r3;
        add     r1,r3;
        add     r2,r3;
        add     r3,r3;

        // ADDQ
        addq    r0,#2;
        addq    r1,#2;
        addq    r2,#2;
        addq    r3,#2;
        addq    r0,#1;
        addq    r1,#1;
        addq    r2,#1;
        addq    r3,#1;
        addq    r0,#-2;
        addq    r1,#-2;
        addq    r2,#-2;
        addq    r3,#-2;
        addq    r0,#-1;
        addq    r1,#-1;
        addq    r2,#-1;
        addq    r3,#-1;
        
        // ADD
        neg     r0;
        sub     r1,r0;
        sub     r2,r0;
        sub     r3,r0;
        sub     r0,r1;
        neg     r1;
        sub     r2,r1;
        sub     r3,r1;
        sub     r0,r2;
        sub     r1,r2;
        neg     r2;
        sub     r3,r2;
        sub     r0,r3;
        sub     r1,r3;
        sub     r2,r3;
        neg     r3;

        // CMP
        abs     r0;
        cmp     r1,r0;
        cmp     r2,r0;
        cmp     r3,r0;
        cmp     r0,r1;
        abs     r1;
        cmp     r2,r1;
        cmp     r3,r1;
        cmp     r0,r2;
        cmp     r1,r2;
        abs     r2;
        cmp     r3,r2;
        cmp     r0,r3;
        cmp     r1,r3;
        cmp     r2,r3;
        abs     r3;
        
        // INDIRECT
        ld.w    r0,(r2);
        ld.w    r1,(r2);
        ld.w    r0,(r3);
        ld.w    r1,(r3);
        ld.b    r0,(r2);
        ld.b    r1,(r2);
        ld.b    r0,(r3);
        ld.b    r1,(r3);
        st.w    (r2),r0;
        st.w    (r2),r1;
        st.w    (r3),r0;
        st.w    (r3),r1;
        st.b    (r2),r0;
        st.b    (r2),r1;
        st.b    (r3),r0;
        st.b    (r3),r1;
        
        // POSTINC
        ld.w    r0,(r2++);
        ld.w    r1,(r2++);
        ld.w    r0,(r3++);
        ld.w    r1,(r3++);
        ld.b    r0,(r2++);
        ld.b    r1,(r2++);
        ld.b    r0,(r3++);
        ld.b    r1,(r3++);
        st.w    (r2++),r0;
        st.w    (r2++),r1;
        st.w    (r3++),r0;
        st.w    (r3++),r1;
        st.b    (r2++),r0;
        st.b    (r2++),r1;
        st.b    (r3++),r0;
        st.b    (r3++),r1;
        
        // STACKREL
        ld.w    r0,(sp+0x78);
        ld.w    r1,(sp+0x78);
        ld.w    r2,(sp+0x78);
        ld.w    r3,(sp+0x78);
        ld.b    r0,(sp+0x78);
        ld.b    r1,(sp+0x78);
        ld.b    r2,(sp+0x78);
        ld.b    r3,(sp+0x78);
        st.w    (sp+0x78),r0;
        st.w    (sp+0x78),r1;
        st.w    (sp+0x78),r2;
        st.w    (sp+0x78),r3;
        st.b    (sp+0x78),r0;
        st.b    (sp+0x78),r1;
        st.b    (sp+0x78),r2;
        st.b    (sp+0x78),r3;
        
        // ABSOLUTE
        ld.w    r0,0xCAFE;
        ld.w    r1,0xCAFE;
        ld.w    r2,0xCAFE;
        ld.w    r3,0xCAFE;
        ld.b    r0,0xCAFE;
        ld.b    r1,0xCAFE;
        ld.b    r2,0xCAFE;
        ld.b    r3,0xCAFE;
        st.w    0xCAFE,r0;
        st.w    0xCAFE,r1;
        st.w    0xCAFE,r2;
        st.w    0xCAFE,r3;
        st.b    0xCAFE,r0;
        st.b    0xCAFE,r1;
        st.b    0xCAFE,r2;
        st.b    0xCAFE,r3;
        
        // PUSH/POP
        pop     r0;
        pop     r1;
        pop     r2;
        pop     r3;
        pop     ps;
        // not used any more....reset;
        ret;
        reti;
        push    r0;
        push    r1;
        push    r2;
        push    r3;
        push    ps;
        trap;
        jsr     (r0);
        jsr     0x1234;
        
        // IMMEDIATE
        ld.w    r0,#0xCAFE;
        ld.w    r1,#0xCAFE;
        ld.w    r2,#0xCAFE;
        ld.w    r3,#0xCAFE;
        ld.b    r0,#0xCAFE;
        ld.b    r1,#0xCAFE;
        ld.b    r2,#0xCAFE;
        ld.b    r3,#0xCAFE;
        
        // shift
        asl     r0,r3;
        asl     r1,r2;
        asl     r2,r1;
        asl     r3,r0;
//        asr     r0,r1;
        lsl     r0,r1;
//        lsr     r0,r1;
        rol     r0,r1;
//        ror     r0,r1;
        roxl    r0,r1;
//        roxr    r0,r1;
        
        asl.wt     r0,r3;
        asl.wt     r1,r2;
        asl.wt     r2,r1;
        asl.wt     r3,r0;

        asl     r1,#7;
        asr     r1,#7;
        lsl     r1,#7;
        lsr     r1,#7;
        rol     r1,#7;
        ror     r1,#7;
        roxl    r1,#7;
        roxr    r1,#7;
        
        // bit
        btst    r0,r3;
        btst    r1,r2;
        btst    r2,r1;
        btst    r3,r0;
        bchg    r0,r1;
        bclr    r0,r1;
        bset    r0,r1;
        
        btst    r1,#7;
        bchg    r1,#7;
        bclr    r1,#7;
        bset    r1,#7;
        
        // BRANCH
target: nop;
        bus     target;
        buc     target;        
        bhi     target;
        bls     target;
        bcc     target;
        bcs     target;
        bne     target;
        beq     target;
        bvc     target;
        bvs     target;
        bpl     target;
        bmi     target;
        bge     target;
        blt     target;
        bgt     target;
        ble     target;

        // MISC
        move    r0,sp;
        move    sp,r0;
        jmp     (r0);
        jmp     0x1234;
        andi    ps,#0x1234;
        ori     ps,#0x1234;
        addi    sp,#0x1234;
        sqrt;
        mulu;
        muls;
        divu;
        divs;
        addx    r0,r1;
        subx    r0,r1;
        negx    r0;
        nop;
        
        
        db      1,2,3,4,0b1010;
        dw      21,500,0xdeadbeef,0xCAFe;
        dl      0x12345678, 0xdeadbeef;
        dm      "Hi there";
        
label_600:   org      600;
also_600     EQU     $;
        ds      10;
        jmp     label_600;
        jmp     also_600;
        
        reti;
        
        