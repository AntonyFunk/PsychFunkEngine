package objects;

import backend.animation.PsychAnimationController;
import shaders.RGBPalette;
import flixel.system.FlxAssets.FlxShader;

typedef RGB = {
	r:Null<Int>,
	g:Null<Int>,
	b:Null<Int>
}

typedef NoteSplashAnim = {
	name:String,
	noteData:Int,
	prefix:String,
	indices:Array<Int>,
	offsets:Array<Float>,
	fps:Array<Int>
}

typedef NoteSplashConfig = {
	animations:Map<String, NoteSplashAnim>,
	scale:Float,
	blendMode:String,
	allowRGB:Bool,
	allowPixel:Bool,
	rgb:Array<Null<RGB>>
}

class NoteSplash extends FlxSprite
{
	public var rgbShader:PixelSplashShaderRef;
	public var texture:String;
	public var config(default, set):NoteSplashConfig;
	public var babyArrow:StrumNote;
	public var noteData:Int = 0;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var inEditor:Bool = false;

	var spawned:Bool = false;
	var noteDataMap:Map<Int, String> = new Map();
	/** Claves de animación por columna (noteData % 4); permite varias variantes con el mismo "lado" sin pisarse en el Map. */
	var animsByColumn:Array<Array<String>> = null;

	public static var defaultNoteSplash(default, never):String = "noteSplashes/noteSplashes";
	public static var configs:Map<String, NoteSplashConfig> = new Map();

	/** Columna 0–3 (una por nota del personaje). Siempre usar esto con datos externos o JSON antiguo. */
	public static inline function noteDataColumn(noteData:Int):Int
	{
		var m:Int = Note.colArray.length;
		return ((noteData % m) + m) % m;
	}

	public function new(?x:Float = 0, ?y:Float = 0, ?splash:String)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		rgbShader = new PixelSplashShaderRef();
		shader = rgbShader.shader;

