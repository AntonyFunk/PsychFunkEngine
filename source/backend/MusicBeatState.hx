package backend;

import flixel.FlxState;
import backend.PsychCamera;
import psychlua.CustomState;

#if GLOBAL_SCRIPTS
import scripting.hscript.FunkinModuleCollection;
import scripting.GlobalScripts;
#end

class MusicBeatState extends MusicBeatSubstate {
	public var camOther:FlxCamera = null;
	public static var timePassedOnState:Float = 0;
	public static var hardRefresh:Null<Bool> = null;
	@:dox(hide) var _psychCameraInitialized:Bool = false;
	
	public function new() {
		super();
	}
	
	/**
	 * Gets the current state.
	 * 
	 * @return 	The current `MusicBeatState`.
	*/
	public static inline function getState():MusicBeatSubstate {
		return cast (FlxG.state, MusicBeatSubstate);
	}
	/**
	 * Retrieves the current state's custom variables map.
	 * 
	 * @return 	The custom variables map.
	*/
	public static inline function getVariables():Map<String, Dynamic> {
		return FlxG.state.extraData;
	}
	
	public override function create() {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut && _requestedSubState == null)
		{
			openSubState(new CustomFadeTransition(.5, true));
		}
		
		FlxTransitionableState.skipNextTransOut = false;
		
		timePassedOnState = 0;
	}
	override function preCreate():Void {
		#if GLOBAL_SCRIPTS
		FunkinModuleCollection.refresh(hardRefresh);
		GlobalScripts.refresh(hardRefresh);
		#end
		
		hardRefresh = null;

		if (!_psychCameraInitialized) initPsychCamera();
		
		if (camOther == null) {
			camOther = new FlxCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		
		super.preCreate();
	}
	@:dox(hide) override function _preCreate():Void {
		MusicBeatSubstate.callGlobal('onCreateState', [this, Type.getClass(this)]);
	}
	@:dox(hide) override function _postCreate():Void {
		MusicBeatSubstate.callGlobal('onCreateStatePost', [this, Type.getClass(this)]);
	}
	
	/**
	 * Initializes a PsychCamera and makes it the default camera.
	 * 
	 * @return 	A new `PsychCamera`.
	*/
	public function initPsychCamera():PsychCamera {
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		return camera;
	}

	/**
	 * Switches to a new state, playing a transition. Calls `onSwitchState` on global scripts.
	 * 
	 * @param 	nextState 	The next state to switch to.
	*/
	public static function switchState(?nextState:FlxState):Void {
		if (MusicBeatSubstate.callGlobal('onSwitchState', [nextState, Type.getClass(nextState)]) != psychlua.LuaUtils.Function_Stop) {
			if (nextState == null)
				return resetState();
			
			if (FlxTransitionableState.skipNextTransIn) {
				FlxG.switchState(nextState); // actually just cant rid of this deprecated implementation or everything dies
			} else {
				startTransition(nextState);
			}
			
			FlxTransitionableState.skipNextTransIn = false;
		}
	}

	/**
	 * Resets the current state, playing a transition.
	*/
	public static function resetState():Void {
		if (FlxTransitionableState.skipNextTransIn) {
			FlxG.resetState();
		} else {
			startTransition();
		}
		
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	/**
	 * Starts a transition to a new state.
	 * 
	 * @param 	nextState 	The next state to switch to.
	*/
	public static function startTransition(?nextState:FlxState):Void {
		FlxG.state.openSubState(new CustomFadeTransition(.5, false));
		
		nextState ??= FlxG.state;
		
		if (nextState is CustomState) {
			var customState:CustomState = cast nextState;
			CustomFadeTransition.finishCallback = () -> FlxG.switchState(() -> new CustomState(customState.stateName, customState.data));
		} else {
			if (nextState == FlxG.state) {
				CustomFadeTransition.finishCallback = () -> FlxG.resetState();
			} else {
				CustomFadeTransition.finishCallback = () -> FlxG.switchState(nextState);
			}
		}
	}

	//// OTHER ////

	// Holds the key of the currently playing music track
	private static var _currentMusicKey:String = null;

	/**
	 * Starts playing the specified music track only if it's not already playing,
	 * or if you explicitly want to switch to a different track.
	 */
	 public static function startMusic(key:String, volume:Float, ?duration:Null<Float>, ?fadeOut:Null<Float>) {
		// If it's the same track and it's already playing, do nothing
		if (_currentMusicKey == key && FlxG.sound.music != null && FlxG.sound.music.playing) {
			return;
		}

		// Update the active music key
		_currentMusicKey = key;
		
		// Play the music as before
		var isFade:Bool = (duration != null || fadeOut != null);
		FlxG.sound.playMusic(Paths.music(key), (isFade ? fadeOut : volume));

		if (isFade) {
			FlxG.sound.music.volume = fadeOut;
			FlxG.sound.music.fadeIn(duration, fadeOut, volume);
		}
	}

	/**
	 * Stops the music. Call this explicitly when entering a state that
	 * should not have any background music.
	 */
	public static function endMusic(duration:Float = 1, ?fadeIn:Float = 0) {
		if (FlxG.sound.music != null && FlxG.sound.music.volume > 0) {
			FlxG.sound.music.fadeOut(duration, fadeIn);
			_currentMusicKey = null;
		}
	}
}