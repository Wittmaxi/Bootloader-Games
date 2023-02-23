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
    ;- setup variables                            ;
    MOV WORD PTR es:[CURRENT_POSITION_Y], 0       ;
    MOV WORD PTR es:[CURRENT_POSITION_X], 0       ;
    ;- set ES to display buffer                   ;
    MOV ax, 0b800H                                ;
    MOV es, ax                                    ;
    MOV di, 0                                     ;

    CALL PICKTILE

@@gameLoop:
    MOV ax, WORD PTR es:[CURRENT_POSITION_Y]
    MOV bx, WORD PTR es:[CURRENT_POSITION_X]
    MOV dx, WORD PTR [CURRENT_TILE]
    CALL DRAWTILE

    ;- wait loop                                  ;
    MOV cx, 08                                    ;
@@:                                               ;
                                                  ;
    ;-- get keyboard scancode                     ;
    MOV ah, 01                                    ;
    INT 16H                                       ;
    JZ @@noKey                                    ;
    XOR ax, ax                                    ;
    INT 16H                                       ;
    ;--- move to the left?                        ;
    SUB al, 'h'                                   ;
    JNZ @F                                        ;
    DEC WORD PTR es:[CURRENT_POSITION_X]          ;
@@:                                               ;
    ;--- move to the right?                       ;
    SUB al, 'l' - 'h'                             ;
    JNZ @F                                        ;
    INC WORD PTR es:[CURRENT_POSITION_X]          ;
@@:                                               ;
@@noKey:                                          ;
    HLT                                           ;
    LOOP @B                                       ;
                                                  ;
    ;- end of loop: prepare next loop             ;
    INC WORD PTR es:[CURRENT_POSITION_Y]          ;
    CMP es:[CURRENT_POSITION_Y], 20 * 2           ;
    JLE @F                                        ;
    CALL CONSOLIDATETILE                          ;
@@:
    CALL CLEAROLDPLAYTILE                         ;
    JMP @@gameLoop

@@l:
    HLT
    JMP @@l
STARTUP ENDP                                      ;
                                                  ;
;-------------------------------------------------;
; PICKTILE                                        ;
;-------------------------------------------------;
; picks a tile, based on the CPU cycles counter   ;
;-------------------------------------------------;
PICKTILE PROC                                     ;
    INT 01AH                                      ;
    MOV al, dl                                    ;
    SHR cl, 1
    SHR cl, 1
    SHR cl, 1
    XCHG al, dl                                   ;
    CWD                                           ;
    SHL al, 1
    SHL al, 1

    MOV bx, WORD PTR [ALL_TILES + al]
    MOV es:[CURRENT_TILE], bx                     ;

    RET
PICKTILE ENDP                                     ;
                                                  ;
;-------------------------------------------------;
; CLEAROLDPLAYTILE                                ;
;-------------------------------------------------;
; currently active playtiles are stored with 042D ;
; remove those in the display buffer              ;
;-------------------------------------------------;
CLEAROLDPLAYTILE PROC                             ;
    MOV cx, 640 / 8 * 200                         ; iterate over every byte of our screen!
    XOR di, di                                    ; possible optimization by putting this into the mainloop?
@@l:                                              ;
    CMP BYTE PTR es:[di], 042D                    ;
    JNE @F                                        ;
CLEAROP LABEL NEAR                                ;
    MOV BYTE PTR es:[di], 000H                    ; this operation will be manipulated by CONSOLIDATETILE
@@:                                               ;
    INC di                                        ;
    LOOP @@l                                      ;
                                                  ;
    RET                                           ;
CLEAROLDPLAYTILE ENDP                             ;
                                                  ;
