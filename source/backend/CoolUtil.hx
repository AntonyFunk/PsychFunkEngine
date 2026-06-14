package backend;

import openfl.utils.Assets;
import openfl.display.BitmapData;
import lime.utils.Assets as LimeAssets;

class CoolUtil
{
	public static function checkForUpdates(url:String = null):String
	{
		if (url == null || url.length == 0) 
			url = "https://raw.githubusercontent.com/inky03/FNF-PsychEngine/mod/gitVersion.txt";
		
		var version:String = states.MainMenuState.modVersion.trim();
		if (ClientPrefs.data.checkForUpdates)
		{
			var http = new haxe.Http(url);
			trace('checking for updates...');

			http.onData = (data:String) ->
			{
				var newVersion:String = data.split('\n')[0].trim();
				trace('version online: $newVersion, your version: $version');

				if (newVersion > version)
				{
					http.onError = null;
					http.onData = null;
					http = null;

					version = newVersion;
					trace('using an outdated version! please update');
				}
			}

			http.onError = (error) ->
			{
				trace('error: $error');
			}

			http.request();
		}

		return version;
	}

	inline public static function quantize(f:Float, snap:Float)
	{
		return (Math.fround(f * snap) / snap);
	}

	inline public static function capitalize(text:String):String
	{
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();
	}

	inline public static function capitalizeAt(text:String, keys:Array<String> = null):String
	{
		if (keys != null)
		{
			for (key in keys)
			{
				if (key == null || key.length == 0) continue;

				var lower = key.toLowerCase();
				text = text.toLowerCase().replace(lower, capitalize(lower));
			}
		}
		
		return text.charAt(0).toUpperCase() + text.substr(1);
	}

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = '';
		#if (sys && MODS_ALLOWED)
		if (FileSystem.exists(path)) daList = Paths.getTextFromFile(path);
		#else
		if (Assets.exists(path)) daList = Assets.getText(path);
		#end

		return listFromString(daList);
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;

		var color:String = hideChars.split(color).join('').trim();
		if (color.startsWith('0x')) color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if (colorNum == null) colorNum = FlxColor.fromString('#$color');

		return colorNum != null ? colorNum : FlxColor.WHITE;
	}

	inline public static function listFromString(str:String):Array<String>
	{
		return str.split('\n').map((s:String) -> s.trim());
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);

		return Math.floor(value * Math.pow(10, decimals)) / Math.pow(10, decimals);
	}

	inline public static function dominantColor(sprite:FlxSprite):FlxColor
	{
		var colors:Map<Int, Int> = [];
		var bitmap:BitmapData = Assets.getBitmapData(Paths.getPath(sprite.graphic.key));

		for (x in 0...sprite.frameWidth)
		{
			for (y in 0...sprite.frameHeight)
			{
				var color:FlxColor = bitmap.getPixel32(x, y);
				if (color.alphaFloat > 0.05)
				{
					color = FlxColor.fromRGB(color.red, color.green, color.blue, 255);
					colors[color] = (colors.exists(color) ? colors[color] : 0) + 1;
				}
			}
		}

		var maxCount:Int = 0;
		var dominant:Int = 0; // after the loop this will store the max color
		colors[FlxColor.BLACK] = 0;
		for (color => count in colors)
		{
			if (count >= maxCount)
			{
				maxCount = count;
				dominant = color;
			}
		}

		colors = [];
		bitmap.dispose();

		return FlxColor.fromInt(dominant);
	}

	inline public static function numberArray(max:Int, ?min:Int = 0):Array<Int>
	{
		return [for (i in min...max) i];
	}

	inline public static function browserLoad(site:String)
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	inline public static function openFolder(folder:String, absolute:Bool = false)
	{
		#if sys
		if (!absolute) folder =  Sys.getCwd() + '$folder';

		folder = folder.replace('/', '\\');
		if (folder.endsWith('/')) folder.substr(0, folder.length - 1);

		var cmd:String = #if linux '/usr/bin/xdg-open' #else 'explorer.exe' #end ;
		Sys.command(cmd, [folder]);

		trace('$cmd $folder');
		#else
		throw "Platform is not supported for CoolUtil.openFolder";
		#end
	}

	/**
		Helper Function to Fix Save Files for Flixel 5

		-- EDIT: [November 29, 2023] --

		this function is used to get the save path, period.
		since newer flixel versions are being enforced anyways.
		@crowplexus
	**/
	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String
	{
		final company:String = FlxG.stage.application.meta.get('company');
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
	}

	public static function setTextBorderFromString(text:FlxText, border:String)
	{
		switch(border.toLowerCase().trim())
		{
			case 'shadow':
				text.borderStyle = SHADOW;
			case 'outline':
				text.borderStyle = OUTLINE;
			case 'outline_fast', 'outlinefast':
				text.borderStyle = OUTLINE_FAST;
			default:
				text.borderStyle = NONE;
		}
	}

	/**
	 * You can use this function in FlxTypedGroup.sort() to sort FlxObjects by their z-index values.
	 * The value defaults to 0, but by assigning it you can easily rearrange objects as desired.
	 *
	 * @param order Either `FlxSort.ASCENDING` or `FlxSort.DESCENDING`
	 * @param a The first FlxObject to compare.
	 * @param b The second FlxObject to compare.
	 * 
	 * @return 1 if `a` has a higher z-index, -1 if `b` has a higher z-index.
	*/
	public static inline function byZIndex(order:Int, a:FlxBasic, b:FlxBasic):Int
	{
		if (a == null || b == null) return 0;
		return FlxSort.byValues(order, a.zIndex, b.zIndex);
	}
}
