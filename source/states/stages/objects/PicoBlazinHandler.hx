package states.stages.objects;

import objects.Note;
import objects.Character;

// Pico Note functions
class PicoBlazinHandler
{
	static var originalBFPos = -1;
	public static function init()
	{
		originalBFPos = FlxG.state.members.indexOf(boyfriendGroup);
	}

	static var cantUppercut = false;
	public static function noteHit(note:Note)
	{
		if (wasNoteHitPoorly(note.rating) && isPlayerLowHealth() && isDarnellPreppingUppercut())
		{
			playPunchHighAnim();
			return;
		}

		if (cantUppercut)
		{
			playBlockAnim();
			cantUppercut = false;
			return;
		}

		switch(note.noteType)
		{
			case "weekend-1-punchlow":
				playPunchLowAnim();
			case "weekend-1-punchlowblocked":
				playPunchLowAnim();
			case "weekend-1-punchlowdodged":
				playPunchLowAnim();
			case "weekend-1-punchlowspin":
				playPunchLowAnim();

			case "weekend-1-punchhigh":
				playPunchHighAnim();
			case "weekend-1-punchhighblocked":
				playPunchHighAnim();
			case "weekend-1-punchhighdodged":
				playPunchHighAnim();
			case "weekend-1-punchhighspin":
				playPunchHighAnim();

			case "weekend-1-blockhigh":
				playBlockAnim();
			case "weekend-1-blocklow":
				playBlockAnim();
			case "weekend-1-blockspin":
				playBlockAnim();

			case "weekend-1-dodgehigh":
				playDodgeAnim();
			case "weekend-1-dodgelow":
				playDodgeAnim();
			case "weekend-1-dodgespin":
				playDodgeAnim();

			// Pico ALWAYS gets punched.
			case "weekend-1-hithigh":
				playHitHighAnim();
			case "weekend-1-hitlow":
				playHitLowAnim();
			case "weekend-1-hitspin":
				playHitSpinAnim();

			case "weekend-1-picouppercutprep":
				playUppercutPrepAnim();
			case "weekend-1-picouppercut":
				playUppercutAnim(true);

			case "weekend-1-darnelluppercutprep":
				playIdleAnim();
			case "weekend-1-darnelluppercut":
				playUppercutHitAnim();

			case "weekend-1-idle":
				playIdleAnim();
			case "weekend-1-fakeout":
				playFakeoutAnim();
			case "weekend-1-taunt":
				playTauntConditionalAnim();
			case "weekend-1-tauntforce":
				playTauntAnim();
			case "weekend-1-reversefakeout":
				playIdleAnim(); // TODO: Which anim?
		}
	}

	public static function noteMiss(note:Note)
	{
		//trace('missed note!');
		if (isDarnellInUppercut())
		{
			playUppercutHitAnim();
			return;
		}

		if (willMissBeLethal())
		{
			playHitLowAnim();
			return;
		}

		if (cantUppercut)
		{
			playHitHighAnim();
			return;
		}

		switch (note.noteType)
		{
			// Pico fails to punch, and instead gets hit!
			case "weekend-1-punchlow":
				playHitLowAnim();
			case "weekend-1-punchlowblocked":
				playHitLowAnim();
			case "weekend-1-punchlowdodged":
				playHitLowAnim();
			case "weekend-1-punchlowspin":
				playHitSpinAnim();

			// Pico fails to punch, and instead gets hit!
			case "weekend-1-punchhigh":
				playHitHighAnim();
			case "weekend-1-punchhighblocked":
				playHitHighAnim();
			case "weekend-1-punchhighdodged":
				playHitHighAnim();
			case "weekend-1-punchhighspin":
				playHitSpinAnim();

			// Pico fails to block, and instead gets hit!
			case "weekend-1-blockhigh":
				playHitHighAnim();
			case "weekend-1-blocklow":
				playHitLowAnim();
			case "weekend-1-blockspin":
				playHitSpinAnim();

			// Pico fails to dodge, and instead gets hit!
			case "weekend-1-dodgehigh":
				playHitHighAnim();
			case "weekend-1-dodgelow":
				playHitLowAnim();
			case "weekend-1-dodgespin":
				playHitSpinAnim();

			// Pico ALWAYS gets punched.
			case "weekend-1-hithigh":
				playHitHighAnim();
			case "weekend-1-hitlow":
				playHitLowAnim();
			case "weekend-1-hitspin":
				playHitSpinAnim();

			// Fail to dodge the uppercut.
			case "weekend-1-picouppercutprep":
				playPunchHighAnim();
				cantUppercut = true;
			case "weekend-1-picouppercut":
				playUppercutAnim(false);

			// Darnell's attempt to uppercut, Pico dodges or gets hit.
			case "weekend-1-darnelluppercutprep":
				playIdleAnim();
			case "weekend-1-darnelluppercut":
				playUppercutHitAnim();

			case "weekend-1-idle":
				playIdleAnim();
			case "weekend-1-fakeout":
				playHitHighAnim();
			case "weekend-1-taunt":
				playTauntConditionalAnim();
			case "weekend-1-tauntforce":
				playTauntAnim();
			case "weekend-1-reversefakeout":
				playIdleAnim();
		}
	}
	
