package options;

import objects.Character;

import backend.Native;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	public function new() {
		super(Language.getPhrase('graphics_menu', 'Graphics Settings'), 'Graphics Settings Menu');
		
		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.onFinish.add((_) -> boyfriend.dance());
		boyfriend.visible = false;

		//I'd suggest using "Low Quality" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Low Quality', //Name
			'If checked, background details will be disabled,\ndecreasing loading times and improving performance.', //Description
			'lowQuality', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, improving performance\nat the cost of rougher visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing; //Changing onChange is only needed if you want to make a special interaction after it changes the value
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Shaders', //Name
			"Enables shaders, commonly used for visual effects.\nMight be CPU intensive for weaker PCs.", //Description
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching', //Name
			"Allows caching textures to the GPU, decreasing RAM usage.\nDisable this if your Graphics Card is weak.", //Description
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !(mobile || html5)
		var option:Option = new Option('VSync',
			"If checked, the game attempts to match the framerate with your monitor's refresh rate.",
			'vSync',
			BOOL);
		addOption(option);

		option.onChange = onChangeFramerate;

		var option:Option = new Option('Framerate',
			"Changes how many frames the game can display per second.",
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 30;
		option.maxValue = 240;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#end
		
		insert(1, boyfriend);
	}

	function onChangeAntiAliasing(?_, ?_)
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate(?_, ?_)
	{
		var refreshRate = FlxG.stage.application.window.displayMode.refreshRate;
		var framerate = ClientPrefs.data.vSync ? refreshRate : ClientPrefs.data.framerate;

		if (ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = framerate;
			FlxG.drawFramerate = framerate;
		}
		else
		{
			FlxG.drawFramerate = framerate;
			FlxG.updateFramerate = framerate;
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}