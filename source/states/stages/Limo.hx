package states.stages;

import states.stages.objects.*;

enum HenchmenKillState
{
	WAIT;
	KILLING;
	SPEEDING_OFFSCREEN;
	SPEEDING;
	STOPPING;
}

class Limo extends BaseStage
{
	var fastCar:FlxSprite;
	var fastCarCanDrive:Bool = true;

	// event
	var limoKillingState:HenchmenKillState = WAIT;
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var dancersDiff:Float = 300;

	var bgLimo:FlxSprite;

	override function create()
	{
		// PRECACHE BLOOD
		Paths.image('limo/blood');

		// PRECACHE SOUND
		Paths.sound('dancerdeath');
	}

	override function buildStage()
	{
		if (!ClientPrefs.data.lowQuality)
		{
			bgLimo = getStageObject('bgLimo');

			limoMetalPole = new BGSprite('limo/metalPole', -500, 220, 0.4, 0.4);
			insert(members.indexOf(bgLimo), limoMetalPole);

			limoCorpse = new BGSprite('limo/henchmen', -500, limoMetalPole.y - 130, 0.4, 0.4, ['hench hit 1'], true);
			insert(members.indexOf(limoMetalPole), limoCorpse);

			limoCorpseTwo = new BGSprite('limo/henchmen', -500, limoMetalPole.y, 0.4, 0.4, ['hench hit 2'], true);
			insert(members.indexOf(limoCorpse), limoCorpseTwo);

			limoLight = new BGSprite('limo/metalLight', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4);
			insert(members.indexOf(gfGroup) - 1, limoLight);

			grpLimoParticles = new FlxTypedGroup<BGSprite>();
			insert(members.indexOf(limoLight), grpLimoParticles);

			resetLimoKill();
		}

		fastCar = getStageObject('fastCar');

		resetFastCar();
	}

	var limoSpeed:Float = 0;
	override function update(elapsed:Float)
	{
		if(!ClientPrefs.data.lowQuality) {
			for (spr in grpLimoParticles.members)
			{
				if (spr == null) continue;

				if (spr.animation.curAnim != null && spr.animation.curAnim.finished)
				{
					spr.kill();
					grpLimoParticles.remove(spr, true);
					spr.destroy();
				}
			}

			switch(limoKillingState) {
				case KILLING:
					limoMetalPole.x += 5000 * elapsed;
					limoLight.x = limoMetalPole.x - 180;
					limoCorpse.x = limoLight.x - 50;
					limoCorpseTwo.x = limoLight.x + 35;

					for (i in 1...5+1) {
						var dancer:FlxSprite = getStageObject('limoDancer$i');
						if (dancer.x < FlxG.width * 1.5 && limoLight.x > (300 * i) - 170) {
							switch(i)
							{
								case 1, 4:
									if (i == 1) FlxG.sound.play(Paths.sound('dancerdeath'), 0.5);

									var diff:String = i == 3 ? '2' : '1';
									var particle:BGSprite = new BGSprite('limo/henchmen', dancer.x + 200, dancer.y, 0.4, 0.4, ['hench leg spin $diff'], false);
									grpLimoParticles.add(particle);
									var particle:BGSprite = new BGSprite('limo/henchmen', dancer.x + 160, dancer.y + 200, 0.4, 0.4, ['hench arm spin $diff'], false);
									grpLimoParticles.add(particle);
									var particle:BGSprite = new BGSprite('limo/henchmen', dancer.x, dancer.y + 50, 0.4, 0.4, ['hench head spin $diff'], false);
									grpLimoParticles.add(particle);

									var particle:BGSprite = new BGSprite('limo/blood', dancer.x - 110, dancer.y + 20, 0.4, 0.4, ['blood'], false);
									particle.flipX = true;
									particle.angle = -57.5;
									grpLimoParticles.add(particle);
								case 2:
									limoCorpse.visible = true;
								case 3:
									limoCorpseTwo.visible = true;
							}
							// Note: Nobody cares about the fifth dancer because he is mostly hidden offscreen :(
							dancer.x += FlxG.width * 2;
						}
					}

					if (limoMetalPole.x > FlxG.width * 2)
					{
						resetLimoKill();
						limoSpeed = 800;
						limoKillingState = SPEEDING_OFFSCREEN;
					}

				case SPEEDING_OFFSCREEN:
					limoSpeed -= 4000 * elapsed;
					bgLimo.x -= limoSpeed * elapsed;
					if (bgLimo.x > FlxG.width * 1.5)
					{
						limoSpeed = 3000;
						limoKillingState = SPEEDING;
					}

				case SPEEDING:
					limoSpeed -= 2000 * elapsed;
					if (limoSpeed < 1000) limoSpeed = 1000;

					bgLimo.x -= limoSpeed * elapsed;
					if (bgLimo.x < -275)
					{
						limoKillingState = STOPPING;
						limoSpeed = 800;
					}
					dancersParenting();

				case STOPPING:
					bgLimo.x = FlxMath.lerp(-200, bgLimo.x, Math.exp(-elapsed * 9));
					if (Math.round(bgLimo.x) == -200)
					{
						bgLimo.x = -200;
						limoKillingState = WAIT;
					}
					dancersParenting();

				default: //nothing
			}
		}
	}

	var danced:Bool = false;
	override function beatHit()
	{
		if (!ClientPrefs.data.lowQuality)
		{
			for (i in 1...5+1)
			{
				var dancer:FunkinSprite = getStageObject('limoDancer$i');

				if (!danced) dancer.playAnim('danceLeft');
				else dancer.playAnim('danceRight');
			}

			danced = !danced;
		}

		if (FlxG.random.bool(10) && fastCarCanDrive)
			fastCarDrive();
	}
	
	// Substates for pausing/resuming tweens and timers
	override function closeSubState()
	{
		if(paused)
		{
			if(carTimer != null) carTimer.active = true;
		}
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		if(paused)
		{
			if(carTimer != null) carTimer.active = false;
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Kill Henchmen":
				killHenchmen();
		}
	}

	function dancersParenting()
	{
		for (i in 1...5+1)
		{
			var dancer:FlxSprite = getStageObject('limoDancer$i');
			dancer.x = (300 * i) + bgLimo.x;
		}
	}
	
	function resetLimoKill():Void
	{
		limoMetalPole.x = -500;
		limoMetalPole.visible = false;
		limoLight.x = -500;
		limoLight.visible = false;
		limoCorpse.x = -500;
		limoCorpse.visible = false;
		limoCorpseTwo.x = -500;
		limoCorpseTwo.visible = false;
	}

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	var carTimer:FlxTimer;
	function fastCarDrive()
	{
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = FlxG.random.int(30600, 39600);
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	function killHenchmen():Void
	{
		if(!ClientPrefs.data.lowQuality) {
			if(limoKillingState == WAIT) {
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = KILLING;

				#if ACHIEVEMENTS_ALLOWED
				var kills = Achievements.addScore("roadkill_enthusiast");
				FlxG.log.add('Henchmen kills: $kills');
				#end
			}
		}
	}
}