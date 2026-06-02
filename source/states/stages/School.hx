package states.stages;

import states.stages.objects.*;
import substates.GameOverSubstate;
import cutscenes.DialogueBox;

import openfl.utils.Assets as OpenFlAssets;

class School extends BaseStage
{
	var bgGirls:BackgroundGirls;
	override function create()
	{
		var _song = PlayState.SONG;
		if(_song.gameOverSound == null || _song.gameOverSound.trim().length < 1) GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pixel';
		if(_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1) GameOverSubstate.loopSoundName = 'gameOver-pixel';
		if(_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1) GameOverSubstate.endSoundName = 'gameOverEnd-pixel';
		if(_song.gameOverChar == null || _song.gameOverChar.trim().length < 1) GameOverSubstate.characterName = 'bf-pixel-dead';

		var bgSky:BGSprite = new BGSprite('weeb/weebSky', -626, -78, 0.2, 0.2);
		bgSky.antialiasing = false;
		bgSky.scale.set(6, 6);
		bgSky.updateHitbox();
		add(bgSky);

		var bgBackTrees:BGSprite = new BGSprite('weeb/weebBackTrees', -842, -80, 0.5, 0.5);
		bgBackTrees.antialiasing = false;
		bgBackTrees.scale.set(6, 6);
		bgBackTrees.updateHitbox();
		add(bgBackTrees);

		var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', -816, -38, 0.75, 0.75);
		bgSchool.antialiasing = false;
		bgSchool.scale.set(6, 6);
		bgSchool.updateHitbox();
		add(bgSchool);

		var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', -662, 6, 1, 1);
		bgStreet.antialiasing = false;
		bgStreet.scale.set(6, 6);
		bgStreet.updateHitbox();
		add(bgStreet);

		if (!ClientPrefs.data.lowQuality)
		{
			var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack', -500, 6, 1, 1);
			fgTrees.antialiasing = false;
			fgTrees.scale.set(6, 6);
			fgTrees.updateHitbox();
			add(fgTrees);
		}

		var bgTrees:FlxSprite = new FlxSprite(-806, -1050);
		bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
		bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
		bgTrees.animation.play('treeLoop');
		bgTrees.antialiasing = false;
		bgTrees.scale.set(6, 6);
		bgTrees.updateHitbox();
		add(bgTrees);

		if (!ClientPrefs.data.lowQuality)
		{
			var treeLeaves:BGSprite = new BGSprite('weeb/petals', -20, -40, 0.85, 0.85, ['PETALS ALL'], true);
			treeLeaves.antialiasing = false;
			treeLeaves.scale.set(6, 6);
			treeLeaves.updateHitbox();
			add(treeLeaves);
		
			bgGirls = new BackgroundGirls(-646, 222);
			add(bgGirls);
		}

		setDefaultGF('gf-pixel');

		switch (songName)
		{
			case 'senpai':
				FlxG.sound.playMusic(Paths.music('Lunchbox'), 0);
				FlxG.sound.music.fadeIn(1, 0, 0.8);
			case 'roses':
				FlxG.sound.play(Paths.sound('ANGRY_TEXT_BOX'));
		}
		if(isStoryMode && !seenCutscene)
		{
			if(songName == 'roses') FlxG.sound.play(Paths.sound('ANGRY'));
			initDoof();
			setStartCallback(schoolIntro);
		}
	}

	override function beatHit()
	{
		if (bgGirls != null) bgGirls.dance();
	}

	// For events
	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "BG Freaks Expression":
				if(bgGirls != null) bgGirls.swapDanceType();
		}
	}

	var doof:DialogueBox = null;
	function initDoof()
	{
		var file:String = Paths.txt('$songName/${songName}Dialogue_${ClientPrefs.data.language}'); //Checks for vanilla/Senpai dialogue
		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			file = Paths.txt('$songName/${songName}Dialogue');
		}

		#if MODS_ALLOWED
		if (!FileSystem.exists(file))
		#else
		if (!OpenFlAssets.exists(file))
		#end
		{
			startCountdown();
			return;
		}

		doof = new DialogueBox(false, CoolUtil.coolTextFile(file));
		doof.cameras = [camHUD];
		doof.scrollFactor.set();
		doof.finishThing = startCountdown;
		doof.nextDialogueThing = PlayState.instance.startNextDialogue;
		doof.skipDialogueThing = PlayState.instance.skipDialogue;
	}
	
	function schoolIntro():Void
	{
		inCutscene = true;
		var black:FlxSprite = new FlxSprite(-100, -100).makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		if(songName == 'senpai') add(black);

		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			black.alpha -= 0.15;

			if (black.alpha <= 0)
			{
				if (doof != null)
					add(doof);
				else
					startCountdown();

				remove(black);
				black.destroy();
			}
			else tmr.reset(0.3);
		});
	}
}