		loadSplash(splash);
	}

	var isPixel:Bool = false;
	public var maxAnims(default, set):Int = 0;
	public function loadSplash(?splash:String)
	{
		config = null;
		maxAnims = 0;

		if (splash == null || splash.length < 1) {
			splash = PlayState.SONG != null ? PlayState.SONG.splashSkin : null;
			if (splash == null || splash.length < 1) splash = defaultNoteSplash;
		}

		var skinPostfix:String = '';
		var checkSkin:String = '';
		var validSkin:String = null;

		for (path in [PlayState.uiPrefix + splash, splash]) {
			skinPostfix = getSplashSkinPostfix();
			checkSkin = path + skinPostfix;
			
			if (!Paths.fileExists('images/$checkSkin.png')) {
				skinPostfix = '';
				checkSkin = path;
			}
			
			if (Paths.fileExists('images/$checkSkin.png')) {
				validSkin = path;
				break;
			}
		}

		if (validSkin == null) return;

		frames = Paths.getSparrowAtlas('$validSkin$skinPostfix');

		if (validSkin.contains('pixelUI/')) isPixel = true;

		var path:String = 'images/$validSkin$skinPostfix';
		if (configs.exists(path))
		{
			this.config = configs.get(path);
			return;
		}
		else if (Paths.fileExists('$path.json'))
		{
			var config:Dynamic = haxe.Json.parse(Paths.getTextFromFile('$path.json'));
			if (config != null)
			{
				var tempConfig:NoteSplashConfig = {
					animations: new Map(),
					scale: config.scale,
					blendMode: config.blendMode,
					allowRGB: config.allowRGB,
					allowPixel: config.allowPixel,
					rgb: config.rgb
				}

				for (i in Reflect.fields(config.animations))
				{
					var anim:NoteSplashAnim = Reflect.field(config.animations, i);
					tempConfig.animations.set(i, anim);
				}

				this.config = tempConfig;
				configs.set(path, this.config);
				return;
			}
		}

		// Splashes with no json
		var tempConfig:NoteSplashConfig = createConfig();
		var anim:String = 'note splash';
		var fps:Array<Null<Int>> = [22, 26];
		var offsets:Array<Array<Float>> = [[0, 0]];
		if (Paths.fileExists('$path.txt')) // Backwards compatibility with 0.7 splash txts
		{
			var configFile:Array<String> = CoolUtil.listFromString(Paths.getTextFromFile('$path.txt'));
			if (configFile.length > 0)
			{
				anim = configFile[0];
				if (configFile.length > 1)
				{
					var framerates:Array<String> = configFile[1].split(' ');
					fps = [Std.parseInt(framerates[0]), Std.parseInt(framerates[1])];
					if (fps[0] == null) fps[0] = 22;
					if (fps[1] == null) fps[1] = 26;

					if (configFile.length > 2)
					{
						offsets = [];
						for (i in 2...configFile.length)
						{
							if (configFile[i].trim() != '')
							{
								var animOffs:Array<String> = configFile[i].split(' ');
								var x:Float = Std.parseFloat(animOffs[0]);
								var y:Float = Std.parseFloat(animOffs[1]);
								if (Math.isNaN(x)) x = 0;
								if (Math.isNaN(y)) y = 0;
								offsets.push([x, y]);
							}
						}
					}
				}
			}
		}

		var failedToFind:Bool = false;
		while (true)
		{
			for (v in Note.colArray)
			{
				if (!checkForAnim('$anim $v ${maxAnims+1}'))
				{
					failedToFind = true;
					break;
				}
			}
			if (failedToFind) break;
			maxAnims++;
		}

		for (animNum in 0...maxAnims)
		{
			for (i => col in Note.colArray)
			{
				var data:Int = i % Note.colArray.length + (animNum * Note.colArray.length);
				var name:String = animNum > 0 ? '$col' + (animNum + 1) : col;
				var offset:Array<Float> = offsets[FlxMath.wrap(data, 0, Std.int(offsets.length-1))];
				addAnimationToConfig(tempConfig, 1, name, '$anim $col ${animNum + 1}', fps, offset, [], data);
			}
		}

		this.config = tempConfig;
		configs.set(path, this.config);
	}

	public function spawnSplashNote(?x:Float = 0, ?y:Float = 0, ?data:Int = 0, ?note:Note, ?randomize:Bool = true, ?forceAnim:String = null)
	{
		if (note != null && note.noteSplashData.disabled)
			return;

		aliveTime = 0;

		if (!inEditor)
		{
			var loadedTexture:String = defaultNoteSplash + getSplashSkinPostfix();
			if (note != null && note.noteSplashData.texture != null) loadedTexture = note.noteSplashData.texture;
			else if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) loadedTexture = PlayState.SONG.splashSkin;

			if (texture != loadedTexture) loadSplash(loadedTexture);
		}

		setPosition(x, y);

		if (babyArrow != null)
			setPosition(babyArrow.x - Note.swagWidth * 0.95, babyArrow.y - Note.swagWidth); // To prevent it from being misplaced for one game tick

		var incomingData:Int = data;
		if (note != null) incomingData = note.noteData;
		
		incomingData = noteDataColumn(incomingData);

		var col:Int = incomingData;
		var chosenAnim:String = null;

		if (forceAnim != null && forceAnim.length > 0 && config != null && config.animations.exists(forceAnim) && animation.exists(forceAnim))
		{
			chosenAnim = forceAnim;
			this.noteData = noteDataColumn(config.animations.get(forceAnim).noteData);
		}
		else if (randomize && animsByColumn != null && col < animsByColumn.length && animsByColumn[col] != null && animsByColumn[col].length > 1)
		{
			chosenAnim = animsByColumn[col][FlxG.random.int(0, animsByColumn[col].length - 1)];
			this.noteData = noteDataColumn(config.animations.get(chosenAnim).noteData);
		}
		else
		{
			this.noteData = incomingData;
			chosenAnim = resolveAnimFromCurrentNoteData();
		}

		if (chosenAnim == null || !animation.exists(chosenAnim))
		{
			trace("ERROR: No animation found for noteData " + this.noteData);
			kill();
			spawned = false;
			return;
		}

		var tempShader:RGBPalette = null;
		if (config.allowRGB)
		{
			Note.initializeGlobalRGBShader(this.noteData % Note.colArray.length);
			if (inEditor || (note == null || note.noteSplashData.useRGBShader) && (PlayState.SONG == null || !PlayState.SONG.disableNoteRGB))
			{
				tempShader = new RGBPalette();
				// If Note RGB is enabled:
				if ((note == null || !note.noteSplashData.useGlobalShader) || inEditor)
				{
					var colors = config.rgb;
					if (colors != null)
					{
						for (i in 0...colors.length)
						{
							if (i > 2) break;

							var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[this.noteData % Note.colArray.length];
							if (PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[this.noteData % Note.colArray.length];

							var rgb = colors[i];
							if (rgb == null)
							{
								if (i == 0) tempShader.r = arr[0];
								else if (i == 1) tempShader.g = arr[1];
								else if (i == 2) tempShader.b = arr[2];
								continue;
							}

							var r:Null<Int> = rgb.r; 
							var g:Null<Int> = rgb.g;
							var b:Null<Int> = rgb.b;

							if (r == null || Math.isNaN(r) || r < 0) r = arr[0];
							if (g == null || Math.isNaN(g) || g < 0) g = arr[1];
							if (b == null || Math.isNaN(b) || b < 0) b = arr[2];

							var color:FlxColor = FlxColor.fromRGB(r, g, b);
							if (i == 0) tempShader.r = color;
							else if (i == 1) tempShader.g = color;
							else if (i == 2) tempShader.b = color;
						}
					}
					else tempShader.copyValues(Note.globalRgbShaders[this.noteData % Note.colArray.length]);

					if (note != null)
					{
						if (note.noteSplashData.r != -1) tempShader.r = note.noteSplashData.r;
						if (note.noteSplashData.g != -1) tempShader.g = note.noteSplashData.g;
						if (note.noteSplashData.b != -1) tempShader.b = note.noteSplashData.b;
					}
				}
				else tempShader.copyValues(Note.globalRgbShaders[this.noteData % Note.colArray.length]);
			}
		}
		rgbShader.copyValues(tempShader);
		if (!config.allowPixel) rgbShader.pixelAmount = 1;
		else if (PlayState.isPixelStage) rgbShader.pixelAmount = 6;

		frameOffset.set(10, 10);
		var conf:NoteSplashAnim = config.animations.get(chosenAnim);
		var offsets:Array<Float> = [0, 0];
		if (conf != null) offsets = conf.offsets;
		if (offsets != null)
		{
			frameOffset.x += offsets[0];
			frameOffset.y += offsets[1];
		}

		animation.onFinish.removeAll();
		animation.onFinish.add(function(name:String) {
			kill();
			spawned = false;
		});

		alpha = ClientPrefs.data.splashAlpha;
		if (note != null) alpha = note.noteSplashData.a;

		if (config.blendMode != '') blend = psychlua.LuaUtils.blendModeFromString(config.blendMode);

		if (!isPixel)
		{
			antialiasing = ClientPrefs.data.antialiasing;
			if (note != null) antialiasing = note.noteSplashData.antialiasing;
			if (PlayState.isPixelStage && config.allowPixel) antialiasing = false;
		}
		else antialiasing = false;

		var minFps:Int = 22;
		var maxFps:Int = 26;
		if (conf != null)
		{
			minFps = conf.fps[0];
			if (minFps < 0) minFps = 0;

			maxFps = conf.fps[1];
			if (maxFps < 0) maxFps = 0;
		}

		animation.play(chosenAnim, true);

		if (animation.curAnim != null) animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);

		spawned = true;
	}

	/**
	 * Resolve the animation key for `this.noteData` (without playing).
	 */
	public function resolveAnimFromCurrentNoteData():Null<String>
	{
		var col:Int = noteDataColumn(noteData);
		var anim:String = noteDataMap.get(col);
		if (anim == null && config != null && config.animations != null)
		{
			for (animName => animData in config.animations)
			{
				if (animData != null && noteDataColumn(animData.noteData) == col)
				{
					anim = animName;
					break;
				}
			}
		}

		if (anim != null && animation.exists(anim)) return anim;

		return null;
	}

	public function playDefaultAnim():Null<String>
	{
		var anim = resolveAnimFromCurrentNoteData();
		if (anim != null) animation.play(anim, true);

		return anim;
	}

	function checkForAnim(anim:String)
	{
		return frames != null && frames.exists(anim);
	}

	var aliveTime:Float = 0;
	static var buggedKillTime:Float = 0.5; //automatically kills note splashes if they break to prevent it from flooding your HUD
	override function update(elapsed:Float)
	{
		if (spawned)
		{
			aliveTime += elapsed;
			if (animation.curAnim == null && aliveTime >= buggedKillTime)
			{
				kill();
				spawned = false;
			}
		}

		if (babyArrow != null)
		{
			if (copyX)
				x = babyArrow.x - Note.swagWidth * 0.95;

			if (copyY)
				y = babyArrow.y - Note.swagWidth;
		}
		super.update(elapsed);
	}

	public static function getSplashSkinPostfix()
	{
		var skin:String = '';
		if (ClientPrefs.data.splashSkin != ClientPrefs.defaultData.splashSkin)
			skin = '-' + ClientPrefs.data.splashSkin.trim().toLowerCase().replace(' ', '-');
		return skin;
	}

	public static function createConfig():NoteSplashConfig
	{
		return {
			animations: new Map(),
			scale: 1,
			blendMode: '',
			allowRGB: true,
			allowPixel: true,
			rgb: null
		}
	}

	public static function addAnimationToConfig(config:NoteSplashConfig, scale:Float, name:String, prefix:String, fps:Array<Int>, offsets:Array<Float>, indices:Array<Int>, noteData:Int):NoteSplashConfig
	{
		if (config == null) config = createConfig();

		noteData = noteDataColumn(noteData);
		config.animations.set(name, {name: name, noteData: noteData, prefix: prefix, indices: indices, offsets: offsets, fps: fps});
		config.scale = scale;
		return config;
	}

	function set_config(value:NoteSplashConfig):NoteSplashConfig 
	{
		if (value == null) value = createConfig();

		@:privateAccess
		animation.clearAnimations();
		noteDataMap.clear();

		animsByColumn = [for (_ in 0...Note.colArray.length) []];
		maxAnims = 1;

		// La clave del Map es la que usa el JSON y el editor; debe coincidir con FlxAnimationController y config.animations.get().
		for (mapKey => i in value.animations)
		{
			if (i == null || i.prefix == null || i.prefix.length == 0 || mapKey == null || mapKey.length == 0)
				continue;

			var maxFps:Int = 24;
			if (i.fps != null && i.fps.length > 1)
				maxFps = Std.int(i.fps[1]);
			else if (i.fps != null && i.fps.length > 0)
				maxFps = Std.int(i.fps[0]);

			if (i.indices != null && i.indices.length > 0)
				animation.addByIndices(mapKey, i.prefix, i.indices, "", maxFps, false);
			else
				animation.addByPrefix(mapKey, i.prefix, maxFps, false);

			var col:Int = noteDataColumn(i.noteData);
			noteDataMap.set(col, mapKey);
			animsByColumn[col].push(mapKey);
		}

		for (c in 0...animsByColumn.length)
		{
			var list = animsByColumn[c];
			if (list.length > 1)
				list.sort(function(a:String, b:String):Int {
					var da = value.animations.get(a);
					var db = value.animations.get(b);
					if (da == null && db == null) return 0;
					if (da == null) return 1;
					if (db == null) return -1;
					if (da.noteData != db.noteData)
						return da.noteData < db.noteData ? -1 : 1;
					return a < b ? -1 : (a > b ? 1 : 0);
				});
		}

		if (maxAnims < 1)
			maxAnims = 1;

		scale.set(value.scale, value.scale);
		return config = value;
	}

	function set_maxAnims(value:Int)
	{
		if (value > 0)
			noteData = Std.int(FlxMath.wrap(noteData, 0, (value * Note.colArray.length) - 1));
		else
			noteData = 0;

		return maxAnims = value;
	}
}

