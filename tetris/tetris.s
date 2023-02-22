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
; o one tile is 4x4 big                           ;
; o one block is 3x3 big                          ;
;-------------------------------------------------;
DRAWTILE PROC                                     ;
    MOV cx, 4                                     ;
@@y:                                              ;
    PUSH cx                                       ;
    MOV cx, 4
@@x:                                              ;
    PUSH dx                                       ;
    AND dx, 01000000000000000B                    ;
    POP dx                                        ;
    JZ @@noTile                                   ;
    CALL DRAWBOX                                  ;
@@noTile:                                         ;
                                                  ;
    ADD bx, 3                                     ;
    SHL dx, 1                                     ;
    LOOP @@x                                      ;
                                                  ;
    ADD ax, 3                                     ;
    SUB bx, 3 * 4                                 ;
    POP cx                                        ;
    LOOP @@y                                      ;
    RET                                           ;
DRAWTILE ENDP                                     ;

;-------------------------------------------------;
; DRAW BOX                                        ;
;-( input )---------------------------------------;
; bx = x                                          ;
; ax = y                                          ;
;-( notes )---------------------------------------;
; o one box is 3x3 big                            ;
;-------------------------------------------------;
DRAWBOX PROC                                      ;
    PUSH ax                                       ; can this be optimized out?
    PUSH bx                                       ;
    PUSH cx                                       ;
    PUSH dx                                       ;
                                                  ;
    ;- draw 50x50                                 ;
    MOV cx, 3                                     ;
    MOV bx, 320 / 4                               ;
@@block:                                          ;
    PUSH cx                                       ;
    MOV cx, 03                                    ;
    ;- calculate pixel offset in map              ;
    PUSH ax                                       ;
    MUL bx                                        ; y * 640
    ADD ax, bx                                    ; + offset
    MOV si, ax                                    ;
    POP ax                                        ;
@@line:                                           ;
    MOV es:[si], 0FH                              ;
    INC si                                        ;
    LOOP @@line                                   ;
                                                  ;
    INC ax                                        ;
    POP cx                                        ;
    LOOP @@block                                  ;
                                                  ;
    POP dx                                        ;
    POP cx                                        ;
    POP bx                                        ;
    POP ax                                        ;
    RET                                           ;
DRAWBOX ENDP                                      ;
                                                  ;
TILE_block:                                       ;
    DB 011101100B                                 ;
    DB 011001100B                                 ;
                                                  ;
    ORG 510                                       ;
    DW 0AA55H                                     ;
TETRIS ENDS                                       ;
END                                               ;
