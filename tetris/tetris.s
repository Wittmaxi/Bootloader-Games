;-------------------------------------------------;
; Copyright 2023 Maximilian Wittmer               ;
;-------------------------------------------------;
; Tetris in the bootloader                        ;
;-( bugs )----------------------------------------;
;                                                 ;
;-( todos )---------------------------------------;
;                                                 ;
;-( notes )---------------------------------------;
; o screen rastered down into 20 x 10 blocks      ;
;   all operations should happen in that reference;
;-------------------------------------------------;
                                                  ;
.8086                                             ;
TETRIS SEGMENT                                    ;
;-------------------------------------------------;
; STARTUP                                         ;
;-------------------------------------------------;
; sets up the computer to be in the state we need ;
;-------------------------------------------------;
STARTUP PROC                                      ;
    ;- setup cs and ds                            ;
    DB 0EAH                                       ;
    DW OFFSET @@proceed                           ;
    DW 07C0H                                      ;
@@proceed:                                        ;
    PUSH cs                                       ;
    POP ds                                        ;
    ;- set CGA mode                               ; 320X200
    MOV ax, 0006H                                 ; CGA mode https://www.fountainware.com/EXPL/video_modes.htm
    INT 10H                                       ;
                                                  ;
    ;- set ES to display buffer                   ;
    MOV ax, 0b800H                                ;
    MOV es, ax                                    ;
    MOV di, 0                                     ;

    MOV ax, 1
    MOV bx, 1
    MOV dx, WORD PTR [TILE_block]
    CALL DRAWTILE

@@l:
    HLT
    JMP @@l
STARTUP ENDP                                      ;
                                                  ;
;-------------------------------------------------;
; DRAW TILE                                       ;
;-( input )---------------------------------------;
; bx = x                                          ;
; ax = y                                          ;
; dx = tile                                       ;
;-( notes )---------------------------------------;
; o one tile is 4x4 blocks big                    ;
; o one block is 3x3 big                          ;
;-------------------------------------------------;
DRAWTILE PROC                                     ;
    ;- loop over each row                         ;
    MOV cx, 0304H                                 ; store the column in CL and in CH, store hwo many pixels of height we already have drawn
@@rowsLoop:                                       ;
    OR ch, ch                                     ; did we underflow on the calculation of "repeating columns?"
    JNZ @@noUnderflow                             ;
    MOV ch, 03H                                   ;
@@noUnderflow:                                    ;
    PUSH dx                                       ;
    PUSH cx                                       ;
    ;- calculate new offset in grahpics buf       ;
    PUSH ax                                       ;
    MUL BYTE PTR [screenWidth]                    ;
    MOV di, ax                                    ;
    POP ax                                        ;
    ;-- add x                                     ;
    ADD di, bx                                    ;
                                                  ;
    ;- for each cell                              ;
    MOV cx, 4                                     ;
@@colLoop:                                        ;
    ;-- in each cell, loop through the four coor bits
    PUSH dx                                       ;
    AND dx, 01000000000000000B                    ;
    POP dx                                        ;
    JZ @@noTileHere                               ;
    ;--- draw the actual tile                     ;
    MOV WORD PTR es:[di], 0505H                   ; unrolled loop takes less bytes
    ADD di, 2                                     ;
    MOV BYTE PTR es:[di], 5                       ;
    JMP @@tileDrawn                               ;
@@noTileHere:                                     ;
    INC di                                        ;
    INC di                                        ;
@@tileDrawn:                                      ;
    INC di                                        ;
    SHL dx, 1                                     ;
    LOOP @@colLoop                                ;
                                                  ;
    ;-- end of cell loop -------------------------;
    POP cx                                        ;
    DEC ch                                        ;
    OR ch, ch                                     ;
    JZ @@noRepeatCol                              ;
    INC cl                                        ;
    POP dx                                        ;
    JMP @@repeatingCol                            ;
@@noRepeatCol:                                    ; because we want to repeat each column 3 times (3x3 for one tile!)
    SUB sp, 2                                     ; discard the old DX
@@repeatingCol:                                   ;
    INC ax
    LOOP @@rowsLoop                               ;

    MOV cx, 0b00bH

    RET
DRAWTILE ENDP                                     ;

TILE_block:                                       ;
    DB 010011000B                                 ;
    DB 011001010B                                 ;
screenWidth:                                      ;
    DB 320/4                                      ;
                                                  ;
    ORG 510                                       ;
    DW 0AA55H                                     ;
TETRIS ENDS                                       ;
END                                               ;
