

***    
*** BUILD OPTIONS
***

    * hardware options
    OPT_DISABLE_BG_LAYER=0
    OPT_DISABLE_SPRITES=0
   
	* cheats to test game
    * score is BCD format, only 6 digits
    OPT_START_SCORE=0x000000
	OPT_SKIP_THANKS_SCREEN=0
	OPT_SKIP_TITLE_SCREEN=0
	OPT_SKIP_ICE_PACK_SCREEN=0
	* test mode: only first snobee is active
	OPT_ONLY_ONE_SNOBEE=0
	* draw maze quicky, like set 2, quick game start!
	OPT_QUICK_MAZE_DRAW=0
***
*** end of BUILD OPTIONS
***




* sound ordinals

    .equ  CREDIT_SND,         0x00
    .equ  SNOBEE_EATEN_SND,         0x12
    .equ  SNOBEE_HATCHING_SND,         0x13
    .equ  SNOBEE_STUNNED_SND,         0x16
    .equ  BLOCK_BROKEN_SND,         0x1A
    .equ  SHAKE_WALL_SND,         0x1B


    
