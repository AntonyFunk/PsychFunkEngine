package states.editors;

import flixel.util.FlxDestroyUtil;
import flixel.graphics.FlxGraphic;

import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxOutlineEffect;

import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.utils.Assets;

import objects.Character;
import objects.HealthIcon;
import objects.Bar;

import states.editors.content.Prompt;
import states.editors.content.PsychJsonPrinter;

import flixel.graphics.frames.FlxAtlasFrames;
import animate.FlxAnimateFrames;

@:bitmap("assets/embed/images/psych-ui/cursorCross.png")
class GraphicCursorCross extends openfl.display.BitmapData {}

class CharacterEditorState extends ScriptedState implements PsychUIEventHandler.PsychUIEvent
{
	var char:Character;
	var ghost:FunkinSprite;

	var camPointer:FlxEffectSprite;
	var camDeadPointer:FlxEffectSprite;

	var silhouettes:FlxSpriteGroup;
	var dadPosition = FlxPoint.weak();
	var bfPosition = FlxPoint.weak();

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var cameraZoomText:FlxText;
	var frameAdvanceText:FlxText;

	var healthBar:Bar;
	var healthIcon:HealthIcon;

	var copiedOffset:Array<Float> = [0, 0];
	var _char:String = null;

	var anims = null;
	var animsTxt:FlxText;
	var curAnim = 0;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;

	var UI_Settings:PsychUIBox;
	var UI_Character:PsychUIBox;

	var unsavedProgress:Bool = false;

	var selectedFormat:FlxTextFormat = new FlxTextFormat(FlxColor.LIME);

	public static var onPlayState:Bool = false;

	public function new(_char:String = null, ?onPlayState:Bool = null)
	{
		this._char = _char ?? Character.DEFAULT_CHARACTER;
		if (CharacterEditorState.onPlayState) this._char = PlayState.SONG.player2;

		super();

		if (onPlayState != null) 
			CharacterEditorState.onPlayState = onPlayState;
	}

	override function create()
	{
		FunkinAssets.cache.clearStoredMemory();
		FunkinAssets.cache.clearUnusedMemory();

		FlxG.sound.music.stop();
		camEditor = initPsychCamera();

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		loadBG();
		
		preCreate();

		silhouettes = new FlxSpriteGroup();
		add(silhouettes);

		var dad:FlxSprite = new FlxSprite(dadPosition.x, dadPosition.y).loadGraphic(Paths.image('editors/silhouetteDad'));
		dad.antialiasing = ClientPrefs.data.antialiasing;
		dad.active = false;
		dad.offset.set(-4, 1);
		silhouettes.add(dad);

		var boyfriend:FlxSprite = new FlxSprite(bfPosition.x, bfPosition.y + 350).loadGraphic(Paths.image('editors/silhouetteBF'));
		boyfriend.antialiasing = ClientPrefs.data.antialiasing;
		boyfriend.active = false;
		boyfriend.offset.set(-6, 2);
		silhouettes.add(boyfriend);

		silhouettes.alpha = 0.25;

		ghost = new FunkinSprite();
		ghost.visible = false;
		ghost.alpha = ghostAlpha;
		add(ghost);

		animsTxt = new FlxText(10, 32, 400, '');
		animsTxt.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		animsTxt.scrollFactor.set();
		animsTxt.borderSize = 1;
		animsTxt.cameras = [camHUD];

		addCharacter();

		camDeadPointer = createPointer(FlxColor.RED);
		camPointer = createPointer();

		healthBar = new Bar(30, FlxG.height - 75);
		healthBar.scrollFactor.set();
		healthBar.cameras = [camHUD];
		add(healthBar);

		healthIcon = new HealthIcon(char.healthIcon, false);
		healthIcon.y = FlxG.height - 150;
		healthIcon.cameras = [camHUD];
		add(healthIcon);
		
		add(animsTxt);

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, "Press F1 for Help", 20);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		cameraZoomText = new FlxText(0, 50, 200, 'Zoom: 1x');
		cameraZoomText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		cameraZoomText.scrollFactor.set();
		cameraZoomText.borderSize = 1;
		cameraZoomText.screenCenter(X);
		cameraZoomText.cameras = [camHUD];
		add(cameraZoomText);

		frameAdvanceText = new FlxText(0, 75, 350, '');
		frameAdvanceText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		frameAdvanceText.scrollFactor.set();
		frameAdvanceText.borderSize = 1;
		frameAdvanceText.screenCenter(X);
		frameAdvanceText.cameras = [camHUD];
		add(frameAdvanceText);

		addHelpScreen();
		FlxG.mouse.visible = true;
		FlxG.camera.zoom = 1;

		makeUIMenu();

		updatePointers();
		updateHealthBar();

		if (ClientPrefs.data.cacheOnGPU) FunkinAssets.cache.clearUnusedMemory();