class PixelSplashShaderRef 
{
	public var shader:PixelSplashShader = new PixelSplashShader();
	public var enabled(default, set):Bool = true;
	public var pixelAmount(default, set):Float = 1;

	public function copyValues(tempShader:RGBPalette)
	{
		if (tempShader != null)
		{
			for (i in 0...3)
			{
				shader.r.value[i] = tempShader.shader.r.value[i];
				shader.g.value[i] = tempShader.shader.g.value[i];
				shader.b.value[i] = tempShader.shader.b.value[i];
			}
			shader.mult.value[0] = tempShader.shader.mult.value[0];
		}
		else enabled = false;
	}

	public function set_enabled(value:Bool)
	{
		enabled = value;
		shader.mult.value = [value ? 1 : 0];
		return value;
	}

	public function set_pixelAmount(value:Float)
	{
		pixelAmount = value;
		shader.uBlocksize.value = [value, value];
		return value;
	}

	public function reset()
	{
		shader.r.value = [0, 0, 0];
		shader.g.value = [0, 0, 0];
		shader.b.value = [0, 0, 0];
	}

	public function new()
	{
		reset();
		enabled = true;

		if (!PlayState.isPixelStage) pixelAmount = 1;
		else pixelAmount = PlayState.daPixelZoom;
		//trace('Created shader ' + Conductor.songPosition);
	}
}

