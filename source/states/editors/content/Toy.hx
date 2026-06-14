package states.editors.content;

class Toy extends objects.Character
{
	public var holdSingTimer:Float = 0;
	public var autoCharacter:Bool = false;

	public var side:ToySide;
	public var dropdown:PsychUIDropDownMenu;
	
	public var size:Float = 0.35;
	
	public function new(x:Float, y:Float, ?character:String, side:ToySide = PLAYER)
	{
		this.side = side;
		this.autoCharacter = (character == null);

		super(x, y, character);
		
		@:privateAccess var list:Array<String> = states.editors.ChartingState.instance.playerDropDown.list.copy();
		list.unshift('Auto.');
		
		dropdown = new PsychUIDropDownMenu(0, 0, list, (ind:Int, character:String) ->
		{
			autoCharacter = (ind == 0);

			changeCharacter(character);
			if (dropdown != null) dropdown.kill();
		});

		dropdown.kill();
		dropdown.button.visible = false;
	}
	
	public override function changeCharacter(newCharacter:String = 'bf')
	{
		if (autoCharacter) newCharacter = getDefaultCharacter(side);
		if (curCharacter == newCharacter && frames != null) return;
		
		super.changeCharacter(newCharacter);

		flipX = (side != PLAYER == flipX);
		scaleTo(size);
	}
	
	public function getDefaultCharacter(side:ToySide)
	{
		return switch (side)
		{
			case GF: (PlayState.SONG.gfVersion ?? 'gf');
			case PLAYER: (PlayState.SONG.player1 ?? 'bf');
			case OPPONENT: (PlayState.SONG.player2 ?? 'dad');
		}
	}

	public function scaleTo(x:Float = 1, ?y:Float)
	{
		scale.set(jsonScale * x, jsonScale * (y ?? x));
		updateHitbox();

		offset.x -= (positionArray[0] * x);
		offset.y -= (positionArray[1] * (y ?? x));
	}
	
	public function showDropDown(vis:Bool = true)
	{
		if (vis) dropdown.revive();
		else
		{
			dropdown.kill();
			dropdown.showDropDown(false);
			return;
		}
		
		var mousePos:FlxPoint = FlxG.mouse.getScreenPosition(dropdown.camera, FlxPoint.weak());
		
		dropdown.text = (autoCharacter ? 'Auto.' : curCharacter);
		dropdown.setPosition(mousePos.x, mousePos.y);
		dropdown.showDropDown();
	}
	
	public override function update(elapsed:Float)
	{
		if (holdSingTimer > 0)
		{
			holdSingTimer -= elapsed;
			if (holdSingTimer <= 0) holdSingTimer = 0;

			holdTimer = 0;
		}
		
		super.update(elapsed);

		if (dropdown != null && dropdown.alive) 
		{
			dropdown.update(elapsed);
			if (PsychUIDropDownMenu.focusOn != dropdown) dropdown.kill();
		}
	}
	
	public override function draw()
	{
		super.draw();
		dropdown.draw();
	}
	
	public function holdSing(anim:String, time:Float = 0)
	{
		holdSingTimer = Math.max(holdSingTimer, time);
		holdTimer = 0;
		
		playAnim(anim, true);
	}
	
	public override function destroy()
	{
		super.destroy();
		dropdown.destroy();
	}
}

typedef ToyHoldData = {
	var anim:String;
	var endBeat:Float;
	var startBeat:Float;
}

enum abstract ToySide(String) to String {
	var GF = 'gf';
	var PLAYER = 'player';
	var OPPONENT = 'opponent';
}