	public static function noteMissPress(direction:Int)
	{
		if (willMissBeLethal())
			playHitLowAnim(); // Darnell throws a punch so that Pico dies.
		else 
			playPunchHighAnim(); // Pico wildly throws punches but Darnell dodges.
	}

	static var alternate:Bool = false;
	static function doAlternate():String
	{
		alternate = !alternate;
		return alternate ? '1' : '2';
	}

	static function playBlockAnim()
	{
		boyfriend.playAnim('block', true);
		FlxG.camera.shake(0.002, 0.1);
		moveToBack();
	}

	static function playCringeAnim()
	{
		boyfriend.playAnim('cringe', true);
		moveToBack();
	}

	static function playDodgeAnim()
	{
		boyfriend.playAnim('dodge', true);
		moveToIdle();
	}

	static function playIdleAnim()
	{
		boyfriend.playAnim('idle', false);
		moveToBack();
	}

	static function playFakeoutAnim()
	{
		boyfriend.playAnim('fakeout', true);
		moveToBack();
	}

	static function playUppercutPrepAnim()
	{
		boyfriend.playAnim('uppercutPrep', true);
		moveToFront();
	}

	static function playUppercutAnim(hit:Bool)
	{
		boyfriend.playAnim('uppercut', true);
		if (hit) FlxG.camera.shake(0.005, 0.25);
		moveToFront();
	}

	static function playUppercutHitAnim()
	{
		boyfriend.playAnim('uppercutHit', true);
		FlxG.camera.shake(0.005, 0.25);
		moveToBack();
	}

	static function playHitHighAnim()
	{
		boyfriend.playAnim('hitHigh', true);
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	static function playHitLowAnim()
	{
		boyfriend.playAnim('hitLow', true);
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	static function playHitSpinAnim()
	{
		boyfriend.playAnim('hitSpin', true);
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	static function playPunchHighAnim()
	{
		boyfriend.playAnim('punchHigh' + doAlternate(), true);
		moveToFront();
	}

	static function playPunchLowAnim()
	{
		boyfriend.playAnim('punchLow' + doAlternate(), true);
		moveToFront();
	}

	static function playTauntConditionalAnim()
	{
		if (boyfriend.getAnimationName() == "fakeout")
			playTauntAnim();
		else
			playIdleAnim();
	}

	static function playTauntAnim()
	{
		boyfriend.playAnim('taunt', true);
		moveToBack();
	}

	static function willMissBeLethal()
	{
		return PlayState.instance.health <= 0.0 && !PlayState.instance.practiceMode;
	}
	
	static function isDarnellPreppingUppercut()
	{
		return dad.getAnimationName() == 'uppercutPrep';
	}

	static function isDarnellInUppercut()
	{
		return dad.getAnimationName() == 'uppercut' || dad.getAnimationName() == 'uppercut-hold';
	}

	static function wasNoteHitPoorly(rating:String)
	{
		return (rating == "bad" || rating == "shit");
	}

	static function isPlayerLowHealth()
	{
		return PlayState.instance.health <= 0.3 * 2;
	}
	
	static function moveToBack()
	{
		var bfPos:Int = FlxG.state.members.indexOf(boyfriendGroup);
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		if(bfPos < dadPos) return;

		FlxG.state.members[dadPos] = boyfriendGroup;
		FlxG.state.members[bfPos] = dadGroup;
	}

	static function moveToFront()
	{
		var bfPos:Int = FlxG.state.members.indexOf(boyfriendGroup);
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		if(bfPos > dadPos) return;

		FlxG.state.members[dadPos] = boyfriendGroup;
		FlxG.state.members[bfPos] = dadGroup;
	}

	static function moveToIdle()
	{
		FlxG.state.members[originalBFPos] = boyfriendGroup;
	}

	static var boyfriend(get, never):Character;
	static var dad(get, never):Character;
	static var boyfriendGroup(get, never):FlxSpriteGroup;
	static var dadGroup(get, never):FlxSpriteGroup;
	static function get_boyfriend() return PlayState.instance.boyfriend;
	static function get_dad() return PlayState.instance.dad;
	static function get_boyfriendGroup() return PlayState.instance.boyfriendGroup;
	static function get_dadGroup() return PlayState.instance.dadGroup;
}