class PixelSplashShader extends FlxShader
{
	@:glFragmentHeader('
		#pragma header
		
		uniform vec3 r;
		uniform vec3 g;
		uniform vec3 b;
		uniform float mult;
		uniform vec2 uBlocksize;
		
		vec4 applyColorTransform(vec4 color) {
		    if (color.a == 0.) {
		        return vec4(0.);
		    }
		    if (!hasTransform) {
		        return color;
		    }
		    if (!hasColorTransform) {
		        return color * openfl_Alphav;
		    }

		    color = vec4(color.rgb / color.a, color.a);
		    color = clamp(openfl_ColorOffsetv + color * openfl_ColorMultiplierv, 0., 1.);

		    if (color.a > 0.) {
		        return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
		    }
		    return vec4(0.);
		}

		vec4 flixel_texture2DCustom(sampler2D bitmap, vec2 uv) {
			vec2 blocks = openfl_TextureSize / uBlocksize;
			vec4 color = texture2D(bitmap, floor(uv * blocks) / blocks);
			if (color.a == 0.0) {
				return color;
			}
			
			vec3 rgbMix = mix(color.rgb, vec3(color.r * r + color.g * g + color.b * b), mult);
			color.rgb = min(rgbMix, color.a);
			return applyColorTransform(color);
		}
	')

	@:glFragmentSource('
		#pragma header

		void main() {
			gl_FragColor = flixel_texture2DCustom(bitmap, openfl_TextureCoordv);
		}')

	public function new()
	{
		super();
	}
}