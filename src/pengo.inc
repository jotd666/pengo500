

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
	OPT_QUICK_MAZE_DRAW=1
***
*** end of BUILD OPTIONS
***




* sound ordinals

    .equ  CREDIT_SND,         0x00
    .equ  SHOOT_SND,         0x01
    .equ  INTRO_SND,      0x02
    .equ  ALIEN_SHOT_SND,      0x03
    .equ  FLAGSHIP_SHOT_SND,      0x04
    .equ  PLAYER_SHOT_SND,      0x05
    .equ  ATTACK_END_SND,      0x06
    .equ  SWARM_1_SND,      0x07
    .equ  EXTRA_LIFE_SND,      0x08
    .equ  ATTACK_START_SND,      0x09
    .equ  EMPTY_SND,      0x0A


    