;-------------------------------------------------;
; CONSOLIDATETILE                                 ;
;-------------------------------------------------;
; "consolidates" all tiles to the value of FF     ;
; Sinc CLEAROLDPLAYTILE implements the same loop, ;
; we can get away with simply manipulating it's code
; to fill the values with FFH instead of 00H      ;
;-------------------------------------------------;
CONSOLIDATETILE PROC                              ;
    MOV BYTE PTR CS:[CLEAROP + 3], 0FFH           ; Manipulate the code of ClearOldPlaytile
    CALL CLEAROLDPLAYTILE                         ;
    MOV BYTE PTR CS:[CLEAROP + 3], 000H           ; restore CLEAROLDPLAYTILE
    RET                                           ;
CONSOLIDATETILE ENDP                              ;
                                                  ;
;-------------------------------------------------;
; DRAW TILE                                       ;
;-( input )---------------------------------------;
; bx = x                                          ;
; ax = y                                          ;
; dx = tile                                       ;
;-( notes )---------------------------------------;
; o one tile is 4x4 blocks big                    ;
; o one block is 2x2 big                          ;
; o does collision detection                      ;
;-------------------------------------------------;
DRAWTILE PROC                                     ;
    MOV ES:[COLLISION_EVENT], 0                   ;
    ;- loop over each row                         ;
    MOV cl, 04H                                   ; store the column in CL and in CH, store hwo many pixels of height we already have drawn
@@rowsLoop:                                       ;
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
    AND dh, 010000000B                            ;

    POP dx                                        ;
    JZ @@noTileHere                               ;
    ;--- draw the actual tile                     ;
    CMP BYTE PTR es:[di], 0FFH                    ;
    JNE @@noCollision                             ;
    MOV BYTE PTR es:[COLLISION_EVENT], 1          ;
@@noCollision:                                    ;
    MOV BYTE PTR es:[di], 042D                    ; unrolled loop takes less bytes
@@noTileHere:                                     ;
    INC di                                        ;
    SHL dx, 1                                     ;
    LOOP @@colLoop                                ;
                                                  ;
    ;-- end of cell loop -------------------------;
    POP cx                                        ;
    INC ax                                        ;
    LOOP @@rowsLoop                               ;
    ;- all done                                   ;
                                                  ;
    ;- check: was there a collision?              ;
    CMP BYTE PTR es:[COLLISION_EVENT], 1          ;
    JNE @F                                        ;
    ;-- there was! Let's consolidate and generate a new tile
    CALL CONSOLIDATETILE                          ;
@@:                                               ;
                                                  ;
    RETN                                          ;
DRAWTILE ENDP                                     ;

    ;- equates                                    ; all write to video memory, in an unused address
    GARBAGE_BIN EQU 20000                         ; W
    CURRENT_TILE EQU 20002                        ; W
    CURRENT_POSITION_X EQU 20004                  ; W
    CURRENT_POSITION_Y EQU 20006                  ; W
    COLLISION_EVENT EQU 20008                     ; B
                                                  ;
    ;- each tile is a W                           ;
ALL_TILES:
TILE_line7:                                       ;
    DB 010001000B                                 ;
    DB 010001000B                                 ;
TILE_line6:                                       ;
    DB 010001000B                                 ;
    DB 010001000B                                 ;
TILE_line5:                                       ;
    DB 010001000B                                 ;
    DB 010001000B                                 ;
TILE_line4:                                       ;
    DB 010001000B                                 ;
    DB 010001000B                                 ;
TILE_line2:                                       ;
    DB 010001000B                                 ;
    DB 010001000B                                 ;
TILE_line:                                       ;
    DB 010001000B                                 ;
    DB 010001000B                                 ;
TILE_block:                                       ;
    DB 011001100B                                 ;
    DB 000000000B                                 ;
TILE_T:                                           ;
    DB 000000000B                                 ;
    DB 000100111B                                 ;
screenWidth:                                      ;
    DB 640/8                                      ;
                                                  ;
    ORG 510                                       ;
    DW 0AA55H                                     ;
TETRIS ENDS                                       ;
END                                               ;
