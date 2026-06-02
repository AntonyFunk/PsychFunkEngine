package states.stages;

import shaders.BuildingEffectShader;

import states.stages.objects.*;
import objects.Character;

class Philly extends BaseStage
{
	var phillyLightsColors:Array<FlxColor> = [
		0xFF31A2FD,
		0xFF31FD8C,
		0xFFFB33F5,
		0xFFFD4531,
		0xFFFBA633
	];
	var curLight:Int = -1;

	// For Philly Glow events
	var blammedLightsBlack:FlxSprite;
	var phillyGlowGradient:PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlowParticle>;
	var phillyWindowEvent:FlxSprite;
	var curLightEvent:Int = -1;

	var lightShader:BuildingEffectShader;

	var trainSound:FlxSound;
	var trainEnabled:Bool = true;

	var lights:FlxSprite;
	var train:FlxSprite;
	var street:FlxSprite;

	override function createPost()
	{
		gf.animation.onFrameChange.add((name, frame, index) -> {
			if (name.startsWith('hair')) gf.skipDance = true;
		});

		gf.animation.onFinish.add((name) -> {
			if (name == 'hairFall') gf.skipDance = false;
		});
	}

	override function buildStage()
	{
		lightShader = new BuildingEffectShader(1.0);

		lights = getStageObject('lights');
		lights.shader = lightShader;

		train = getStageObject('train');
		street = getStageObject('street');

		trainSound = new FlxSound().loadEmbedded(Paths.sound('train_passes'));
		FlxG.sound.list.add(trainSound);
	}

	override function eventPushed(event:objects.Note.EventNote)
	{
		switch(event.event)
		{
			case "Philly Glow":
				blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blammedLightsBlack.visible = false;
				insert(members.indexOf(lights) + 1, blammedLightsBlack);

				phillyWindowEvent = new FlxSprite(lights.x, lights.y).loadGraphic(lights.graphic);
				phillyWindowEvent.scrollFactor.set(lights.scrollFactor.x, lights.scrollFactor.y);
				phillyWindowEvent.scale.set(lights.scale.x, lights.scale.y);
				phillyWindowEvent.updateHitbox();
				phillyWindowEvent.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);

				phillyGlowGradient = new PhillyGlowGradient(-400, 225);
				phillyGlowGradient.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);
				if (!ClientPrefs.data.flashing) phillyGlowGradient.intendedAlpha = 0.7;

				Paths.image('philly/particle'); // precache philly glow particle image
				phillyGlowParticles = new FlxTypedGroup<PhillyGlowParticle>();
				phillyGlowParticles.visible = false;
				insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
		}
	}

	var trainMoving:Bool = false;
	var trainFrameTiming:Float = 0;
	var trainCars:Int = 8;
	var trainFinishing:Bool = false;
	var trainCooldown:Int = 0;

	override function update(elapsed:Float)
	{
		var shaderInput:Float = (Conductor.crochet / 1000) * elapsed * 1.5;
		lightShader.update(shaderInput);

		if (trainEnabled && trainMoving)
		{
			trainFrameTiming += elapsed;
	
			if (trainFrameTiming >= 1 / 24)
			{
				updateTrainPos();
				trainFrameTiming = 0;
			}
		}

		if (phillyGlowParticles != null)
		{
			phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
			{
				if(particle.alpha <= 0)
					particle.kill();
			});
		}
	}

	override function beatHit()
	{
		if (trainEnabled)
		{
			// Update train cooldown
			if (!trainMoving) trainCooldown += 1;
	
			// Start train
			if (curBeat % 8 == 4 && FlxG.random.bool(30) && !trainMoving && trainCooldown > 8)
			{
				trainCooldown = FlxG.random.int(-4, 0);
				trainStart();
			}
		}

		if (curBeat % 4 == 0)
		{
			curLight = FlxG.random.int(0, phillyLightsColors.length - 1, [curLight]);

			lights.color = phillyLightsColors[curLight];
			lightShader.reset();
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Philly Glow":
				if(flValue1 == null || flValue1 <= 0) flValue1 = 0;
				var lightId:Int = Math.round(flValue1);

				var chars:Array<Character> = [boyfriend, gf, dad];
				switch(lightId)
				{
					case 0:
						if(phillyGlowGradient.visible)
						{
							doFlash();
							if(ClientPrefs.data.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = false;
							phillyWindowEvent.visible = false;
							phillyGlowGradient.visible = false;
							phillyGlowParticles.visible = false;
							curLightEvent = -1;

							if (street != null) street.color = FlxColor.WHITE;
							for (who in chars) if (who != null) who.color = FlxColor.WHITE;
						}

					case 1: //turn on
						curLightEvent = FlxG.random.int(0, phillyLightsColors.length-1, [curLightEvent]);
						var color:FlxColor = phillyLightsColors[curLightEvent];

						if(!phillyGlowGradient.visible)
						{
							doFlash();
							if(ClientPrefs.data.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = true;
							blammedLightsBlack.alpha = 1;
							phillyWindowEvent.visible = true;
							phillyGlowGradient.visible = true;
							phillyGlowParticles.visible = true;
						}
						else if(ClientPrefs.data.flashing)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.25;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						var charColor:FlxColor = color;
						if (!ClientPrefs.data.flashing) charColor.saturation *= 0.5;
						else charColor.saturation *= 0.75;

						for (who in chars) if (who != null) who.color = charColor;
						phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
						{
							particle.color = color;
						});
						phillyGlowGradient.color = color;
						phillyWindowEvent.color = color;

						color.brightness *= 0.5;
						if (street != null) street.color = color;

					case 2: // spawn particles
						if(!ClientPrefs.data.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = phillyLightsColors[curLightEvent];
							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlowParticle = phillyGlowParticles.recycle(PhillyGlowParticle);
									particle.x = -400 + width * i + FlxG.random.float(-width / 5, width / 5);
									particle.y = phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40);
									particle.color = color;
									particle.start();
									phillyGlowParticles.add(particle);
								}
							}
						}
						phillyGlowGradient.bop();
				}
		}
	}

	function doFlash()
	{
		var color:FlxColor = FlxColor.WHITE;
		if(!ClientPrefs.data.flashing) color.alphaFloat = 0.5;

		FlxG.camera.flash(color, 0.15, null, true);
	}

	var startedMoving:Bool = false;

	function trainStart():Void
	{
		trainMoving = true;
		trainSound.play(true);
	}

	function updateTrainPos():Void
	{
		if (trainSound.time >= 4700)
		{
			startedMoving = true;
			if (gf != null) gf.playAnim('hairBlow');
		}
  
		if (startedMoving)
		{
			train.x -= 400;
  
			if (train.x < -2000 && !trainFinishing)
			{
				train.x = -1150;
				trainCars -= 1;
  
				if (trainCars <= 0) trainFinishing = true;
			}
  
			if (train.x < -4000 && trainFinishing) trainReset();
		}
	}

	function trainReset():Void
	{
		if (gf != null && startedMoving) gf.playAnim('hairFall');

		train.x = 2000;
		trainCars = 8;

		trainMoving = false;
		trainFinishing = false;
		startedMoving = false;
	}
}