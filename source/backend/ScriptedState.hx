package backend;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if GLOBAL_SCRIPTS
import scripting.hscript.FunkinModuleCollection;
import scripting.GlobalScripts;
#end

class ScriptedState extends ScriptedSubState {
	public var camOther:FlxCamera = null;
	
	@:dox(hide) var _psychCameraInitialized:Bool = false;
	
	/**
	 * Shows a text string at the top-left of the game screen. Useful for debugging.
	 * 
	 * @param 	text 	The text to add.
	 * @param 	color 	The color of the text to add.
	 * @param 	size 	Optional parameter for the size of the text to add.
	*/
	public static function debugPrint(text:String, ?color:FlxColor, ?size:Int)
	{
		Log.print(text, (color == null ? NONE : CUSTOM(color)), size);
	}
	
	public override function create()
	{
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut && _requestedSubState == null)
		{
			openSubState(new CustomFadeTransition(0.5, true));
		}

		MusicBeatState.timePassedOnState = 0;
		FlxTransitionableState.skipNextTransOut = false;
	}
	public override function preCreate()
	{
		#if GLOBAL_SCRIPTS
		FunkinModuleCollection.refresh();
		GlobalScripts.refresh();
		#end

		if (!_psychCameraInitialized) initPsychCamera();
		
		if (camOther == null)
		{
			camOther = new FlxCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		
		super.preCreate();
	}
	override function _preCreate()
	{
		#if GLOBAL_SCRIPTS
		FunkinModuleCollection.refresh(MusicBeatState.hardRefresh);
		GlobalScripts.refresh(MusicBeatState.hardRefresh);
		#end
		
		MusicBeatState.hardRefresh = null;
		
		#if SCRIPTS_ALLOWED startStateScripts(); #end
		MusicBeatSubstate.callGlobal('onCreateState', [this, Type.getClass(this)]);
	}
	override function _postCreate()
	{
		callOnScripts('onCreatePost');
		MusicBeatSubstate.callGlobal('onCreateStatePost', [this, Type.getClass(this)]);
	}
	#if SCRIPTS_ALLOWED
	public override function startStateScripts():Bool
	{
		var loaded:Bool = false;

		#if HSCRIPT_ALLOWED
		loaded = startHScripts();
		#end

		#if LUA_ALLOWED
		FunkinLua.registerFunctions();
		MusicBeatSubstate.callGlobal('onRegisterLuaAPI');

		callOnHScript('onRegisterLuaAPI');
		loaded = (startLuas() || loaded);
		#end
		
		return loaded;
	}
	#end
	
	public function initPsychCamera():PsychCamera
	{
		_psychCameraInitialized = true;
		
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);

		return camera;
	}
	
	override function getFolderName():String
	{
		return 'states';
	}
}