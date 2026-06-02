package funkin.backend;

import haxe.ds.IntMap;

import openfl.Assets;
import openfl.media.Sound;
import openfl.display.BitmapData;

import flixel.util.FlxStringUtil;
import flixel.graphics.FlxGraphic;

class CacheMap<T>
{
	public var cache:Map<String, T> = [];
	public var excludeKeys:Array<String> = [];

	public function new() {}
	
	public function get(key:String):Null<T> return cache.get(key);
	
	public function exists(key:String) return cache.exists(key);
	
	public function set(key:String, value:T) cache.set(key, value);
	
	public function remove(key:String) return cache.remove(key);
	
	public function keys() return cache.keys();
	
	/**
	 * Adds a key to be considered permanent to the cache.
	 */
	public function excludeAsset(key:String)
	{
		if (!excludeKeys.contains(key)) excludeKeys.push(key);
	}
}

@:access(openfl.display.BitmapData)
@:allow(funkin.FunkinAssets)
class FunkinCache
{
	public final currentTrackedGraphics:CacheMap<FlxGraphic> = new CacheMap();
	public final currentTrackedSounds:CacheMap<Sound> = new CacheMap();
	
	public final localTrackedAssets:Array<String> = [];

	public function new() {}

	/**
	 * Clears all graphics and sounds that are considered inactive. Flags everything to be inactive as well.
	 * 
	 * use `clearUnusedMemory` afterwards to purge everything
	 */
	public function clearStoredMemory()
	{
		Paths.tempAtlasFramesCache.clear();
		
		for (key in currentTrackedSounds.keys())
		{
			if (!localTrackedAssets.contains(key) && !currentTrackedSounds.excludeKeys.contains(key))
				removeCache(key);
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets.resize(0);
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}
	
	/**
	 * Clears the graphics cache of any inactive graphics.
	 */
	public function clearUnusedMemory()
	{
		for (key in currentTrackedGraphics.keys())
		{
			if (!localTrackedAssets.contains(key) && !currentTrackedGraphics.excludeKeys.contains(key))
			{
				removeCache(key);
			}
		}
		
		// run the garbage collector for good measure
		openfl.system.System.gc();
		#if cpp cpp.vm.Gc.compact(); #end
	}
	
	/**
	 * Remove asset from the cache
	 * 
	 * @param key the id to use in the cache.
	 * @param dispose
	 * 
	 * @return Bool
	 */
	public function removeCache(key:String, dispose:Bool = true):Bool
	{
		if (currentTrackedGraphics.exists(key))
		{
			if (dispose) disposeGraphic(currentTrackedGraphics.get(key));
			currentTrackedGraphics.remove(key);
			
			return true;
		}
		
		if (currentTrackedSounds.exists(key))
		{
			if (dispose) Assets.cache.clear(key);
			currentTrackedSounds.remove(key);
			
			return true;
		}
		
		return false;
	}

	/**
	 * Push `BitmapData` instance to GPU cache.
	 * 
	 * @param bitmap The bitmap to use.
	 */
	public function gpuCacheBitmap(bitmap:BitmapData)
	{
		if (FlxG.stage.context3D == null || bitmap.image == null) return;

		if (ClientPrefs.data.cacheOnGPU)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}
	}
	
	/**
	 * Caches and returns a new `FlxGraphic` instance.
	 * 
	 * @param key the id to use in the cache.
	 * @param bitmap The bitmap to use.
	 * @param allowGPU if true, will only store in video memory.
	 * 
	 * @return FlxGraphic
	 */
	public function cacheBitmap(key:String, bitmap:BitmapData, allowGPU:Bool = true):FlxGraphic
	{
		if (allowGPU) gpuCacheBitmap(bitmap);
		
		var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		newGraphic.persist = true;
		newGraphic.destroyOnNoUse = false;
		
		localTrackedAssets.push(key);
		currentTrackedGraphics.set(key, newGraphic);

		return newGraphic;
	}

	/**
	 * Caches and returns a `Sound` instance.
	 * 
	 * @param key the id to use in the cache.
	 * @param sound The `Sound` instance to cache.
	 */
	public function cacheSound(key:String, sound:Sound):Sound
	{
		currentTrackedSounds.set(key, sound);
		localTrackedAssets.push(key);
		
		return sound;
	}

	/**
	 * Disposes of a `FlxGraphic`
	 * 
	 * @param graphic 
	 */
	public function disposeGraphic(graphic:Null<FlxGraphic>)
	{
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null) graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}
}
