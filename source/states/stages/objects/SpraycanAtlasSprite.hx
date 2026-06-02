package states.stages.objects;

enum SpraycanState
{
	WAITING;
	ARCING;		// In the air.
	SHOT;		// Hit by the player.
	IMPACTED;	// Impacted the player.
}

class SpraycanAtlasSprite extends FlxSpriteGroup
{
	public var currentState:SpraycanState = WAITING;

	public var canAtlas:FlxAnimate;
	public var explosion:FlxSprite;
	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		canAtlas = new FlxAnimate();
		canAtlas.frames = Paths.getAnimateAtlas('spraycanAtlas');
		canAtlas.anim.addBySymbolIndices('Can Start', 'Can with Labels', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 24, false);
		canAtlas.anim.addBySymbolIndices('Hit Pico', 'Can with Labels', [19, 20, 21, 22, 23, 24, 25], false);
		canAtlas.anim.addBySymbolIndices('Can Shot', 'Can with Labels', [26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42], 24, false);
		canAtlas.animation.onFinish.add(finishCanAnimation);
		canAtlas.animation.onFrameChange.add(onCanFrame);
		canAtlas.visible = canAtlas.active = false;
		canAtlas.antialiasing = ClientPrefs.data.antialiasing;
		add(canAtlas);

		explosion = new FlxSprite(750, -100);
		explosion.frames = Paths.getSparrowAtlas('spraypaintExplosionEZ');
		explosion.animation.addByPrefix('idle', 'explosion round 1 short0', 24, false);
		explosion.animation.onFinish.add((name:String) -> explosion.visible = explosion.active = false);
		explosion.visible = explosion.active = false;
		explosion.antialiasing = ClientPrefs.data.antialiasing;
		add(explosion);
	}

	public var cutscene:Bool = false;
	public function finishCanAnimation(animName:String)
	{
		switch(playingAnim)
		{
			case 'Can Start':
				playHitPico();
			case 'Can Shot':
				canAtlas.visible = canAtlas.active = false;
				currentState = WAITING;
			case 'Hit Pico':
				if(!cutscene) playHitExplosion();
				canAtlas.visible = canAtlas.active = false;
				currentState = WAITING;
		}
	}

	public function onCanFrame(name:String, frameNumber:Int, frameIndex:Int):Void
	{
		if (frameNumber == 3 && name == "Can Shot")
		{
			var explode:FunkinSprite = new FunkinSprite(750, -100);
			explode.frames = Paths.getSparrowAtlas("SpraypaintExplosion");
			explode.animation.addByPrefix("idle", "Explosion 1 movie0", 24, false);
			add(explode);

			explode.animation.play("idle");
			explode.animation.onFinish.add((_) -> explode.kill());
		}
	}

	public function playHitExplosion():Void
	{
		explosion.visible = explosion.active = true;
		explosion.animation.play('idle', true);
	}

	public function playCanStart():Void
	{
		playAnimation('Can Start');
		canAtlas.visible = canAtlas.active = true;
		currentState = ARCING;
	}

	public function playCanShot():Void
	{
		playAnimation('Can Shot');
		currentState = SHOT;
	}

	public function playHitPico():Void
	{
		playAnimation('Hit Pico');
		currentState = IMPACTED;
	}

	var playingAnim:String;
	public function playAnimation(name:String)
	{
		canAtlas.anim.play(name, true);
		playingAnim = name;
	}
}