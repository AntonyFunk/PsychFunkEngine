package states.stages.objects;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
#end

class ABotSpeaker extends FlxTypedSpriteGroup<FlxSprite>
{
	static final VIZ_MAX = 7; // ranges from viz1 to viz7
	static final VIZ_POS_X:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
	static final VIZ_POS_Y:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];

	public var bg:FlxSprite;
	public var vizSprites:Array<FlxSprite> = [];
	public var eyeBg:FlxSprite;
	public var eyes:FlxAnimate;
	public var speaker:FlxAnimate;

	#if funkin.vis var analyzer:SpectralAnalyzer; #end
	var volumes:Array<Float> = [];

	public var snd(default, set):FlxSound;
	function set_snd(changed:FlxSound)
	{
		snd = changed;
		#if funkin.vis initAnalyzer(); #end
		return snd;
	}

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		var antialias = ClientPrefs.data.antialiasing;

		bg = new FlxSprite(90, 20).loadGraphic(Paths.image('abot/stereoBG'));
		bg.antialiasing = antialias;
		add(bg);

		var vizX:Float = 0;
		var vizY:Float = 0;
		var vizFrames = Paths.getSparrowAtlas('abot/aBotViz');
		for (i in 1...VIZ_MAX + 1)
		{
			volumes.push(0.0);
			vizX += VIZ_POS_X[i-1];
			vizY += VIZ_POS_Y[i-1];
			var viz:FlxSprite = new FlxSprite(vizX + 140, vizY + 74);
			viz.frames = vizFrames;
			viz.animation.addByPrefix('VIZ', 'viz${i}0', 0);
			viz.animation.play('VIZ', false, false, 1);
			viz.antialiasing = antialias;
			vizSprites.push(viz);
			add(viz);
		}

		eyeBg = new FlxSprite(-30, 215).makeGraphic(1, 1, FlxColor.WHITE);
		eyeBg.scale.set(160, 60);
		eyeBg.updateHitbox();
		add(eyeBg);

		eyes = new FlxAnimate(-10, 230);
		Paths.loadAnimateAtlas(eyes, 'abot/systemEyes');
		eyes.anim.addBySymbolIndices('lookleft', 'a bot eyes lookin', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], 24, false);
		eyes.anim.addBySymbolIndices('lookright', 'a bot eyes lookin', [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35], 24, false);
		eyes.anim.play('lookright', true);
		eyes.animation.curAnim.curFrame = eyes.animation.numFrames;
		add(eyes);

		speaker = new FlxAnimate(-65, -10);
		Paths.loadAnimateAtlas(speaker, 'abot/abotSystem');
		speaker.anim.addBySymbol('anim', 'Abot System', 24, false);
		speaker.anim.play('anim', true);
		speaker.animation.curAnim.curFrame = speaker.animation.numFrames;
		speaker.antialiasing = antialias;
		add(speaker);
	}

	#if funkin.vis
	override function draw()
	{
		super.draw();
		drawFFT();
	}

	/**
	 * TJW funkin.vis based visualizer! updateFFT() is the old nasty shit that dont worky!
	 */
	var levels:Array<Bar>;
	function drawFFT():Void
	{
		levels = analyzer != null ? analyzer.getLevels(levels) : getDefaultLevels();

		for (i in 0...Std.int(Math.min(vizSprites.length, levels.length)))
		{
			var animFrame:Int = (FlxG.sound.volume == 0 || FlxG.sound.muted) ? 0 : Math.round(levels[i].value * 6);
  
			// don't display if we're at 0 volume from the level
			vizSprites[i].visible = animFrame > 0;
  
			// decrement our animFrame, so we can get a value from 0-5 for animation frames
			animFrame -= 1;
  
			animFrame = Math.floor(Math.min(5, animFrame));
			animFrame = Math.floor(Math.max(0, animFrame));
  
			animFrame = Std.int(Math.abs(animFrame - 5)); // shitty dumbass flip, cuz dave got da shit backwards lol!
  
			vizSprites[i].animation.curAnim.curFrame = animFrame;
		}
	}

	public function initAnalyzer():Void
	{
		if (snd == null) return;
	  
		@:privateAccess
		analyzer = new SpectralAnalyzer(snd._channel.__audioSource, VIZ_MAX, 0.1, 40);
		// A-Bot tuning...
		analyzer.minDb = -65;
		analyzer.maxDb = -25;
		analyzer.maxFreq = 22000;
		// we use a very low minFreq since some songs use low low subbass like a boss
		analyzer.minFreq = 10;

		// On native it uses FFT stuff that isn't as optimized as the direct browser stuff we use on HTML5
		// So we want to manually change it!
		#if sys analyzer.fftN = 256; #end
	}

	/**
	 * Explicitly define the default levels to draw when the analyzer is not available.
	 * @return Array<Bar>
	 */
	static function getDefaultLevels():Array<Bar>
	{
		var result:Array<Bar> = [];
		for (i in 0...VIZ_MAX) result.push({value: 0, peak: 0.0});
		
		return result;
	}
	#end

	public function beatHit()
	{
		speaker.anim.play('anim', true);
	}

	var lookingAtRight:Bool = true;
	public function lookLeft()
	{
		if(lookingAtRight) eyes.anim.play('lookleft', true);
		lookingAtRight = false;
	}
	public function lookRight()
	{
		if(!lookingAtRight) eyes.anim.play('lookright', true);
		lookingAtRight = true;
	}
}