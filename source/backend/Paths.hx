package backend;

import flash.media.Sound;

import openfl.geom.Rectangle;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;

#if MODS_ALLOWED
import backend.Mods;
#end

using haxe.io.Path;

class Paths
{
	public static inline final ASSETS = 'assets';
	public static inline final MODS = 'mods';

	public static inline final SOUND_EXT = 'ogg';
	public static inline final VIDEO_EXT = 'mp4';

	@:allow(funkin.backend.FunkinCache)
	static var tempAtlasFramesCache:Map<String, FlxAtlasFrames> = [];

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, ?parentFolder:String, ?modsAllowed:Bool = true):String
	{
		if (file.startsWith(ASSETS) || file.startsWith(MODS)) return file;

		if (parentFolder != null) file = '$parentFolder/$file';
		
		#if MODS_ALLOWED
		if (modsAllowed)
		{
			final modPath:String = modFolders(file);
			if (FileSystem.exists(modPath)) return modPath;
		}
		#end

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = assets('$currentLevel/$file');
			if (FunkinAssets.exists(levelPath)) return levelPath;
		}
		
		final embedPath = assets('embeds/$file');
		if (FunkinAssets.exists(embedPath)) return embedPath;

		final sharedPath = shared(file);
		if (FunkinAssets.exists(sharedPath)) return sharedPath;
		
		return assets(file);
	}

	public static function getFilePath(key:String, extensions:Array<String>, ?parentFolder:String, ?modsAllowed:Bool = true):String
	{
		for (ext in extensions)
		{
			final path = getPath('$key.$ext', parentFolder, modsAllowed);
			if (fileExists(path)) return path;
		}
		
		return getPath(key, parentFolder, modsAllowed);
	}

	inline static public function assets(file:String = ''):String
	{
		return '$ASSETS/$file';
	}

	inline static public function shared(file:String = ''):String
	{
		return '$ASSETS/shared/$file';
	}

	/**
	 * Searches for a .txt file within the `data` directory.
	 */
	public static inline function txt(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('data/$key.txt', folder, modsAllowed);
	}

	/**
	 * Searches for a .xml file within the `data` directory.
	 */
	public static inline function xml(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('data/$key.xml', folder, modsAllowed);
	}

	/**
	 * Searches for a .json file within the `songs` directory.
	 */
	public static inline function json(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('data/$key.json', folder, modsAllowed);
	}

	/**
	 * Searches for a .frag file within the `shaders` directory.
	 */
	public static inline function frag(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('shaders/$key.frag', folder, modsAllowed);
	}

	/**
	 * Searches for a .vert file within the `shaders` directory.
	 */
	 public static inline function vert(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('shaders/$key.vert', folder, modsAllowed);
	}

	/**
	 * Searches for a .lua file directory.
	 */
	public static inline function lua(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('$key.lua', folder, modsAllowed);
	}

	/**
	 * Searches for a .hx file directory.
	 */
	public static inline function hx(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('$key.hx', folder, modsAllowed);
	}

	/**
	 * Searches for a .mp4 within the `videos` directory.
	 */
	public static function video(key:String, ?folder:String, modsAllowed:Bool = true):String
	{
		return getPath('videos/$key.$VIDEO_EXT', folder, modsAllowed);
	}

	public static inline function inst(song:String, ?postFix:String, ?modsAllowed:Bool = true):Null<Sound>
	{
		var songKey = format(song) + '/Inst';
		if (postFix != null) songKey += '-$postFix';

		songKey = getPath('songs/$songKey.$SOUND_EXT', null, modsAllowed);
		
		return FunkinAssets.getSound(songKey);
	}

	public static inline function voices(song:String, ?postFix:String, ?modsAllowed:Bool = true):Null<Sound>
	{
		var songKey = format(song) + '/Voices';
		if (postFix != null) songKey += '-$postFix';

		songKey = getPath('songs/$songKey.$SOUND_EXT', null, modsAllowed);
		
		return FunkinAssets.getSoundDirectly(songKey);
	}

	/**
	 * Searches for a file within the `sounds` directory and caches a `Sound` instance.
	 */
	public static inline function sound(key:String, ?folder:String, ?modsAllowed:Bool = true):Sound
	{
		return FunkinAssets.getSound(getPath('sounds/$key.$SOUND_EXT', folder, modsAllowed));
	}

	/**
	 * Searches for a file within the `music` directory and caches a `Sound` instance.
	 */
	inline static public function music(key:String, ?folder:String, ?modsAllowed:Bool = true):Sound
	{
		return FunkinAssets.getSound(getPath('music/$key.$SOUND_EXT', folder, modsAllowed));
	}

	/**
	 * Searches for a file within the `sounds` directory and caches a multiple random `Sound` instances.
	 */
	inline static public function soundRandom(key:String, min:Int = 0, max:Int = 0, ?folder:String, ?modsAllowed:Bool = true):Sound
	{
		return sound(key + FlxG.random.int(min, max), folder, modsAllowed);
	}

	/**
	 * Searches for a file within the `images` directory and caches a `FlxGraphic` instance.
	 */
	static public function image(key:String, ?folder:String = null, ?allowGPU:Bool = true, ?modsAllowed:Bool = true):FlxGraphic
	{
		return FunkinAssets.getGraphic(getPath('images/$key.png', folder, modsAllowed), true, allowGPU);
	}

	inline static public function font(key:String, ?folder:String, ?modsAllowed:Bool = true):String
	{
		return getFilePath('fonts/$key', ['ttf', 'otf'], folder, modsAllowed);
	}

	public static function readDirectory(path:String, ?parentFolder:String = null, ?modsAllowed:Bool = true):Array<String>
	{
		return FunkinAssets.readDirectory(getPath(path, parentFolder, modsAllowed));
	}
	
	public static function listFilesInDirectory(path:String, ?extensions:Array<String> = null, ?parentFolder:String = null, ?modsAllowed:Bool = true):Array<String>
	{
		var entries = readDirectory(path, parentFolder, modsAllowed);
		if (extensions == null) return entries;

		var extsDot = extensions.map((e) -> return '.' + e.toLowerCase());

		if (entries != null && entries.length > 0)
		{
			return entries.filter((name) ->
			{
				final lower = name.toLowerCase();
				for (ext in extsDot) if (lower.endsWith(ext)) return true;

				return false;
			});
		}
		
		return [];
	}

	public static function listPathsInDirectory(path:String, ?extensions:Array<String> = null, ?parentFolder:String = null, ?modsAllowed:Bool = true):Array<String>
	{
		final base = getPath(path, parentFolder, modsAllowed);
		final names = listFilesInDirectory(path, extensions, parentFolder, modsAllowed);

		return names.map((name) -> return '$base/$name');
	}

	public static function getTextFromFile(key:String, ?parentFolder:String, ?modsAllowed:Bool = true):String
	{
		key = getPath(key, parentFolder, modsAllowed);
		return FunkinAssets.exists(key) ? FunkinAssets.getContent(key) : '';
	}

	public static inline function fileExists(key:String, ?parentFolder:String = null, ?modsAllowed:Bool = true)
	{
		return FunkinAssets.exists(getPath(key, parentFolder, modsAllowed));
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', parentFolder, true);
		if (FunkinAssets.exists(myXml))
		{
			#if MODS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? getTextFromFile(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', parentFolder, true);
			if (FunkinAssets.exists(myJson))
			{
				#if MODS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? getTextFromFile(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}

		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
		if (keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if (extraFrames != null) parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	static public function getMultiAnimateAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true, ?modsAllowed:Bool = true):FlxFramesCollection
	{	
		var addedKeys:Array<String> = [];
		var framesList:Array<FlxAtlasFrames> = [];
		
		if (keys.length > 0)
		{
			for (i in 0...keys.length)
			{
				final key = keys[i].trim();
				if (key == null || key.length < 1 || addedKeys.contains(key)) continue;

				var frames:FlxAtlasFrames = null;
				if (!fileExists('images/$key/Animation.json', parentFolder, modsAllowed))
				{
					frames = Paths.getAtlas(key, parentFolder, allowGPU);
				}
				else frames = Paths.getAnimateAtlas(key, parentFolder);
		
				if (frames == null)
				{
					FlxG.log.error('Multi-Animate atlas could not load frames: $key');
					continue;
				}

				addedKeys.push(key);
				framesList.push(frames);
			}
		}
		
		return FlxAnimateFrames.combineAtlas(framesList);
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String, ?allowGPU:Bool = true, modsAllowed:Bool = true):FlxAtlasFrames
	{
		final directPath = getPath('images/$key.png', parentFolder, modsAllowed).withoutExtension();
		final tempFrames = tempAtlasFramesCache.get(directPath);
		if (tempFrames != null)
		{
			return tempFrames;
		}
		
		final xmlPath = getPath('images/$key.xml', parentFolder, modsAllowed);
		final frames = FlxAtlasFrames.fromSparrow(image(key, parentFolder, allowGPU, modsAllowed), FunkinAssets.exists(xmlPath) ? FunkinAssets.getContent(xmlPath) : null);
		if (frames != null) tempAtlasFramesCache.set(directPath, frames);
		return frames;
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if (MODS_ALLOWED && sys)
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if (FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? getTextFromFile(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if (MODS_ALLOWED && sys)
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if (FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? getTextFromFile(json) : getPath(Language.getFileTranslation('images/$key') + '.json', parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', parentFolder));
		#end
	}

	inline static public function getAnimateAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true, ?modsAllowed:Bool = true):FlxAtlasFrames
	{
		if (!fileExists('images/$key/Animation.json', parentFolder, modsAllowed))
		{
			return getAtlas(key, parentFolder, allowGPU);
		}
		
		var atlas = FlxAnimateFrames.fromAnimate(getPath(Language.getFileTranslation('images/$key'), parentFolder, modsAllowed), null, null, null, true);
		
		if (atlas.parent != null)
		{
			FunkinAssets.cache.gpuCacheBitmap(atlas.parent.bitmap);
			atlas.parent.destroyOnNoUse = false;
		}

		return atlas;
	}

	/**
	 * Removes all non alpha numeric chars and replaces spaces with `-` to lower in a given String.
	 */
	public static inline function format(path:String):String
	{
		return ~/[^- a-zA-Z0-9..\/]+\//g.replace(path, '').replace(' ', '-').toLowerCase().trim();
	}

	#if MODS_ALLOWED
	/**
	 * Inserts the mod asset path to the given file path
	 */
	public static inline function mods(key:String = ''):String
	{
		return '$MODS/$key';
	}

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');
	
	/**
	 * Searches the primary loaded mod path and general mod path for a given file
	 */
	public static function modFolders(key:String):String
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			final fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if (fileExists(fileToCheck)) return fileToCheck;
		}
		
		for (mod in Mods.globalMods)
		{
			final fileToCheck:String = mods(mod + '/' + key);
			if (fileExists(fileToCheck)) return fileToCheck;
		}

		return mods(key);
	}
	#end

	@:deprecated("`Paths.getFolderPath` is deprecated, just use `Paths.assets` instead")
	inline static public function getFolderPath(file:String = '', ?folder:String = null)
	{
		return assets(file);
	}

	@:deprecated("`Paths.getSharedPath` is deprecated, just use `Paths.shared` instead")
	inline public static function getSharedPath(file:String = '')
	{
		return shared(file);
	}

	@:deprecated("`Paths.formatToSongPath` is deprecated, just use `Paths.format` instead")
	public static inline function formatToSongPath(path:String)
	{
		return format(path);
	}

	@:deprecated("`Paths.loadAnimateAtlas` is deprecated, just use `Paths.getAnimateAtlas` instead")
	public static function loadAnimateAtlas(spr:FlxAnimate, folder:Dynamic, ?spriteJson:Dynamic = null, ?animationJson:Dynamic = null)
	{
		if (spr != null) spr.frames = Paths.getAnimateAtlas(folder);
	}
}