package states.stages;

import states.stages.objects.*;
import objects.Character;

class StageWeek1 extends BaseStage
{
	var isTutorial:Bool;
	var cameraTwn:FlxTween;
	
	var dadbattleBlack:BGSprite;
	var dadbattleLight:BGSprite;
	var dadbattleFog:DadBattleFog;
	
	override function create()
	{
		isTutorial = (game.songName == 'tutorial');
	}
	override function createPost()
	{
		if (isTutorial)
		{
			game.dad.visible = false;
			game.camZoomingDisabled = true;
		}
	}

	override function eventPushed(event:objects.Note.EventNote)
	{
		switch(event.event)
		{
			case "Dadbattle Spotlight":
				dadbattleBlack = new BGSprite(null, -800, -400, 0, 0);
				dadbattleBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				dadbattleBlack.alpha = 0.25;
				dadbattleBlack.visible = false;
				add(dadbattleBlack);

				dadbattleLight = new BGSprite('spotlight', 400, -400);
				dadbattleLight.alpha = 0.375;
				dadbattleLight.blend = ADD;
				dadbattleLight.visible = false;
				add(dadbattleLight);

				dadbattleFog = new DadBattleFog();
				dadbattleFog.visible = false;
				add(dadbattleFog);
		}
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Dadbattle Spotlight":
				if (flValue1 == null) flValue1 = 0;
				var val:Int = Math.round(flValue1);

				switch(val) {
					case 1, 2, 3: // enable and target dad
						if (val == 1) // enable
						{
							dadbattleBlack.visible = true;
							dadbattleLight.visible = true;
							dadbattleFog.visible = true;
							defaultCamZoom += 0.12;
						}

						var who:Character = dad;
						if (val > 2) who = boyfriend;
						
						// 2 only targets dad
						dadbattleLight.alpha = 0;
						new FlxTimer().start(0.12, (_) -> dadbattleLight.alpha = 0.375);
						dadbattleLight.setPosition(who.getGraphicMidpoint().x - dadbattleLight.width / 2, who.y + who.height - dadbattleLight.height + 50);
						FlxTween.tween(dadbattleFog, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
						
					default:
						dadbattleBlack.visible = false;
						dadbattleLight.visible = false;
						defaultCamZoom -= 0.12;
						FlxTween.tween(dadbattleFog, {alpha: 0}, 0.7, {onComplete: (_) -> dadbattleFog.visible = false});
				}
		}
	}
	
	override function onMoveCamera(character:String) { // Tutorial camera zooming
		if (!isTutorial || cameraTwn != null) return;
		
		var targetZoom:Float = switch (character) {
			case 'boyfriend': 1;
			default: 1.3;
		}
		
		if (FlxG.camera.zoom != targetZoom)
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: targetZoom}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete: (_) -> cameraTwn = null});
	}
}