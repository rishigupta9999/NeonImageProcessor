//
//  MenuFlowTypes.h
//  Neon21
//
//  Copyright Neon Games 2010. All rights reserved.
//

typedef enum
{
    ProgressPoint_NoGameInProgress,
    ProgressPoint_FirstTimePlaying,
    ProgressPoint_Movie_Intro,
    ProgressPoint_MainMenu_Load,
    ProgressPoint_Cutscene_LoserBus_Ep1,
    ProgressPoint_Cutscene_IChaChingIntro_OneOff,
    ProgressPoint_Neon21_IChaChing_LowStakes,
    ProgressPoint_Cutscene_JohnnyPokerTourney_OneOff,
    ProgressPoint_Cutscene_LoserBus_Ep2,
    ProgressPoint_Run21_IChaChing_LowStakes,
    ProgressPoint_Cutscene_LoserBus_Ep3,
    ProgressPoint_Neon21_IChaChing_HighStakes,
    ProgressPoint_Cutscene_21SquaredIntro_OneOff,
    ProgressPoint_21Squared_IChaChing_LowStakes,
    ProgressPoint_Cutscene_EndOfDemo_OneOff,
    ProgressPoint_Cutscene_BrokeTheBank_OneOff,
    ProgressPoint_Cutscene_FjordKnoxIntro_OneOff,
    ProgressPoint_Neon21_FjordKnox_LowStakes,
    ProgressPoint_Cutscene_FjordKnox_Ep1,
    ProgressPoint_Run21_FjordKnox_MidStakes,
    ProgressPoint_Cutscene_FjordKnox_Ep2,
    ProgressPoint_Neon21_FjordKnox_HighStakes,
    ProgressPoint_Cutscene_FjordKnox_Ep3,
    ProgressPoint_21Squared_FjordKnox_MidStakes,
    ProgressPoint_Cutscene_GummySlotsIntro_OneOff,
    ProgressPoint_Cutscene_HighRollers_Ep1,
    ProgressPoint_Neon21_GummySlots_HighStakes,
    ProgressPoint_Cutscene_HighRollers_Ep2,
    ProgressPoint_Run21_GummySlots_HighStakes,
    ProgressPoint_Cutscene_HighRollers_Ep3,
    ProgressPoint_21Squared_GummySlots_HighStakes,
    ProgressPoint_Movie_Ending,
    ProgressPoint_BeatGameScreen,
    ProgressPoint_Invalid,
    ProgressPoint_MAX = ProgressPoint_Invalid,
} ENeonEscapeProgress;
// Update Strings in .m

typedef enum
{
	NeonMenu_NONE,
	NeonMenu_AppStart,
	NeonMenu_NeonLogo,
	NeonMenu_PressStart,
	NeonMenu_MainMenu,
	NeonMenu_NewContinueGame,
    NeonMenu_FreePlay,
    NeonMenu_Options,
    NeonMenu_HowToPlay,
    NeonMenu_HowToPlay_Basics,
    NeonMenu_HowToPlay_Basics_Story,
    NeonMenu_HowToPlay_Basics_Objective,
    NeonMenu_HowToPlay_Companions,
    NeonMenu_HowToPlay_Companions_HowWork,
    NeonMenu_HowToPlay_Companions_WhoAreThey,
    NeonMenu_HowToPlay_Companions_HowGetMore,
    NeonMenu_HowToPlay_GameRules,
    NeonMenu_HowToPlay_GameRules_Neon21,
    NeonMenu_HowToPlay_GameRules_TripleSwitch,
    NeonMenu_HowToPlay_GameRules_Run21,
    NeonMenu_HowToPlay_GameRules_21Squared,
    NeonMenu_Overworld,
    NeonMenu_Overworld_Gracys,
    NeonMenu_Overworld_IChaChing,
    NeonMenu_Overworld_FjordKnox,
    NeonMenu_Overworld_GummySlots,
    NeonMenu_Overworld_CharacterCloseup,
	NeonMenu_MAX,
} ENeonMenu;
