package objects;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

import backend.Song;
import states.stages.objects.TankmenBG;

typedef DeathData =
{
	@:optional var delay:Float;
	@:optional var confirm_delay:Float;
	
	@:optional var camera_zoom:Float;
	@:optional var camera_position:Array<Float>;
}

typedef CharacterFile = {
	var animations:Array<AnimationData>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var death:DeathData;

	var flip_x:Bool;
	var antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;

	@:optional var _editor_isPlayer:Null<Bool>;
}

class Character extends FunkinSprite
{
	/**
	 * In case a character is missing, it will use this on its place
	 */
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimationData> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var deathDelay:Float = 0;
	public var confirmDelay:Float = 0.7;
	
	public var cameraDeathZoom:Float = 1.0;
	public var cameraDeathPosition:Array<Float> = [0, 0];

	//public var position:FlxPoint = FlxPoint.get();
	//public var cameraPosition:FlxPoint = FlxPoint.get();
	//public var healthColor:FlxColor = FlxColor.RED;

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	// Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false; // well... innecesary shit
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;
	
	public var canPlayComboAnim:Bool = true;
	public var canPlayDropAnim:Bool = true;
	
	public var comboNoteCounts:Array<Int> = [];
	public var dropNoteCounts:Array<Int> = [];

	// Backwards Compatibility
	public var atlas(get, never):Character;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		this.isPlayer = isPlayer;
		changeCharacter(character);
		
		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	public function changeCharacter(?character:String)
	{
		if (character == null) return;

		animationsArray = [];
		animOffsets = [];
		curCharacter = character;
		
		loadCharacterFile();

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
	}

	public function loadCharacterFile(json:Dynamic = null, ?imagePath:String)
	{
		var characterPath:String = 'characters/$curCharacter.json';

		var path:String = Paths.getPath(characterPath);
		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			missingCharacter = true;
			
			if (missingText == null)
			{
				missingText = new FlxText(0, 0, 300, 'ERROR:\n$curCharacter.json', 16);
				missingText.alignment = CENTER;
			}
			
			missingText.revive();
		}
		else
		{
			missingCharacter = false;
			missingText?.kill();
		}

		try
		{
			if (json == null) {
				#if MODS_ALLOWED
				json = Json.parse(Paths.getTextFromFile(path));
				#else
				json = Json.parse(Assets.getText(path));
				#end
			}
		}
		catch(e:Dynamic)
		{
			trace('Error loading character file of "$curCharacter": $e');
		}

		if (json == null) return;

		imageFile = imagePath ?? json.image;
		jsonScale = json.scale;

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		if (json.death != null)
		{
			deathDelay = json.death.delay;
			confirmDelay = json.death.confirm_delay;

			cameraDeathZoom = json.death.camera_zoom;
			cameraDeathPosition = json.death.camera_position;
		}

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;

		// antialiasing
		noAntialiasing = (json.no_antialiasing != null ? json.no_antialiasing == true : json.antialiasing != true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if (animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) anim = cast FunkinAnimationUtil.newAnimationFromData(anim);

			FunkinAnimationUtil.reloadFrames(this, animationsArray, imageFile.split(','));

			for (anim in animationsArray) {
				if (anim.renderType != null && anim.renderType != '') FunkinAnimationUtil.addMultiAnimation(this, anim);
				else predictAnimationRender(anim);
			}
		}

		recalculateDanceIdle();
		dance();

		scale.set(jsonScale, jsonScale);
		updateHitbox();
		
		comboNoteCounts = findCountAnims('combo');
		dropNoteCounts = findCountAnims('drop');

		trace('Loaded file to character ' + curCharacter);
	}

	function predictAnimationRender(anim:AnimationData) {
		if (!Paths.fileExists('images/$imageFile/Animation.json'))
		{
			anim.renderType = 'sparrow';
			FunkinAnimationUtil.addAnimation(this, anim);
		}
		else
		{
			anim.animType = 'symbol';
			anim.renderType = 'animateatlas';
			FunkinAnimationUtil.addAnimateAnim(this, anim);
		}
	}

	override function update(elapsed:Float)
	{
		if (debugMode || isAnimationNull())
		{
			super.update(elapsed);
			return;
		}

		if (heyTimer > 0)
		{
			var rate:Float = PlayState.instance?.playbackRate ?? 1.0;
			heyTimer -= elapsed * rate;
			if (heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if (specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if(specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if (isAnimationFinished() && hasAnimation('$name-loop'))
		{
			playAnim('$name-loop');
			if (shouldLoopAnim(name)) specialAnim = true;
		}

		super.update(elapsed);
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(force:Bool = false)
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if (danceIdle)
			{
				danced = !danced;

				if (danced) playAnim('danceRight$idleSuffix', force);
				else playAnim('danceLeft$idleSuffix', force);
			}
			else if (hasAnimation('idle$idleSuffix')) playAnim('idle$idleSuffix', force);
		}
	}
	
	public function findCountAnims(prefix:String):Array<Int> {
		var counts:Array<Int> = [];
		
		for (anim => _ in animOffsets)
		{
			if (anim.startsWith(prefix))
			{
				var number:Null<Int> = Std.parseInt(anim.substring(prefix.length));
				if (number != null) counts.push(number);
			}
		}
		
		counts.sort((a:Int, b:Int) -> a - b);
		return counts;
	}
	
	public function playComboAnim(combo:Int):Void {
		if (!canPlayComboAnim || comboNoteCounts.length == 0) return;
		
		var animToPlay:String = 'combo$combo';
		
		if (hasAnimation(animToPlay))
		{
			playAnim(animToPlay, true);
			specialAnim = true;
		}
	}
	
	public function playComboDropAnim(lastCombo:Int):Void {
		if (!canPlayDropAnim) return;
		
		var dropAnim:Null<String> = null;
		for (count in dropNoteCounts)
		{
			if (lastCombo >= count) dropAnim = 'drop$count';
		}
		
		if (dropAnim != null && hasAnimation(dropAnim))
		{
			playAnim(dropAnim, true);
			specialAnim = true;
		}
	}

	public override function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		super.playAnim(name, force, reversed, frame);

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (name == 'singLEFT') danced = true;
			else if (name == 'singRIGHT') danced = false;

			if (name == 'singUP' || name == 'singDOWN') danced = !danced;
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if (songData != null)
			{
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);
			}

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if (settingCharacterUp) danceEveryNumBeats = (danceIdle ? 1 : 2);
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if (danceIdle) calc /= 2;
			else calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public static final IGNORED_PREFIXES:Array<String> = ['idle', 'danceLeft', 'danceRight', 'singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	public function shouldLoopAnim(name:String)
	{
		for (prefix in IGNORED_PREFIXES) if (name.startsWith(prefix)) return false;
		return name.startsWith('sing') && !name.endsWith('miss');
	}

	@:deprecated("`Character.atlas` is deprecated, just use `Character` instead")
	public function get_atlas():Character return isAnimate ? this : null;
}

@:deprecated("`AnimArray` is deprecated, use `AnimationData` instead")
typedef AnimArray = AnimationData;