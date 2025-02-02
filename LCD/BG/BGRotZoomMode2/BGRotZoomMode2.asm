; Game Boy Advance 'Bare Metal' BG Mode 2 Rotate & Zoom Demo by krom (Peter Lemon):
; Direction Pad Changes BG X/Y Position
; L/R Buttons Rotate BG Anti-Clockwise/Clockwise
; A/B Buttons Zoom BG Out/In
; Start Button Changes Mosaic Level
; Select Button Resets To Default Settings

format binary as 'gba'
org $8000000
include 'LIB\FASMARM.INC' ; Include FASMARM Macros
include 'LIB\GBA.INC' ; Include GBA Definitions
include 'LIB\GBA_DMA.INC' ; Include GBA DMA Macros
include 'LIB\GBA_KEYPAD.INC' ; Include GBA Keypad Macros
include 'LIB\GBA_LCD.INC' ; Include GBA LCD Macros
include 'LIB\GBA_HEADER.ASM' ; Include GBA Header & ROM Entry Point

macro Control { ; Macro To Handle Control Input
  mov r0,BGAffineSource ; R0 = Address Of Parameter Table
  mov r1,IO ; R1 = GBA I/O Base Offset
  ldr r2,[r1,KEYINPUT] ; R2 = Key Input

  ; Move Left & Right
  ldrh r3,[r0,8] ; R3 = X Center
  tst r2,KEY_RIGHT ; Test Right Direction Pad Button
  addeq r3,4 ; IF (Right Pressed) X Center += 4
  tst r2,KEY_LEFT ; Test Left Direction Pad Button
  subeq r3,4 ; IF (Left Pressed) X Center -= 4
  strh r3,[r0,8] ; Stores X Center To Parameter Table (Screen X Of Center)

  ; Move Up & Down
  ldrh r3,[r0,10] ; R3 = Y Center
  tst r2,KEY_DOWN ; Test Down Direction Pad Button
  addeq r3,4 ; IF (Down Pressed) Y Center += 4
  tst r2,KEY_UP ; Test Up Direction Pad Button
  subeq r3,4 ; IF (Up Pressed) Y Center -= 4
  strh r3,[r0,10] ; Stores Y Center To Parameter Table (Screen Y Of Center)

  ; Zoom On A & B (X & Y Zoom Is Equal)
  ldrh r3,[r0,12] ; R3 = Zoom Variable
  tst r2,KEY_A ; Test A Button
  addeq r3,4 ; IF (A Pressed) Zoom += 4
  tst r2,KEY_B ; Test B Button
  subeq r3,4 ; IF (B Pressed) Zoom -= 4
  cmp r3,0 ; IF (Zoom <= 0)
  movle r3,4 ; Zoom = 4
  strh r3,[r0,12] ; Store Zoom To Parameter Table (X Scale Factor)
  strh r3,[r0,14] ; Store Zoom To Parameter Table (Y Scale Factor)

  ; Rotate On L & R
  ldrh r3,[r0,16] ; R3 = Rotation Variable
  tst r2,KEY_L ; Test L Button
  addeq r3,512 ; IF (L Pressed) Rotate += 512 (Anti-Clockwise)
  tst r2,KEY_R ; Test R Button
  subeq r3,512 ; IF (R Pressed) Rotate -= 512 (Clockwise)
  strh r3,[r0,16] ; Store Rotate To Parameter Table (Rotation)

  ; Mosaic Level Increased IF Start Pressed
  ldrh r3,[r0,18] ; R3 = Mosaic Variable
  tst r2,KEY_START ; Test Start Button
  addeq r3,17 ; IF (Start Pressed) Mosaic += 17 (X & Y Size At Same Time)
  cmp r3,255 ; IF (Mosaic > 255) (255 = Full X & Y Mosaic Resolution)
  movgt r3,0 ; Mosaic = 0 (Mosaic Reset)
  strh r3,[r1,MOSAIC] ; Store Mosaic Amount To Mosaic Register
  strh r3,[r0,18] ; Store Mosaic Amount To Parameter Table (Mosaic Amount)

  ; Reset IF Select Pressed
  tst r2,KEY_SELECT ; Test Select Button
  bne ControlResetEnd ; IF (Select Not Pressed) Skip To ControlResetEnd
  mov r3,$00020000 ; R3 = Default Screen Center X/Y
  str r3,[r0,0] ; Store Screen Center X To Parameter Table
  str r3,[r0,4] ; Store Screen Center Y To Parameter Table
  mov r3,$0078 ; R3 = Default Screen X Of Center
  strh r3,[r0,8] ; Store Screen X Of Center To Parameter Table
  mov r3,$0050 ; R3 = Default Screen Y Of Center
  strh r3,[r0,10] ; Store Screen Y Of Center To Parameter Table
  mov r3,$0100 ; R3 = Default Screen X/Y Scale Factor
  strh r3,[r0,12] ; Store Default Screen X Scale Factor To Parameter Table
  strh r3,[r0,14] ; Store Default Screen Y Scale Factor To Parameter Table
  mov r3,$0000 ; R3 = Default Rotation & Mosaic Amount
  strh r3,[r0,16] ; Store Default Rotation To Parameter Table
  strh r3,[r0,18] ; Store Default Mosaic To Parameter Table
  ControlResetEnd:

  orr r1,BG2PA ; Update BG Parameters
  mov r2,1 ; (BIOS Call Requires R0 To Point To Parameter Table)
  swi $0E0000 ; Bios Call To Calculate All The Correct BG Parameters According To The Controls
}

copycode:
  adr r0,startcode
  mov r1,IWRAM
  imm32 r2,endcopy
  clp:
    ldr r3,[r0],4
    str r3,[r1],4
    cmp r1,r2
    bmi clp
  imm32 r0,start
  bx r0
startcode:
  org IWRAM

; Variable Data
BGAffineSource: ; Memory Area Used To Set BG Affine Transformations Using BIOS Call
  ; Center Of Rotation In Original Image (Last 8-Bits Fractional)
  dw $00020000 ; X
  dw $00020000 ; Y
  ; Center Of Rotation On Screen
  dh $0078 ; X
  dh $0050 ; Y
  ; Scaling Ratios (Last 8-Bits Fractional)
  dh $0100 ; X
  dh $0100 ; Y
  ; Angle Of Rotation ($0000..$FFFF Anti-Clockwise)
  dh $0000
  ; Mosaic Amount
  dh $0000

start:
  mov r0,IO
  mov r1,MODE_2
  orr r1,BG2_ENABLE
  str r1,[r0]

  imm16 r1,1100100001000000b ; BG Tile Offset = 0, Enable Mosaic, BG Map Offset = 16384, Map Size = 128x128 Tiles
  strh r1,[r0,BG2CNT]

  DMA32 BGPAL, VPAL, 16 ; DMA BG Palette To Color Mem
  DMA32 BGIMG, VRAM, 2736 ; DMA BG Image To VRAM
  DMA32 BGMAP, VRAM+16384, 4096 ; DMA BG Map To VRAM

Loop:
    VBlank  ; Wait Until VBlank
    Control ; Update BG According To Controls
    b Loop

endcopy: ; End Of Program Copy Code

; Static Data (ROM)
org startcode + (endcopy - IWRAM)
BGIMG: file 'BG.img' ; Include BG Image Data (10944 Bytes)
BGMAP: file 'BG.map' ; Include BG Map Data (16384 Bytes)
BGPAL: file 'BG.pal' ; Include BG Palette Data (64 Bytes)