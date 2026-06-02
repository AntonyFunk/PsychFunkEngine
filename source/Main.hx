package;

#if android
import android.content.Context;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

import openfl.Assets;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
#end

import haxe.io.Path;

import debug.FPSCounter;
import debug.ScriptTraceDisplay;

import backend.Highscore;
import backend.ScriptedState;

#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end

import funkin.backend.FunkinGame;

#if GLOBAL_SCRIPTS
import scripting.GlobalScripts;
#end

#if HSCRIPT_ALLOWED
#if (!macro && HSCRIPT_SCRIPTED_CLASSES)
import scripting.hscript.ScriptedClasses;
#end
import scripting.hscript.FunkinHscript;
#end

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

// // // // // // // // //
class Main extends Sprite
{
	public static final game = 
	{
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: states.TitleState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var appName(default, null):String;
	
	public static var fpsVar:FPSCounter;
	public static var traces:ScriptTraceDisplay;
	
	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function loadGameEarly()
	{
		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		// Credits to MAJigsaw77 (he's the og author for this code)
		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end
		
		#if (linux || mac) // fix the app icon not showing up on the Linux Panel
		FlxG.stage.window.setIcon(Image.fromFile('icon.png'));
		#end

		#if !mobile
		FlxG.stage.align = "tl";
		FlxG.stage.scaleMode = StageScaleMode.NO_SCALE;
		#end
	}
	
	public function new()
	{
		super();
		
		#if CRASH_HANDLER
		FlxG.stage.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
		
		appName = (FlxG.stage.application.meta.get('file') ?? 'PsychEngineMint');
		
		#if hxvlc
		hxvlc.util.Handle.initAsync(#if (hxvlc >= "1.8.0")  ['--no-lua'] , #end (success:Bool) ->
		{
			trace('HXVLC LibVLC instance ${success ? 'initialized' : 'failed to initialize'}!');
		});
		#end
		
		#if LUA_ALLOWED Mods.pushGlobalMods(); #end
		Mods.loadTopMod();

		FlxG.signals.postGameReset.add(() ->
		{
			#if (!html5 && !switch) FlxG.autoPause = ClientPrefs.data.autoPause; #end
			FlxG.fixedTimestep = false;
		});

		FunkinAssets.cache.currentTrackedSounds.excludeAsset('assets/shared/music/freakyMenu.ogg');
		
		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Controls.instance = new Controls();
		
		#if GLOBAL_SCRIPTS GlobalScripts.init(); #end
		#if HSCRIPT_ALLOWED FunkinHscript.init(); #end
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(scripting.lua.CallbackHandler.call)); #end
		
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		addChild(new #if UNHOLYWANDERER04 UnholyGame #else FunkinGame #end (game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		
		ClientPrefs.loadPrefs();
		Highscore.load();

		Language.reloadPhrases();
		Difficulty.resetList();
		
		substates.OutdatedSubState.updateVersion = CoolUtil.checkForUpdates();
		
		traces = new ScriptTraceDisplay();
		addChild(traces);
		
		#if !mobile
		fpsVar = new FPSCounter(12, 4, 0xffffff);
		addChild(fpsVar);

		if (fpsVar != null) fpsVar.visible = ClientPrefs.data.showFPS;
		#end
		
		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		
		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		#if (sys && !mobile)
		// Force-kill the game to prevent background processing.
		FlxG.stage.window.onClose.add(() -> 
		{
			#if hxvlc
			hxvlc.util.Handle.dispose(); // Clean up VLC threads to prevent memory leaks.
			#end

			#if DISCORD_ALLOWED
			DiscordClient.shutdown();
			#end
			
			Sys.exit(0);
		});
		#end
		
		// shader coords fix
		FlxG.signals.gameResized.add((w:Int, h:Int) ->
		{
			if (FlxG.cameras != null)
			{
				for (cam in FlxG.cameras.list)
				{
					if (cam != null && (cam.filters != null && cam.filters.length > 0))
						resetSpriteCache(cam.flashSprite);
				}
			}

			if (FlxG.game != null) resetSpriteCache(FlxG.game);
		});
	}
	
	static function resetSpriteCache(sprite:Sprite)
	{
		@:privateAccess
		{
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
			sprite.__cacheBitmapData2 = null;
			sprite.__cacheBitmapData3 = null;
			sprite.__cacheBitmapColorTransform = null;
		}
	}
	
	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent)
	{
		var ghOld:String = 'https://github.com/inky03/PsychEngineMint'; // change this link to your actual repository if you're modding !
		var gh:String = 'https://github.com/AntonyFunk/PsychFunkEngine'; // change this link to your actual repository if you're modding !
		
		var dateNow:String = Date.now().toString().replace(' ', '_').replace(':', "'"); // yayyyy
		
		var errMsg:String = 'UNCAUGHT EXCEPTION: ${e.error}\n\nSTACK TRACEBACK:';
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		
		function stackItemToString(stackItem:haxe.CallStack.StackItem) {
			return switch (stackItem) {
				case FilePos(s, file, line, col):
					'$file:$line${col == null ? '' : ':$col'} (${stackItemToString(s)})';
				case CFunction:
					'Function from C';
				case Module(m):
					'Module $m';
				case Method(cls, method):
					'Method ${cls ?? '<unknown>'}.$method';
				case LocalFunction(n):
					'Local function #$n';
			}
		}
		
		for (stackItem in callStack) errMsg += ('\n${stackItemToString(stackItem)}');
		
		var errText:String = '$appName ${states.MainMenuState.modVersion}\n\n$errMsg\n\n$gh\n';
		
		#if sys
		var path:String = './crash/${appName}_$dateNow.txt';
		errMsg += '\n\nHas been saved in ${Path.normalize(path)}';
		#end
		
		#if officialBuild
		errMsg += '\n\nIf you believe this error was caused by the engine, report this issue at $gh';
		#end
		
		#if sys
		if (!FileSystem.exists("./crash/")) FileSystem.createDirectory("./crash/");
		
		File.saveContent(path, errText);
		Sys.println(errText);
		#end
		
		backend.Native.windowAlert(ERROR, errMsg, 'Fatal Uncaught Exception');

		#if sys
		Sys.sleep(0.1);
		FlxG.stage.window.close();
		#end
	}
	#end
}

#if UNHOLYWANDERER04
class UnholyGame extends FunkinGame
{
	public var frameCounter:Int = 0;
	
	override function onEnterFrame(_)
	{
		super.onEnterFrame(_);
		frameCounter ++;
	}
}
#end