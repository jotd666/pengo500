

***    
*** BUILD OPTIONS
***

    * hardware options
    OPT_DISABLE_BG_LAYER=0
    OPT_DISABLE_SPRITES=0
   
	* cheats to test game
    * score is decimal format
    OPT_START_SCORE=0
	OPT_SKIP_THANKS_SCREEN=0
	OPT_SKIP_TITLE_SCREEN=0
	OPT_SKIP_ICE_PACK_SCREEN=0
	OPT_SKIP_GAME_DEMO=0
	OPT_ONLY_ONE_LIFE=0
	* test mode: only first snobee is active
	OPT_ONLY_ONE_SNOBEE=0
	* draw maze quicky, like set 2, quick game start!
	OPT_QUICK_MAZE_DRAW=0
	* make diamonds almost grouped
	OPT_ALMOST_GROUP_DIAMONDS=0
***
*** end of BUILD OPTIONS
***




* sound ordinals

    .equ  CREDIT_SND,         0x00
    .equ  DRAW_MAZE_SND,         0x01
    .equ  START_SND,         0x02
    .equ  DIAMONDS_ALIGNED_SND,         0x03
    .equ  LEVEL_COMPLETED_SND,         0x04
    .equ  PLAYER_DIES_SND,         0x05
    .equ  IN_GAME_MUSIC_SND,         0x08
    *.equ  IN_GAME_MUSIC_FAST_SND,         0x09
    .equ  HISCORE_MUSIC_SND,         0x09
    .equ  SNOBEE_EATEN_SND,         0x12
    .equ  SNOBEE_HATCHING_SND,         0x13
    .equ  SNOBEE_STUNNED_SND,         0x16
    .equ  EXTRA_LIFE_SND,         0x19
    .equ  BLOCK_BROKEN_SND,         0x1A
    .equ  SHAKE_WALL_SND,         0x1B


    
