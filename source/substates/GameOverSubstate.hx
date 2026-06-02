package substates;

import backend.WeekData;

import objects.Character;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxPoint;

import states.StoryMenuState;
import states.FreeplayState;

class GameOverSubstate extends ScriptedSubState
{
	public var boyfriend:Character;
	var camFollow:FlxObject;

	var stagePostfix:String = '';

	var targetCameraZoom:Float = 1.0;

	public static var characterName:String = 'bf';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static var instance:GameOverSubstate;
	public function new(?playStateBoyfriend:Character = null)
	{
		if (playStateBoyfriend != null)
		{
			this.boyfriend = playStateBoyfriend;
			//PlayState.instance?.remove(playStateBoyfriend);
		}

		super();
	}

	public static function resetVariables() {
		characterName = 'bf';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';

		var _song = PlayState.SONG;
		if(_song != null)
		{
			if(_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) characterName = _song.gameOverChar;
			if(_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) deathSoundName = _song.gameOverSound;
			if(_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) loopSoundName = _song.gameOverLoop;
			if(_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) endSoundName = _song.gameOverEnd;
		}
	}

	var charX:Float = 0;
	var charY:Float = 0;

	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	override function create()
	{
		preCreate();
		
		instance = this;

		Conductor.songPosition = 0;

		if (boyfriend.curCharacter != characterName) boyfriend.changeCharacter(characterName);

		boyfriend.setPosition(boyfriend.positionArray[0], boyfriend.positionArray[1]);
		boyfriend.x += (PlayState.instance?.boyfriendGroup.x ?? 0);
		boyfriend.y += (PlayState.instance?.boyfriendGroup.y ?? 0);

		boyfriend.skipDance = true;
		boyfriend.playAnim('firstDeath');
		add(boyfriend);

		add(camFollow = new FlxObject(0, 0, 1, 1));
		camFollow.setPosition(
			boyfriend.getMidpoint().x - 100 - boyfriend.cameraPosition[0] + boyfriend.cameraDeathPosition[0] * (boyfriend.isPlayer ? 1 : -1), 
			boyfriend.getMidpoint().y - 100 + boyfriend.cameraPosition[1] + boyfriend.cameraDeathPosition[1]
		);

		FlxG.sound.play(Paths.sound(deathSoundName));		

		FlxG.camera.target = null;
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		targetCameraZoom = (PlayState.instance?.defaultCamZoom ?? 1.0) * boyfriend.cameraDeathZoom;
		
		PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverStart());
		
		PlayState.instance?.setOnScripts('inGameOver', true);
		PlayState.instance?.callOnScripts('onGameOverStart', []);
		FlxG.sound.music.loadEmbedded(Paths.music(loopSoundName), true);
		
		if (characterName == 'pico-dead') {
			overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
			overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
			overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
			overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
			overlay.antialiasing = ClientPrefs.data.antialiasing;
			overlayConfirmOffsets.set(250, 200);
			overlay.visible = false;
			add(overlay);

			boyfriend.animation.onFrameChange.add(function(name:String, frameNumber:Int, frameIndex:Int) {
				switch (name) {
					case 'firstDeath':
						if (frameNumber >= 36 - 1) {
							overlay.visible = true;
							overlay.animation.play('deathLoop');
							boyfriend.animation.onFrameChange.removeAll();
						}
					default:
						boyfriend.animation.onFrameChange.removeAll();
				}
			});

			if (PlayState.instance != null && PlayState.instance.gf != null && PlayState.instance.gf.curCharacter == 'nene')
			{
				var neneKnife:FlxSprite = new FlxSprite(boyfriend.x - 450, boyfriend.y - 250);
				neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
				neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
				neneKnife.antialiasing = ClientPrefs.data.antialiasing;
				neneKnife.animation.onFinish.addOnce(function(_) {
					remove(neneKnife, true);
					neneKnife.kill();
				});
				insert(0, neneKnife);
				neneKnife.animation.play('anim', true);
			}
		}

		super.create();
	}

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		super.update(elapsed);
		
		PlayState.instance?.callOnScripts('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (!boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished()) {
			boyfriend.playAnim('deathLoop');
			if (overlay != null && overlay.animation.exists('deathLoop')) {
				overlay.visible = true;
				overlay.animation.play('deathLoop');
			}
			justPlayedLoop = true;
		}

		FlxG.camera.zoom = FlxMath.lerp(targetCameraZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125));

		if(!isEnding)
		{
			if (controls.ACCEPT) endBullshit();
			else if (controls.BACK && PlayState.instance?.callOnScripts('onGameOverConfirmPre', [false], true) != psychlua.LuaUtils.Function_Stop)
			{
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
				FlxG.camera.visible = false;
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = false;
				PlayState.chartingMode = false;
				
				PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverConfirm(false));
				
				var stopped:Bool = (callOnScripts('onGameOverConfirm', [false], true) == psychlua.LuaUtils.Function_Stop);
				stopped = (stopped || (PlayState.instance != null && PlayState.instance.callOnScripts('onGameOverConfirm', [false], true) == psychlua.LuaUtils.Function_Stop));
				
				if (!stopped) {
					Mods.loadTopMod();
					
					if (PlayState.isStoryMode) {
						MusicBeatState.switchState(new StoryMenuState());
					} else {
						MusicBeatState.switchState(new FreeplayState());
					}
		
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
			}
		else if (justPlayedLoop) coolStartDeath();
			
			if (FlxG.sound.music.playing)
				Conductor.songPosition = FlxG.sound.music.time;
		}
		
		PlayState.instance?.callOnScripts('onUpdatePost', [elapsed]);
		
		postUpdate(elapsed);
	}

	public var isEnding:Bool = false;
	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;
		
		PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverLoop());
		PlayState.instance?.callOnScripts('onGameOverLoop', []);
	}

	function endBullshit():Void
	{
		if (!isEnding && PlayState.instance?.callOnScripts('onGameOverConfirmPre', [true], true) != psychlua.LuaUtils.Function_Stop)
		{
			isEnding = true;
			
			if (boyfriend.hasAnimation('deathConfirm')) boyfriend.playAnim('deathConfirm', true);
			else if (boyfriend.hasAnimation('deathLoop')) boyfriend.playAnim('deathLoop', true);

			if (overlay != null && overlay.animation.exists('deathConfirm')) {
				overlay.visible = true;
				overlay.animation.play('deathConfirm');
				overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
			}
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			
			FlxTransitionableState.skipNextTransIn = true;
			new FlxTimer().start(boyfriend.confirmDelay, (_) -> {
				FlxG.camera.fade(FlxColor.BLACK, 2, false, () -> MusicBeatState.resetState());
			});
			
			PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverConfirm(true));
			
			callOnScripts('onGameOverConfirm', [true]);
			PlayState.instance?.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