		super.create();
	}

	function addHelpScreen()
	{
		var str:Array<String> =
		[
			"CAMERA",
			'E/Q - Camera Zoom In/Out',
			'J/K/L/I - Move Camera',
			'R - Reset Camera Zoom',
			'',
			"CHARACTER",
			'Ctrl + R - Reset Current Offset',
			'Ctrl + C - Copy Current Offset',
			'Ctrl + V - Paste Copied Offset on Current Animation',
			'Ctrl + Z - Undo Last Paste or Reset',
			'W/S - Previous/Next Animation',
			'Space - Replay Animation',
			'Arrow Keys/Mouse & Right Click - Move Offset',
			'A/D - Frame Advance (Back/Forward)',
			'',
			"OTHER",
			'F12 - Toggle Silhouettes',
			'Hold Shift - Move Offsets 10x faster and Camera 4x faster',
			'Hold Control - Move camera 4x slower'
		];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.6;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		for (i => txt in str)
		{
			if (txt.length < 1) continue;

			var helpText:FlxText = new FlxText(0, 0, 600, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - str.length/2) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function addCharacter(reload:Bool = false)
	{
		var pos:Int = -1;
		if (char != null)
		{
			pos = members.indexOf(char);
			remove(char);
			char.destroy();
		}

		var isPlayer = (reload ? char.isPlayer : !predictCharacterIsNotPlayer(_char));
		char = new Character(0, 0, _char, isPlayer);
		if(!reload && char.editorIsPlayer != null && isPlayer != char.editorIsPlayer)
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = (char.originalFlipX != char.isPlayer);
			if(check_player != null) check_player.checked = char.isPlayer;
		}
		char.debugMode = true;
		char.missingCharacter = false;

		char.recalculateDanceIdle();
		char.dance();

		if (pos > -1) insert(pos, char);
		else add(char);
		updateCharacterPositions();
		reloadAnimList();
		if (healthBar != null && healthIcon != null) updateHealthBar();
	}

	function makeUIMenu()
	{
		UI_Settings = new PsychUIBox(FlxG.width - 275, 25, 250, 120, ['Ghost', 'Settings']);
		UI_Settings.scrollFactor.set();
		UI_Settings.cameras = [camHUD];

		UI_Character = new PsychUIBox(UI_Settings.x - 100, UI_Settings.y + UI_Settings.height + 10, 350, 280, ['Animations', 'Character', 'Icon']);
		UI_Character.scrollFactor.set();
		UI_Character.cameras = [camHUD];
		add(UI_Character);
		add(UI_Settings);

		addGhostUI();
		addSettingsUI();
		addAnimationsUI();
		addCharacterUI();
		addIconUI();

		UI_Settings.selectedName = 'Settings';
		UI_Character.selectedName = 'Character';
	}

	var ghostAlpha:Float = 0.6;
	function addGhostUI()
	{
		var TAB = UI_Settings.getTab('Ghost').menu;

		//var hideGhostButton:PsychUIButton = null;
		var makeGhostButton:PsychUIButton = new PsychUIButton(25, 15, "Make Ghost", function() {
			var anim:AnimationData = (curAnim >= 0 && curAnim < char.animationsArray.length) ? char.animationsArray[curAnim] : null;

			ghost.setPosition(char.x, char.y);

			ghost.frames = char.frames;
			ghost.animation.copyFrom(char.animation);

			ghost.offset.copyFrom(char.offset);
			ghost.frameOffset.copyFrom(char.frameOffset);

			ghost.scale.copyFrom(char.scale);
			ghost.updateHitbox();
			
			ghost.alpha = ghostAlpha;
			ghost.visible = char.visible;
			
			ghost.flipX = char.flipX;
			ghost.antialiasing = char.antialiasing;

			ghost.applyStageMatrix = char.applyStageMatrix;
			ghost.useRenderTexture = char.useRenderTexture;

			if (char.isAnimationNull()) return;

			FunkinAnimationUtil.addMultiAnimation(ghost, anim);

			ghost.animation.play(char.getAnimationName(), true, false, char.getAnimationFrame());
			ghost.animation.pause();

			/*
			hideGhostButton.active = true;
			hideGhostButton.alpha = 1;
			*/

			trace('Created ghost of "${ghost.getAnimationName()}" animation at frame ${ghost.getAnimationFrame()}');
		});

		/*
		hideGhostButton = new PsychUIButton(20 + makeGhostButton.width, makeGhostButton.y, "Hide Ghost", function() {
			ghost.visible = false;
			hideGhostButton.active = false;
			hideGhostButton.alpha = 0.6;
		});
		hideGhostButton.active = false;
		hideGhostButton.alpha = 0.6;
		*/

		var highlightGhost:PsychUICheckBox = new PsychUICheckBox(20 + makeGhostButton.x + makeGhostButton.width, makeGhostButton.y, "Highlight Ghost", 100);
		highlightGhost.onClick = function()
		{
			var value = highlightGhost.checked ? 125 : 0;
			ghost.colorTransform.redOffset = value;
			ghost.colorTransform.greenOffset = value;
			ghost.colorTransform.blueOffset = value;
		};

		var ghostAlphaSlider:PsychUISlider = new PsychUISlider(15, makeGhostButton.y + 25, 'Opacity:', (v:Float) ->
		{
			ghostAlpha = v;
			ghost.alpha = ghostAlpha;

		}, ghostAlpha, 0, 1);

		TAB.add(makeGhostButton);
		//TAB.add(hideGhostButton);
		TAB.add(highlightGhost);
		TAB.add(ghostAlphaSlider);
	}

	var check_player:PsychUICheckBox;
	var charDropDown:PsychUIDropDownMenu;
	function addSettingsUI()
	{
		var TAB = UI_Settings.getTab('Settings').menu;

		check_player = new PsychUICheckBox(10, 60, "Playable Character", 100);
		check_player.checked = char.isPlayer;
		check_player.onClick = function()
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;
			updateCharacterPositions();
			updatePointers(false);
		};

		var reloadChar:PsychUIButton = new PsychUIButton(140, 20, "Reload Char", function()
		{
			addCharacter(true);
			updatePointers();
			reloadCharacterOptions();
			reloadCharacterDropDown();
		});

		var templateCharacter:PsychUIButton = new PsychUIButton(140, 50, "Load Template", function()
		{
			final _template:CharacterFile =
			{
				animations: [
					newAnimation('idle', 'BF idle dance'),
					newAnimation('singLEFT', 'BF NOTE LEFT0'),
					newAnimation('singDOWN', 'BF NOTE DOWN0'),
					newAnimation('singUP', 'BF NOTE UP0'),
					newAnimation('singRIGHT', 'BF NOTE RIGHT0')
				],
				image: 'characters/BOYFRIEND',
				scale: 1,
				sing_duration: 4,
				healthicon: 'face',

				position: [0, 0],
				camera_position: [0, 0],
				
				death: {
					delay: 0,
					confirm_delay: 0.7,
					camera_zoom: 1.0,
					camera_position: [0, 0]
				},

				flip_x: false,
				antialiasing: true,
				healthbar_colors: [161, 161, 161],
				vocals_file: null,
			};

			char.loadCharacterFile(_template);
			char.missingCharacter = false;
			char.color = FlxColor.WHITE;
			char.alpha = 1;
			reloadAnimList();
			reloadCharacterOptions();
			updateCharacterPositions();
			updatePointers();
			reloadCharacterDropDown();
			updateHealthBar();
		});
		templateCharacter.normalStyle.bgColor = FlxColor.RED;
		templateCharacter.normalStyle.textColor = FlxColor.WHITE;

		charDropDown = new PsychUIDropDownMenu(10, 30, [''], function(index:Int, intended:String)
		{
			if (intended == null || intended.length < 1) return;
			if (intended == _char) return;

			var characterPath:String = 'characters/$intended.json';
			var path:String = Paths.getPath(characterPath, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (Assets.exists(path))
			#end
			{
				_char = intended;
				check_player.checked = char.isPlayer;
				addCharacter();
				reloadCharacterOptions();
				reloadCharacterDropDown();
				updatePointers();
			}
			else
			{
				reloadCharacterDropDown();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		});
		reloadCharacterDropDown();
		charDropDown.selectedLabel = _char;

		TAB.add(new FlxText(charDropDown.x, charDropDown.y - 15, 80, 'Character:'));
		TAB.add(check_player);
		TAB.add(reloadChar);
		TAB.add(templateCharacter);
		TAB.add(charDropDown);
	}

	var animationDropDown:PsychUIDropDownMenu;
	var animationTypeDropDown:PsychUIDropDownMenu;
	var animationRenderDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationFileInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;
	var animationFlipXCheckBox:PsychUICheckBox;
	var animationFlipYCheckBox:PsychUICheckBox;
	function addAnimationsUI()
	{
		var TAB = UI_Character.getTab('Animations').menu;

		animationInputText = new PsychUIInputText(15, 32, 150, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 38, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 38, 220, '', 8);
		animationFileInputText = new PsychUIInputText(animationIndicesInputText.x, animationIndicesInputText.y + 38, 220, '', 8);
		animationFramerate = new PsychUINumericStepper(animationIndicesInputText.x + 240, animationIndicesInputText.y + 4, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationFileInputText.x + 240, animationFileInputText.y - 1, "Looped", 40);
		animationFlipXCheckBox = new PsychUICheckBox(animationNameInputText.x + 174, animationNameInputText.y - 1, "Flip X", 40);
		animationFlipYCheckBox = new PsychUICheckBox(animationFlipXCheckBox.x + 74, animationNameInputText.y - 1, "Flip Y", 40);

		animationTypeDropDown = new PsychUIDropDownMenu(190, animationFileInputText.y + 38, ['Symbol', 'FrameLabel']);
		animationRenderDropDown = new PsychUIDropDownMenu(35, animationTypeDropDown.y, ['Sparrow', 'AnimateAtlas']);
		animationRenderDropDown.onChangeList = (selectedAnim:Int, pressed:String) -> {
			animationTypeDropDown.alpha = (selectedAnim != 1 ? 0.5 : 1.0);
			animationTypeDropDown.active = (selectedAnim != 0);
		}
		animationRenderDropDown.selectedIndex = 0;

		animationDropDown = new PsychUIDropDownMenu(190, animationInputText.y - 3, ['']);
		animationDropDown.onChangeList = (selectedAnim:Int, pressed:String) -> {
			var anim:AnimationData = char.animationsArray[selectedAnim];
			if (anim == null) return;

			animationInputText.text = anim.anim;
			animationFileInputText.text = anim.image;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationFramerate.value = anim.fps;
			animationFlipXCheckBox.checked = anim.flipX;
			animationFlipYCheckBox.checked = anim.flipY;
			animationTypeDropDown.selectedLabel = CoolUtil.capitalizeAt(anim.animType, ['label']);
			animationRenderDropDown.selectedLabel = CoolUtil.capitalizeAt(anim.renderType, ['atlas']);

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
			
			char.playAnim(anim.anim, true);

			curAnim = Std.int(Math.max(0, selectedAnim));
			updateText();
		}

		var addUpdateButton:PsychUIButton = new PsychUIButton(70, animationRenderDropDown.y + 34, "Add/Update", function() {
			var indicesText:String = animationIndicesInputText.text.trim();
			var indices:Array<Int> = [];
			if(indicesText.length > 0)
			{
				var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
				if(indicesStr.length > 0)
				{
					for (ind in indicesStr)
					{
						if(ind.contains('-'))
						{
							var splitIndices:Array<String> = ind.split('-');
							var indexStart:Int = Std.parseInt(splitIndices[0]);
							if(Math.isNaN(indexStart) || indexStart < 0) indexStart = 0;
	
							var indexEnd:Int = Std.parseInt(splitIndices[1]);
							if(Math.isNaN(indexEnd) || indexEnd < indexStart) indexEnd = indexStart;
	
							for (index in indexStart...indexEnd+1)
								indices.push(index);
						}
						else
						{
							var index:Int = Std.parseInt(ind);
							if(!Math.isNaN(index) && index > -1)
								indices.push(index);
						}
					}
				}
			}

			var lastAnim:String = (char.animationsArray[curAnim] != null) ? char.animationsArray[curAnim].anim : '';
			var lastOffsets:Array<Int> = [0, 0];
			for (anim in char.animationsArray)
				if (animationInputText.text == anim.anim)
				{
					lastOffsets = anim.offsets;
					if(char.hasAnimation(animationInputText.text))
					{
						char.animation.remove(animationInputText.text);
					}
					char.animationsArray.remove(anim);
				}

			var addedAnim:AnimationData = newAnimation(animationInputText.text, animationNameInputText.text);
			addedAnim.fps = Math.round(animationFramerate.value);
			addedAnim.loop = animationLoopCheckBox.checked;
			addedAnim.indices = indices;
			addedAnim.offsets = lastOffsets;
			addedAnim.image = animationFileInputText.text;
			addedAnim.flipX = animationFlipXCheckBox.checked;
			addedAnim.flipY = animationFlipYCheckBox.checked;
			addedAnim.animType = animationTypeDropDown.text.toLowerCase();
			addedAnim.renderType = animationRenderDropDown.text.toLowerCase();
			char.animationsArray.push(addedAnim);
			FunkinAnimationUtil.reloadFrames(char, char.animationsArray, char.imageFile.split(','));
			FunkinAnimationUtil.addMultiAnimations(char, char.animationsArray);

			curAnim = Std.int(Math.max(0, char.animationsArray.indexOf(addedAnim)));
			updateText();
			reloadAnimationDropDown(false);
			if (animationDropDown.list.length > 0)
				animationDropDown.selectedIndex = FlxMath.wrap(curAnim, 0, animationDropDown.list.length - 1);
		});

		var removeButton:PsychUIButton = new PsychUIButton(195, addUpdateButton.y, "Remove", function() {
			for (anim in char.animationsArray)
				if(animationInputText.text == anim.anim)
				{
					var resetAnim:Bool = false;
					if (anim.anim == char.getAnimationName()) resetAnim = true;

					if (char.hasAnimation(anim.anim)) char.animation.remove(anim.anim);
					char.animOffsets.remove(anim.anim);
					char.animationsArray.remove(anim);

					if(resetAnim && char.animationsArray.length > 0) {
						curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
						char.playAnim(anims[curAnim].anim, true);
					}
					reloadAnimList();
					trace('Removed animation: ' + animationInputText.text);
					break;
				}
		});
		reloadAnimList();
		animationDropDown.selectedLabel = anims[0] != null ? anims[0].anim : '';
		
		TAB.add(new FlxText(animationDropDown.x, animationDropDown.y - 15, 100, 'ANIMATION LIST:'));
		TAB.add(new FlxText(animationFileInputText.x, animationFileInputText.y - 15, 160, 'OPTIONAL - Animation File:'));
		TAB.add(new FlxText(animationInputText.x, animationInputText.y - 15, 100, 'Animation Name:'));
		TAB.add(new FlxText(animationTypeDropDown.x, animationTypeDropDown.y - 15, 100, 'Animation Type:'));
		TAB.add(new FlxText(animationRenderDropDown.x, animationRenderDropDown.y - 15, 100, 'Animation Render:'));
		TAB.add(new FlxText(animationFramerate.x, animationFramerate.y - 15, 100, 'Framerate:'));
		TAB.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 15, 150, 'Animation Prefix:'));
		TAB.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 15, 170, 'ADVANCED - Animation Indices:'));

		TAB.add(animationInputText);
		TAB.add(animationFileInputText);
		TAB.add(animationNameInputText);
		TAB.add(animationIndicesInputText);
		TAB.add(animationFramerate);
		TAB.add(animationFlipXCheckBox);
		TAB.add(animationFlipYCheckBox);
		TAB.add(animationLoopCheckBox);
		TAB.add(addUpdateButton);
		TAB.add(removeButton);
		TAB.add(animationTypeDropDown);
		TAB.add(animationRenderDropDown);
		TAB.add(animationDropDown);
	}

	var imageInputText:PsychUIInputText;
	var vocalsInputText:PsychUIInputText;

	var singLengthStepper:PsychUINumericStepper;
	var scaleStepper:PsychUINumericStepper;
	var posXStepper:PsychUINumericStepper;
	var posYStepper:PsychUINumericStepper;
	var posCamXStepper:PsychUINumericStepper;
	var posCamYStepper:PsychUINumericStepper;
	var posCamDeathXStepper:PsychUINumericStepper;
	var posCamDeathYStepper:PsychUINumericStepper;

	var flipXCheckBox:PsychUICheckBox;
	var antialiasingCheckBox:PsychUICheckBox;

	var stageMatrixCheckBox:PsychUICheckBox;
	var renderTextureCheckBox:PsychUICheckBox;

	var saveCharacterButton:PsychUIButton;
	function addCharacterUI()
	{
		final TAB = UI_Character.getTab('Character').menu;

		imageInputText = new PsychUIInputText(15, 30, 228, char.imageFile, 8);
		var reloadImage:PsychUIButton = new PsychUIButton(imageInputText.x + 238, imageInputText.y - 3, "Reload Image", function()
		{
			var lastAnim = char.getAnimationName();
			reloadCharacterImage(imageInputText.text);

			if (!char.isAnimationNull()) char.playAnim(lastAnim, true);
		});

		vocalsInputText = new PsychUIInputText(15, imageInputText.y + 35, 75, char.vocalsFile != null ? char.vocalsFile : '', 8);

		singLengthStepper = new PsychUINumericStepper(15, vocalsInputText.y + 45, 0.1, 4, 0, 999, 1);

		scaleStepper = new PsychUINumericStepper(15, singLengthStepper.y + 40, 0.1, 1, 0.05, 10, 2);

		flipXCheckBox = new PsychUICheckBox(singLengthStepper.x + 105, singLengthStepper.y - 30, "Flip X", 40);
		flipXCheckBox.checked = char.flipX;
		if (char.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.onClick = function() {
			char.originalFlipX = !char.originalFlipX;
			char.flipX = (char.originalFlipX != char.isPlayer);
		};

		antialiasingCheckBox = new PsychUICheckBox(flipXCheckBox.x - 15, flipXCheckBox.y + 30, "Antialiasing", 70);
		antialiasingCheckBox.checked = !char.noAntialiasing;
		antialiasingCheckBox.onClick = function() {
			char.antialiasing = false;
			if (antialiasingCheckBox.checked && ClientPrefs.data.antialiasing) {
				char.antialiasing = true;
			}
			char.noAntialiasing = !antialiasingCheckBox.checked;
		};

		posXStepper = new PsychUINumericStepper(singLengthStepper.x + 185, singLengthStepper.y - 35, 10, char.positionArray[0], -9999, 9999, 0);
		posYStepper = new PsychUINumericStepper(posXStepper.x + 70, posXStepper.y, 10, char.positionArray[1], -9999, 9999, 0);

		posCamXStepper = new PsychUINumericStepper(posXStepper.x, posXStepper.y + 40, 10, char.cameraPosition[0], -9999, 9999, 0);
		posCamYStepper = new PsychUINumericStepper(posYStepper.x, posYStepper.y + 40, 10, char.cameraPosition[1], -9999, 9999, 0);

		posCamDeathXStepper = new PsychUINumericStepper(posCamXStepper.x, posCamXStepper.y + 40, 10, char.cameraDeathPosition[0], -9999, 9999, 0);
		posCamDeathYStepper = new PsychUINumericStepper(posCamYStepper.x, posCamYStepper.y + 40, 10, char.cameraDeathPosition[1], -9999, 9999, 0);

		saveCharacterButton = new PsychUIButton(reloadImage.x, (UI_Character.height - TAB.height) - 58, 'Save Character', saveCharacter);

		TAB.add(new FlxText(15, imageInputText.y - 15, 100, 'Main File Name:'));
		TAB.add(imageInputText);
		
		TAB.add(new FlxText(15, vocalsInputText.y - 15, 100, 'Vocals File Postfix:'));
		TAB.add(vocalsInputText);

		TAB.add(new FlxText(15, singLengthStepper.y - 15, 120, 'Sing Duration:'));
		TAB.add(singLengthStepper);

		TAB.add(new FlxText(15, scaleStepper.y - 15, 100, 'Scale:'));
		TAB.add(scaleStepper);

		TAB.add(new FlxText(posXStepper.x, posXStepper.y - 15, 100, 'Character X/Y:'));
		TAB.add(posXStepper);
		TAB.add(posYStepper);

		TAB.add(new FlxText(posCamXStepper.x, posCamXStepper.y - 15, 100, 'Camera X/Y:'));
		TAB.add(posCamXStepper);
		TAB.add(posCamYStepper);

		TAB.add(new FlxText(posCamDeathXStepper.x, posCamDeathXStepper.y - 15, 100, 'Camera Death X/Y:'));
		TAB.add(posCamDeathXStepper);
		TAB.add(posCamDeathYStepper);
		
		TAB.add(reloadImage);
		
		TAB.add(flipXCheckBox);
		TAB.add(antialiasingCheckBox);
		
		TAB.add(saveCharacterButton);
	}

	var healthIconInputText:PsychUIInputText;
	
	var healthColorRStepper:PsychUINumericStepper;
	var healthColorGStepper:PsychUINumericStepper;
	var healthColorBStepper:PsychUINumericStepper;

	var iconColorButton:PsychUIButton;
	function addIconUI()
	{
		final TAB = UI_Character.getTab('Icon').menu;

		healthIconInputText = new PsychUIInputText(15, 30, 75, healthIcon.getCharacter(), 8);

		healthColorRStepper = new PsychUINumericStepper(healthIconInputText.x, healthIconInputText.y + 5, 20, char.healthColorArray[0], 0, 255, 0);
		healthColorGStepper = new PsychUINumericStepper(healthColorRStepper.x + 65, healthColorRStepper.y, 20, char.healthColorArray[1], 0, 255, 0);
		healthColorBStepper = new PsychUINumericStepper(healthColorGStepper.x + 130, healthColorGStepper.y, 20, char.healthColorArray[2], 0, 255, 0);

		iconColorButton = new PsychUIButton(healthColorBStepper.x, healthColorBStepper.y + 30, "Get Icon Color", () ->
		{
			var coolColor:FlxColor = CoolUtil.dominantColor(healthIcon);
			char.healthColorArray[0] = coolColor.red;
			char.healthColorArray[1] = coolColor.green;
			char.healthColorArray[2] = coolColor.blue;
			updateHealthBar();
		});
		
		TAB.add(iconColorButton);

		TAB.add(new FlxText(15, healthIconInputText.y - 15, 100, 'Health Icon Name:'));
		TAB.add(healthIconInputText);

		TAB.add(new FlxText(healthColorRStepper.x, healthColorRStepper.y - 15, 100, 'Health Bar R/G/B:'));
		TAB.add(healthColorRStepper);
		TAB.add(healthColorGStepper);
		TAB.add(healthColorBStepper);
	}

	public function UIEvent(id:String, sender:Dynamic) {
		//trace(id, sender);
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT)
		{
			if(sender == healthIconInputText) {
				var lastIcon = healthIcon.getCharacter();
				healthIcon.changeIcon(healthIconInputText.text);
				char.healthIcon = healthIconInputText.text;
				if(lastIcon != healthIcon.getCharacter()) updatePresence();
				unsavedProgress = true;
			}
			else if(sender == vocalsInputText)
			{
				char.vocalsFile = vocalsInputText.text;
				unsavedProgress = true;
			}
			else if(sender == imageInputText)
			{
				char.imageFile = imageInputText.text;
				unsavedProgress = true;
			}
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT)
		{
			if (sender == scaleStepper)
			{
				char.jsonScale = sender.value;
				char.scale.set(char.jsonScale, char.jsonScale);
				char.updateHitbox();
				unsavedProgress = true;
			}
			else if(sender == posXStepper)
			{
				char.positionArray[0] = posXStepper.value;
				updateCharacterPositions();
				unsavedProgress = true;
			}
			else if(sender == posYStepper)
			{
				char.positionArray[1] = posYStepper.value;
				updateCharacterPositions();
				unsavedProgress = true;
			}
			else if(sender == singLengthStepper)
			{
				char.singDuration = singLengthStepper.value;
				unsavedProgress = true;
			}
			else if(sender == posCamXStepper)
			{
				char.cameraPosition[0] = posCamXStepper.value;
				updatePointerPos();
				unsavedProgress = true;
			}
			else if(sender == posCamYStepper)
			{
				char.cameraPosition[1] = posCamYStepper.value;
				updatePointerPos();
				unsavedProgress = true;
			}
			else if(sender == posCamDeathXStepper)
			{
				char.cameraDeathPosition[0] = posCamDeathXStepper.value;
				updatePointerPos(true, true);
				unsavedProgress = true;
			}
			else if(sender == posCamDeathYStepper)
			{
				char.cameraDeathPosition[1] = posCamDeathYStepper.value;
				updatePointerPos(true, true);
				unsavedProgress = true;
			}
			else if(sender == healthColorRStepper)
			{
				char.healthColorArray[0] = Math.round(healthColorRStepper.value);
				updateHealthBar();
				unsavedProgress = true;
			}
			else if(sender == healthColorGStepper)
			{
				char.healthColorArray[1] = Math.round(healthColorGStepper.value);
				updateHealthBar();
				unsavedProgress = true;
			}
			else if(sender == healthColorBStepper)
			{
				char.healthColorArray[2] = Math.round(healthColorBStepper.value);
				updateHealthBar();
				unsavedProgress = true;
			}
		}
	}

	function reloadCharacterImage(?image:String)
	{
		var lastAnim:String = char.getAnimationName();

		char.color = FlxColor.WHITE;
		char.alpha = 1;

		char.loadCharacterFile(null, image);

		if (char.animationsArray.length > 0)
		{
			if (lastAnim != '') char.playAnim(lastAnim, true);
			else char.dance();
		}
	}

	function reloadCharacterOptions()
	{
		if (UI_Character == null) return;

		check_player.checked = char.isPlayer;
		imageInputText.text = char.imageFile;
		healthIconInputText.text = char.healthIcon;
		vocalsInputText.text = char.vocalsFile != null ? char.vocalsFile : '';
		singLengthStepper.value = char.singDuration;
		scaleStepper.value = char.jsonScale;
		flipXCheckBox.checked = char.originalFlipX;
		antialiasingCheckBox.checked = !char.noAntialiasing;
		posXStepper.value = char.positionArray[0];
		posYStepper.value = char.positionArray[1];
		posCamXStepper.value = char.cameraPosition[0];
		posCamYStepper.value = char.cameraPosition[1];
		posCamDeathXStepper.value = char.cameraDeathPosition[0];
		posCamDeathYStepper.value = char.cameraDeathPosition[1];
		reloadAnimList();
		updateHealthBar();
	}

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	var undoOffsets:Array<Float> = null;
	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		super.update(elapsed);

		if (PsychUIInputText.focusOn != null)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// CAMERA CONTROLS
		if (FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		var lastZoom = FlxG.camera.zoom;
		if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 5)
		{
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if (FlxG.camera.zoom > 5) FlxG.camera.zoom = 5;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1)
		{
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if (FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		}

		if (lastZoom != FlxG.camera.zoom) cameraZoomText.text = 'Zoom: ' + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + 'x';

		// CHARACTER CONTROLS
		var changedAnim:Bool = false;
		if (anims.length > 1)
		{
			if (FlxG.keys.justPressed.W && (changedAnim = true)) curAnim--;
			else if (FlxG.keys.justPressed.S && (changedAnim = true)) curAnim++;
			
			if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(animsTxt, camHUD)) {
				var p:Float = FlxMath.remapToRange(FlxG.mouse.getWorldPosition(camHUD).y, animsTxt.y, animsTxt.y + animsTxt.textField.textHeight, 0, anims.length);
				var animIndex:Int = Std.int(Math.min(p, anims.length - 1));
				if (curAnim != animIndex) {
					curAnim = animIndex;
					changedAnim = true;
				}
			}
			
			if (changedAnim)
			{
				undoOffsets = null;
				curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
				animationDropDown.selectedLabel = anims[curAnim].anim;
				updateText();
			}
		}

		var changedOffset = false;
		var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
		var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
		if (moveKeysP.contains(true))
		{
			char.frameOffset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
			char.frameOffset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
			changedOffset = true;
		}

		if (moveKeys.contains(true))
		{
			holdingArrowsTime += elapsed;
			if(holdingArrowsTime > 0.6)
			{
				holdingArrowsElapsed += elapsed;
				while(holdingArrowsElapsed > (1/60))
				{
					char.frameOffset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
					char.frameOffset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
					holdingArrowsElapsed -= (1/60);
					changedOffset = true;
				}
			}
		}
		else holdingArrowsTime = 0;

		if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
		{
			char.frameOffset.x -= FlxG.mouse.deltaViewX;
			char.frameOffset.y -= FlxG.mouse.deltaViewY;
			changedOffset = true;
		}

		if(FlxG.keys.pressed.CONTROL)
		{
			if(FlxG.keys.justPressed.C)
			{
				copiedOffset[0] = char.frameOffset.x;
				copiedOffset[1] = char.frameOffset.y;
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.V)
			{
				undoOffsets = [char.frameOffset.x, char.frameOffset.y];
				char.frameOffset.x = copiedOffset[0];
				char.frameOffset.y = copiedOffset[1];
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.R)
			{
				undoOffsets = [char.frameOffset.x, char.frameOffset.y];
				char.frameOffset.set(0, 0);
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.Z && undoOffsets != null)
			{
				char.frameOffset.x = undoOffsets[0];
				char.frameOffset.y = undoOffsets[1];
				changedOffset = true;
			}
		}

		var anim:AnimationData = (curAnim >= 0 && curAnim < char.animationsArray.length) ? char.animationsArray[curAnim] : null;
		if(changedOffset && anim != null && anim.offsets != null)
		{
			anim.offsets[0] = Std.int(char.frameOffset.x);
			anim.offsets[1] = Std.int(char.frameOffset.y);

			char.addOffset(anim.anim, char.frameOffset.x, char.frameOffset.y);
			updateText();
		}

		var txt = 'ERROR: No Animation Found';
		var clr = FlxColor.RED;
		if(!char.isAnimationNull())
		{
			if (FlxG.keys.pressed.A || FlxG.keys.pressed.D)
			{
				holdingFrameTime += elapsed;
				if (holdingFrameTime > 0.5) holdingFrameElapsed += elapsed;
			}
			else holdingFrameTime = 0;

			if (FlxG.keys.justPressed.SPACE) char.playAnim(char.getAnimationName(), true);

			var frames:Int = char.animation.curAnim.curFrame;
			var length:Int = char.animation.curAnim.numFrames;

			if (length >= 0)
			{
				if(FlxG.keys.justPressed.A || FlxG.keys.justPressed.D || holdingFrameTime > 0.5)
				{
					var isLeft = false;
					if((holdingFrameTime > 0.5 && FlxG.keys.pressed.A) || FlxG.keys.justPressed.A) isLeft = true;
					char.animPaused = true;
	
					if(holdingFrameTime <= 0.5 || holdingFrameElapsed > 0.1)
					{
						frames = FlxMath.wrap(frames + Std.int(shiftMult * (isLeft ? -1 : 1)), 0, length - 1);
						char.animation.curAnim.curFrame = frames;
						holdingFrameElapsed -= 0.1;
					}
				}
	
				txt = 'Frames: ( $frames / ${length-1} )';
				//if(char.animation.curAnim.paused) txt += ' - PAUSED';
				clr = FlxColor.WHITE;
			}
		}
		if (txt != frameAdvanceText.text) frameAdvanceText.text = txt;
		frameAdvanceText.color = clr;

		// OTHER CONTROLS
		if (FlxG.keys.justPressed.F12)
			silhouettes.visible = !silhouettes.visible;

		if (FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
		{
			helpBg.visible = !helpBg.visible;
			helpTexts.visible = helpBg.visible;
		}
		else if (FlxG.keys.justPressed.ESCAPE)
		{
			if (!onPlayState)
			{
				if (!unsavedProgress)
				{
					MusicBeatState.switchState(new states.MainMenuState(true));
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else openSubState(new ExitConfirmationPrompt());
			}
			else
			{
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new PlayState());
			}
			return;
		}
		
		postUpdate(elapsed);
	}

	final assetFolder = 'week1';  //load from assets/week1/
	inline function loadBG()
	{
		var lastLoaded = Paths.currentLevel;
		Paths.currentLevel = assetFolder;

		/////////////
		// bg data //
		/////////////
		#if !BASE_GAME_FILES
		camEditor.bgColor = 0xFF666666;
		#else
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.95, 0.95);
		add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -730, 600, 1, 1);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);
		#end

		dadPosition.set(100, 100);
		bfPosition.set(770, 100);
		/////////////

		Paths.currentLevel = lastLoaded;
	}

	inline function createPointer(color:FlxColor = FlxColor.WHITE, ?size:Float = 35):FlxEffectSprite
	{
		var graphic = FlxGraphic.fromClass(GraphicCursorCross);
		var scale = size / graphic.width;

		var target = new FlxSprite().loadGraphic(graphic);
		var outline = new FlxOutlineEffect(NORMAL, FlxColor.BLACK, 1);

		var pointer = new FlxEffectSprite(target, [outline]);
		pointer.scale.set(scale, scale);
		pointer.updateHitbox();
		pointer.color = color;
		pointer.draw(); // force update size of pointer
		add(pointer);

		return pointer;
	}

	inline function updatePointerPos(snap:Bool = true, ?isDead:Bool = false)
	{
		var pointer = camPointer;
		if (isDead) pointer = camDeadPointer;

		if (char == null || camPointer == null) return;

		var deathPos:Array<Float> = [
			char.cameraDeathPosition[0] * (char.isPlayer ? 1 : -1), 
			char.cameraDeathPosition[1]
		];

		var offX:Float = (isDead ? deathPos[0] : 0);
		var offY:Float = (isDead ? deathPos[1] : 0);

		if (!char.isPlayer)
		{
			offX += char.getMidpoint().x + 100 + char.cameraPosition[0];
			offY += char.getMidpoint().y - 100 + char.cameraPosition[1];
		}
		else
		{
			offX += char.getMidpoint().x - 100 - char.cameraPosition[0];
			offY += char.getMidpoint().y - 100 + char.cameraPosition[1];
		}

		pointer.setPosition(offX, offY);
		if (snap)
		{
			FlxG.camera.scroll.x = pointer.getMidpoint().x - FlxG.width * 0.5;
			FlxG.camera.scroll.y = pointer.getMidpoint().y - FlxG.height * 0.5;
		}
	}

	inline function updatePointers(snap:Bool = true, ?deadSnap:Bool = false)
	{
		updatePointerPos(snap && !deadSnap);
		updatePointerPos(snap && deadSnap, true);
	}

	inline function updateHealthBar()
	{
		healthColorRStepper.value = char.healthColorArray[0];
		healthColorGStepper.value = char.healthColorArray[1];
		healthColorBStepper.value = char.healthColorArray[2];
		healthBar.leftBar.color = healthBar.rightBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
		healthIcon.changeIcon(char.healthIcon);
		updatePresence();
	}
	
	override function updatePresence() {
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + char.curCharacter, healthIcon.getCharacter());
		#end
	}

	inline function reloadAnimList()
	{
		anims = char.animationsArray;
		if(anims.length > 0) char.playAnim(anims[0].anim, true);
		curAnim = 0;

		updateText();
		reloadAnimationDropDown();
	}

	inline function updateText()
	{
		animsTxt.removeFormat(selectedFormat);

		var intendText:String = '';
		for (num => anim in anims)
		{
			if(num > 0) intendText += '\n';

			if(num == curAnim)
			{
				var n:Int = intendText.length;
				intendText += anim.anim + ": " + anim.offsets;
				animsTxt.addFormat(selectedFormat, n, intendText.length);
			}
			else intendText += anim.anim + ": " + anim.offsets;
		}
		animsTxt.text = intendText;
	}

	inline function updateCharacterPositions()
	{
		if((char != null && !char.isPlayer) || (char == null && predictCharacterIsNotPlayer(_char))) char.setPosition(dadPosition.x, dadPosition.y);
		else char.setPosition(bfPosition.x, bfPosition.y);

		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
		updatePointers(false);
	}

	inline function predictCharacterIsNotPlayer(name:String)
	{
		return (name != 'bf' && !name.startsWith('bf-') && !name.endsWith('-player') && !name.endsWith('-playable') && !name.endsWith('-dead')) ||
				name.endsWith('-opponent') || name.startsWith('gf-') || name.endsWith('-gf') || name == 'gf';
	}

	inline function newAnimation(anim:String, name:String):AnimationData
	{
		var animData = FunkinAnimationUtil.newAnimation();
		animData.anim = anim; animData.name = name;

		return animData;
	}

	var characterList:Array<String> = [];
	function reloadCharacterDropDown() {
		characterList = Mods.mergeAllTextsNamed('data/characterList.txt');
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
				{
					var charToCheck:String = file.substr(0, file.length - 5);
					if(!characterList.contains(charToCheck))
						characterList.push(charToCheck);
				}

		if (characterList.length < 1) characterList.push('');

		if (charDropDown != null) {
			charDropDown.list = characterList;
			charDropDown.selectedLabel = _char;
		}
	}

	function reloadAnimationDropDown(resetSelect:Bool = true) {
		if (animationDropDown == null) return;

		if (char != null)
			anims = char.animationsArray;

		var animList:Array<String> = [];
		for (anim in anims) animList.push(anim.anim);
		if(animList.length < 1) animList.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.list = animList;
		if (resetSelect) animationDropDown.selectedIndex = 0;
	}

	// save
	var _file:FileReference;
	function onSaveComplete(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function getDeathData():DeathData {
		return {
			delay: char.deathDelay,
			confirm_delay: char.confirmDelay,
			camera_zoom: char.cameraDeathZoom,
			camera_position: char.cameraDeathPosition
		};
	}

	function saveCharacter() {
		if (_file != null) return;

		var json:Dynamic = {
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.jsonScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,

			"position":	char.positionArray,
			"camera_position": char.cameraPosition,

			"death": getDeathData(),

			"flip_x": char.originalFlipX,
			"antialiasing": !char.noAntialiasing,
			"healthbar_colors": char.healthColorArray,
			"vocals_file": char.vocalsFile,
			"_editor_isPlayer": char.isPlayer
		};

		var data:String = PsychJsonPrinter.print(json, ['offsets', 'position', 'healthbar_colors', 'camera_position', 'indices']);

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, '$_char.json');
		}
	}
}