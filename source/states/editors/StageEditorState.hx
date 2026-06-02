package states.editors;

import backend.StageData;
import backend.PsychCamera;
import objects.Character;
import psychlua.LuaUtils;
import flixel.FlxObject;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import openfl.utils.Assets;
import openfl.display.Sprite;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import states.editors.content.Prompt;
import states.editors.content.PreloadListSubState;

class StageEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	final minZoom:Float = 0.1;
	final maxZoom:Float = 5;

	var gf:Character;
	var dad:Character;
	var boyfriend:Character;
	var stageJson:StageFile;

	var camGame:FlxCamera;
	public var camHUD:FlxCamera;

	var UI_stagebox:PsychUIBox;
	var UI_box:PsychUIBox;
	var spriteList_box:PsychUIBox;
	var stageSprites:Array<StageEditorSprite> = [];
	var allObjects:Array<FunkinSprite> = [];

	public function new(stageToLoad:String = 'stage', cachedJson:StageFile = null)
	{
		lastLoadedStage = stageToLoad;
		stageJson = cachedJson;
		super();
	}

	var unsavedProgress:Bool = false;

	var lastLoadedStage:String;
	var camFollow:FlxObject = new FlxObject(0, 0, 1, 1);

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var posTxt:FlxText;
	var outputTxt:FlxText;

	var selectionSprites:FlxTypedGroup<FunkinSprite> = new FlxTypedGroup();

	override function create()
	{
		FunkinAssets.cache.clearStoredMemory();
		FunkinAssets.cache.clearUnusedMemory();

		rpcDetails = 'Stage Editor';
		rpcState = 'Stage: $lastLoadedStage';

		camGame = initPsychCamera();
		camGame.bgColor = 0xFF666666;
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		if (stageJson == null) stageJson = StageData.getStageFile(lastLoadedStage);
		FlxG.camera.follow(null, LOCKON, 0);

		loadJsonAssetDirectory();
		gf = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.gf : 'gf');
		gf.visible = !(stageJson.hide_girlfriend);
		dad = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.dad : 'dad');
		boyfriend = new Character(0, 0, stageJson._editorMeta != null ? stageJson._editorMeta.boyfriend : 'bf', true);

		for (i in 0...4)
		{
			var spr:FunkinSprite = new FunkinSprite().makeGraphic(1, 1, FlxColor.LIME);
			spr.alpha = 0.8;
			selectionSprites.add(spr);
		}

		FlxG.camera.zoom = stageJson.defaultZoom;
		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();
		var point = focusOnTarget('boyfriend');
		FlxG.camera.scroll.set(point.x - FlxG.width * 0.5, point.y - FlxG.height * 0.5);

		screenUI();
		spriteCreatePopup();
		editorUI();

		add(camFollow);
		updateSpriteList();

		addHelpScreen();
		FlxG.mouse.visible = true;

		super.create();
	}

	function loadJsonAssetDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = stageJson.directory;
		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);
	}

	var showSelectionQuad:Bool = true;
	function addHelpScreen()
	{
		#if FLX_DEBUG
		var btn = 'F3';
		#else
		var btn = 'F2';
		#end

		var str:Array<String> = [
			"E/Q - Camera Zoom In/Out",
			"J/K/L/I - Move Camera",
			"R - Reset Camera Zoom",
			"Arrow Keys/Mouse & Right Click - Move Object",
			"",
			'$btn - Toggle HUD',
			"F12 - Toggle Selection Rectangle",
			"Hold Shift - Move Objects and Camera 4x faster",
			"Hold Control - Move Objects pixel-by-pixel and Camera 4x slower"
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

			var helpText:FlxText = new FlxText(0, 0, 680, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - str.length * 0.5) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function updateSpriteList()
	{
		for (spr in stageSprites) {
			if (spr != null) spr.destroy();
		}

		allObjects = [];
		stageSprites = [];

		var list:Map<String, Dynamic> = [];
		if (stageJson.objects != null && stageJson.objects.length > 0)
		{
			var addedObjects:Map<String, Dynamic> = StageData.addObjectsToState(stageJson.objects, gf, dad, boyfriend, null, true);

			for (i in 0...stageJson.objects.length)
			{
				var data = stageJson.objects[i];
				if (StageData.reservedNames.contains(data.type))
				{
					var name:String = '';
					var char:Dynamic = null;
					switch (data.type)
					{
						case 'gf', 'gfGroup':
							name = 'gf';
						case 'dad', 'dadGroup':
							name = 'dad';
						case 'boyfriend', 'boyfriendGroup':
							name = 'boyfriend';
					}

					if (name.length > 0) {
						char = addedObjects.get(name);
						if (char == null) char = Reflect.field(this, name);

						allObjects.push(char);
					}
				}
				else
				{
					var spr:Dynamic = null;
					if (addedObjects.exists(data.name)) spr = addedObjects.get(data.name);
					if (spr != null) stageSprites.push(spr);

					allObjects.push(new StageEditorSprite(data));
				}
			}

			list = addedObjects;
		}

		for (char in ['gf', 'dad', 'boyfriend'])
		{
			if (!list.exists(char)) allObjects.push(Reflect.field(this, char));
		}

		updateSpriteListRadio();
		updateSpriteListButtons();
	}
	
	var focusRadioGroup:PsychUIRadioGroup;
	function screenUI()
	{
		var lowQualityCheckbox:PsychUICheckBox = null;
		var highQualityCheckbox:PsychUICheckBox = null;
		function visibilityFilterUpdate()
		{
			curFilters = 0;
			if (lowQualityCheckbox.checked) curFilters |= LOW_QUALITY;
			if (highQualityCheckbox.checked) curFilters |= HIGH_QUALITY;
		}

		spriteList_box = new PsychUIBox(25, 40, 250, 200, ['Sprite List']);
		spriteList_box.scrollFactor.set();
		spriteList_box.cameras = [camHUD];
		add(spriteList_box);
		addSpriteListBox();

		var bg:FlxSprite = new FlxSprite(0, FlxG.height - 60).makeGraphic(1, 1, FlxColor.BLACK);
		bg.cameras = [camHUD];
		bg.alpha = 0.4;
		bg.scale.set(FlxG.width, FlxG.height - bg.y);
		bg.updateHitbox();
		add(bg);

		var tipText:FlxText = new FlxText(0, FlxG.height - 44, 300, 'Press F1 for Help', 20);
		tipText.alignment = CENTER;
		tipText.cameras = [camHUD];
		tipText.scrollFactor.set();
		tipText.screenCenter(X);
		tipText.active = false;
		add(tipText);

		var targetTxt:FlxText = new FlxText(30, FlxG.height - 52, 300, 'Camera Target', 16);
		targetTxt.alignment = CENTER;
		targetTxt.cameras = [camHUD];
		targetTxt.scrollFactor.set();
		targetTxt.active = false;
		add(targetTxt);

		focusRadioGroup = new PsychUIRadioGroup(targetTxt.x, FlxG.height - 24, ['dad', 'boyfriend', 'gf'], 10, 0, true);
		focusRadioGroup.onClick = function()
		{
			//trace('Changed focus to $target');
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
			FlxG.camera.target = camFollow;
		}
		focusRadioGroup.radios[0].label = 'Opponent';
		focusRadioGroup.radios[1].label = 'Boyfriend';
		focusRadioGroup.radios[2].label = 'Girlfriend';
		focusRadioGroup.checked = 1;

		for (radio in focusRadioGroup.radios) radio.text.size = 11;

		focusRadioGroup.cameras = [camHUD];
		add(focusRadioGroup);

		lowQualityCheckbox = new PsychUICheckBox(FlxG.width - 240, FlxG.height - 36, 'Can see Low Quality Sprites?', 90);
		lowQualityCheckbox.cameras = [camHUD];
		lowQualityCheckbox.onClick = visibilityFilterUpdate;
		lowQualityCheckbox.checked = false;
		add(lowQualityCheckbox);

		highQualityCheckbox = new PsychUICheckBox(FlxG.width - 120, FlxG.height - 36, 'Can see High Quality Sprites?', 90);
		highQualityCheckbox.cameras = [camHUD];
		highQualityCheckbox.onClick = visibilityFilterUpdate;
		highQualityCheckbox.checked = true;
		add(highQualityCheckbox);
		visibilityFilterUpdate();

		posTxt = new FlxText(0, 50, 500, 'X: 0\nY: 0', 24);
		posTxt.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		posTxt.borderSize = 2;
		posTxt.cameras = [camHUD];
		posTxt.screenCenter(X);
		add(posTxt);

		outputTxt = new FlxText(0, 0, 800, '', 24);
		outputTxt.alignment = CENTER;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.borderSize = 1;
		outputTxt.cameras = [camHUD];
		outputTxt.screenCenter();
		outputTxt.alpha = 0;
		add(outputTxt);
	}

	var spriteListRadioGroup:PsychUIRadioGroup;

	// Sprite list buttons
	var buttonMoveUp:PsychUIButton;
	var buttonMoveDown:PsychUIButton;
	var buttonCreate:PsychUIButton;
	var buttonDuplicate:PsychUIButton;
	var buttonDelete:PsychUIButton;
	var spriteListButtonY:Float = 0;

	/**
	 * With `maxItems` and scrolling, each visible row displays `labels[checked + curScroll]`, not `labels[checked]`.
	 */
	function spriteListGlobalLabelIndex():Int
	{
		if (spriteListRadioGroup == null || spriteListRadioGroup.checked < 0) return -1;
		return spriteListRadioGroup.checked + spriteListRadioGroup.curScroll;
	}

	function spriteListObjectIndexFromRadio():Int
	{
		var L:Int = spriteListGlobalLabelIndex();
		if (L < 0 || spriteListRadioGroup.labels == null) return -1;
		return spriteListRadioGroup.labels.length - 1 - L;
	}

	function setSpriteListSelectionToLabelIndex(L:Int):Void
	{
		var g:PsychUIRadioGroup = spriteListRadioGroup;
		if (g == null || g.labels == null || L < 0 || L >= g.labels.length) return;
		if (g.maxItems <= 0 || g.labels.length <= g.maxItems)
		{
			g.curScroll = 0;
			g.checked = L;
			return;
		}
		var maxScroll:Int = g.labels.length - g.maxItems;
		if (L < g.curScroll) g.curScroll = L;
		else if (L >= g.curScroll + g.maxItems) g.curScroll = L - g.maxItems + 1;
		g.curScroll = Std.int(FlxMath.bound(g.curScroll, 0, maxScroll));
		g.checked = L - g.curScroll;
	}

	function addSpriteListBox()
	{
		var tab_group = spriteList_box.getTab('Sprite List').menu;
		spriteListRadioGroup = new PsychUIRadioGroup(10, 10, [], 25, 18, false, 200);
		spriteListRadioGroup.cameras = [camHUD];
		spriteListRadioGroup.onClick = spriteListRadioGroup.onScroll = function()
		{
			if (spriteListRadioGroup.checked >= 0)
			{
				var li:Int = spriteListGlobalLabelIndex();
				trace('Click detected, checked: ' + spriteListRadioGroup.checked + ', label: ${li >= 0 && li < spriteListRadioGroup.labels.length ? spriteListRadioGroup.labels[li] : "?"}');
			}
			else trace('Click detected, unchecked');

			updateSelectedUI();
			updateSpriteListButtons();
		}
		spriteListRadioGroup.allowUncheck = true;
		tab_group.add(spriteListRadioGroup);

		var buttonX = spriteList_box.x + spriteList_box.width - 10;
		spriteListButtonY = spriteListRadioGroup.y - 30;
		buttonMoveUp = new PsychUIButton(buttonX, spriteListButtonY, 'Move Up', function()
		{
			if (spriteListRadioGroup.checked < 0) return;

			var selectedIdx:Int = spriteListObjectIndexFromRadio();
			var spr = allObjects[selectedIdx];
			if (spr == null) return;

			var newIdx:Int = Std.int(Math.min(allObjects.length - 1, selectedIdx + 1));
			if (newIdx == selectedIdx) return; // Already at top

			allObjects.remove(spr);
			allObjects.insert(newIdx, spr);

			var newLabelIdx:Int = allObjects.length - newIdx - 1;
			updateSpriteListRadio();
			setSpriteListSelectionToLabelIndex(newLabelIdx);
			updateSpriteListButtons();
		});
		buttonMoveUp.cameras = [camHUD];
		tab_group.add(buttonMoveUp);

		buttonMoveDown = new PsychUIButton(buttonX, spriteListButtonY + 30, 'Move Down', function()
		{
			if (spriteListRadioGroup.checked < 0) return;

			var selectedIdx:Int = spriteListObjectIndexFromRadio();
			var spr = allObjects[selectedIdx];
			if (spr == null) return;

			var newIdx:Int = Std.int(Math.max(0, selectedIdx - 1));
			if (newIdx == selectedIdx) return; // Already at bottom

			allObjects.remove(spr);
			allObjects.insert(newIdx, spr);

			var newLabelIdx:Int = allObjects.length - newIdx - 1;
			updateSpriteListRadio();
			setSpriteListSelectionToLabelIndex(newLabelIdx);
			updateSpriteListButtons();
		});
		buttonMoveDown.cameras = [camHUD];
		tab_group.add(buttonMoveDown);

		buttonCreate = new PsychUIButton(buttonX, spriteListButtonY + 60, 'New', function() createPopup.visible = createPopup.active = true);
		buttonCreate.cameras = [camHUD];
		buttonCreate.normalStyle.bgColor = FlxColor.GREEN;
		buttonCreate.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonCreate);

		buttonDuplicate = new PsychUIButton(buttonX, spriteListButtonY + 90, 'Duplicate', function()
		{
			if (spriteListRadioGroup.checked < 0) return;

			var objIdx:Int = spriteListObjectIndexFromRadio();
			var spr = allObjects[objIdx];
			if (spr == null || !Std.isOfType(spr, StageEditorSprite)) return;

			var copiedSpr:StageEditorSprite = cast spr;
			var copiedMeta:StageEditorSprite = new StageEditorSprite(copiedSpr.formatToJson());

			copiedMeta.name = findUnoccupiedName(copiedSpr.name, true);
			insertMeta(copiedMeta, 1);
		});
		buttonDuplicate.cameras = [camHUD];
		buttonDuplicate.normalStyle.bgColor = FlxColor.BLUE;
		buttonDuplicate.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonDuplicate);

		buttonDelete = new PsychUIButton(buttonX, spriteListButtonY + 120, 'Delete', function()
		{
			if (spriteListRadioGroup.checked < 0) return;

			var objIdx:Int = spriteListObjectIndexFromRadio();
			var spr = allObjects[objIdx];
			if (spr == null || !Std.isOfType(spr, StageEditorSprite)) return;

			var copiedSpr:StageEditorSprite = cast spr;
			stageSprites.remove(copiedSpr);
			allObjects.remove(spr);
			spr.destroy();

			updateSpriteListRadio();
			updateSpriteListButtons();
		});
		buttonDelete.cameras = [camHUD];
		buttonDelete.normalStyle.bgColor = FlxColor.RED;
		buttonDelete.normalStyle.textColor = FlxColor.WHITE;
		tab_group.add(buttonDelete);

		updateSpriteListButtons();
	}

	function updateSpriteListButtons()
	{
		spriteListButtonY = spriteListRadioGroup.y - 30;

		var selectedIdx:Int = spriteListObjectIndexFromRadio();
		var spr = selectedIdx >= 0 ? allObjects[selectedIdx] : null;

		if (spriteListRadioGroup.checked < 0 || selectedIdx < 0 || spr == null)
		{
			// No selection, show all buttons in default positions
			buttonCreate.y = spriteListButtonY;
			buttonMoveUp.y = spriteListButtonY + 30;
			buttonMoveDown.y = spriteListButtonY + 60;
			buttonDuplicate.y = spriteListButtonY + 90;
			buttonDelete.y = spriteListButtonY + 120;

			buttonMoveUp.visible = buttonMoveUp.active = false;
			buttonMoveDown.visible = buttonMoveDown.active = false;
			buttonDuplicate.visible = buttonDuplicate.active = false;
			buttonDelete.visible = buttonDelete.active = false;
			return;
		}

		if (!Std.isOfType(spr, StageEditorSprite))
		{
			// Reserved character: hide Duplicate and Delete, center remaining 3 buttons
			buttonMoveUp.y = spriteListButtonY;
			buttonMoveDown.y = spriteListButtonY + 30;
			buttonCreate.y = spriteListButtonY + 60;

			buttonDuplicate.visible = buttonDuplicate.active = false;
			buttonDelete.visible = buttonDelete.active = false;
		}
		else
		{
			// Normal sprite: show all 5 buttons
			buttonMoveUp.y = spriteListButtonY;
			buttonMoveDown.y = spriteListButtonY + 30;
			buttonCreate.y = spriteListButtonY + 60;
			buttonDuplicate.y = spriteListButtonY + 90;
			buttonDelete.y = spriteListButtonY + 120;

			buttonDuplicate.visible = buttonDuplicate.active = true;
			buttonDelete.visible = buttonDelete.active = true;
		}

		buttonMoveUp.visible = buttonMoveUp.active = true;
		buttonMoveDown.visible = buttonMoveDown.active = true;
	}

	function showOutput(txt:String, isError:Bool = false)
	{
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputTxt.text = txt;
		outputTime = 3;

		if (isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
		else FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function findUnoccupiedName(prefix:String = 'sprite', ?isCopy:Bool = false):String
	{
		final reg:String = ~/-copy[0-9]*$/.replace(prefix, '');
		final name:String = (isCopy || (prefix != reg)) ? '$reg-copy' : prefix;

		var num:Int = 1;
		while (true)
		{
			final newName:String = name + num;
			var exists:Bool = false;
			for (spr in stageSprites) {
				if (spr.name == newName) {
					exists = true;
					break;
				}
			}

			if (!exists) return newName;
			num++;
		}

		return name;
	}
	
	function insertMeta(meta:StageEditorSprite, insertOffset:Int = 0)
	{
		var O:Int = spriteListObjectIndexFromRadio();
		if (O < 0) O = allObjects.length;

		var num:Int = Std.int(FlxMath.bound(O + insertOffset, 0, allObjects.length));
		allObjects.insert(num, meta);
		stageSprites.push(meta);
		updateSpriteListRadio();
		createPopup.visible = createPopup.active = false;
		var newLabelIdx:Int = allObjects.length - 1 - num;
		setSpriteListSelectionToLabelIndex(newLabelIdx);
		updateSelectedUI();
		updateSpriteListButtons();
		unsavedProgress = true;
	}

	var createPopup:FlxSpriteGroup;
	function spriteCreatePopup()
	{
		createPopup = new FlxSpriteGroup();
		createPopup.cameras = [camHUD];

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scale.set(300, 240);
		bg.updateHitbox();
		bg.screenCenter();
		createPopup.add(bg);

		var txt:FlxText = new FlxText(0, bg.y + 10, 180, 'New Sprite', 24);
		txt.screenCenter(X);
		txt.alignment = CENTER;
		createPopup.add(txt);

		var btnY = 320;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, 'No Animation');
		btn.onClickReleased = () -> loadImage('sprite');
		btn.screenCenter(X);
		createPopup.add(btn);

		btnY += 50;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Animated');
		btn.onClickReleased = () -> loadImage('animatedSprite');
		btn.screenCenter(X);
		createPopup.add(btn);

		btnY += 50;
		var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Solid Color');
		btn.onClickReleased = () ->
		{
			var meta:StageEditorSprite = new StageEditorSprite({type: 'square', scale: [200, 200], name: findUnoccupiedName()});
			meta.makeGraphic(1, 1, FlxColor.WHITE);
			meta.scale.set(200, 200);
			meta.updateHitbox();
			meta.screenCenter();
			insertMeta(meta);
		};
		btn.screenCenter(X);
		createPopup.add(btn);
		add(createPopup);
		createPopup.visible = createPopup.active = false;
	}

	function updateSpriteListRadio()
	{
		var nameList:Array<String> = [];
		for (spr in allObjects)
		{
			if (spr == null) continue;

			if (Std.isOfType(spr, StageEditorSprite))
			{
				var s:StageEditorSprite = cast spr;
				nameList.push(s.name);
			}
			else if (spr == gf) nameList.push('- Girlfriend -');
			else if (spr == boyfriend) nameList.push('- Boyfriend -');
			else if (spr == dad) nameList.push('- Opponent -');
			else nameList.push('Unknown');
		}
		nameList.reverse();

		spriteListRadioGroup.labels = nameList;

		final maxNum:Int = 19;
		spriteList_box.resize(250, Std.int(Math.min(maxNum, spriteListRadioGroup.labels.length) * 25 + 35));
		spriteListRadioGroup.updateRadioItems();
	}

	function editorUI()
	{
		UI_box = new PsychUIBox(FlxG.width - 225, 10, 200, 400, ['Meta', 'Data', 'Object']);
		UI_box.cameras = [camHUD];
		UI_box.scrollFactor.set();
		add(UI_box);
		UI_box.selectedName = 'Data';

		UI_stagebox = new PsychUIBox(FlxG.width - 275, 25, 250, 100, ['Stage']);
		UI_stagebox.cameras = [camHUD];
		UI_stagebox.scrollFactor.set();
		add(UI_stagebox);
		UI_box.y += UI_stagebox.y + UI_stagebox.height;

		addDataTab();
		addObjectTab();
		addMetaTab();
		addStageTab();
	}

	var directoryDropDown:PsychUIDropDownMenu;
	var uiInputText:PsychUIInputText;
	var hideGirlfriendCheckbox:PsychUICheckBox;
	var zoomStepper:PsychUINumericStepper;
	var cameraSpeedStepper:PsychUINumericStepper;
	var camDadStepperX:PsychUINumericStepper;
	var camDadStepperY:PsychUINumericStepper;
	var camGfStepperX:PsychUINumericStepper;
	var camGfStepperY:PsychUINumericStepper;
	var camBfStepperX:PsychUINumericStepper;
	var camBfStepperY:PsychUINumericStepper;
	function addDataTab()
	{
		var tab_group = UI_box.getTab('Data').menu;

		var objX = 10;
		var objY = 30;
		tab_group.add(new FlxText(objX, objY - 18, 150, 'Compiled Assets:'));

		var folderList:Array<String> = [''];
		#if sys
		for (folder in FileSystem.readDirectory('assets/'))
			if (FileSystem.isDirectory('assets/$folder') && folder != 'shared' && !Mods.ignoreModFolders.contains(folder))
				folderList.push(folder);
		#end

		var saveButton:PsychUIButton = new PsychUIButton(UI_box.width - 90, UI_box.height - 50, 'Save', function()
		{
			saveData();
		});
		tab_group.add(saveButton);

		directoryDropDown = new PsychUIDropDownMenu(objX, objY, folderList, (sel:Int, selected:String) -> {
			stageJson.directory = selected;
			saveObjectsToJson();
			FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new StageEditorState(lastLoadedStage, stageJson));
		});
		directoryDropDown.selectedLabel = stageJson.directory;

		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'UI Style:'));
		uiInputText = new PsychUIInputText(objX, objY, 100, stageJson.stageUI != null ? stageJson.stageUI : '', 8);
		uiInputText.onChange.add((old:String, cur:String) -> stageJson.stageUI = uiInputText.text);

		objY += 30;
		hideGirlfriendCheckbox = new PsychUICheckBox(objX, objY, 'Hide Girlfriend?', 100);
		hideGirlfriendCheckbox.onClick = function()
		{
			stageJson.hide_girlfriend = hideGirlfriendCheckbox.checked;
			gf.visible = !hideGirlfriendCheckbox.checked;
			if (focusRadioGroup.checked > -1)
			{
				var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
				camFollow.setPosition(point.x, point.y);
			}
		};
		hideGirlfriendCheckbox.checked = !gf.visible;

		objY += 50;
		tab_group.add(new FlxText(objX + 50, objY - 18, 100, 'Camera Offsets:'));

		objY += 20;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Opponent:'));

		var cx:Float = 0;
		var cy:Float = 0;
		if (stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
		{
			cx = stageJson.camera_opponent[0];
			cy = stageJson.camera_opponent[0];
		}
		camDadStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camDadStepperX.onValueChange.add((value:Float) ->
		{
			if (stageJson.camera_opponent == null) stageJson.camera_opponent = [0, 0];
			stageJson.camera_opponent[0] = value;

			_updateCamera();
		});

		camDadStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camDadStepperY.onValueChange.add((value:Float) ->
		{
			if (stageJson.camera_opponent == null) stageJson.camera_opponent = [0, 0];
			stageJson.camera_opponent[1] = value;
			
			_updateCamera();
		});

		objY += 40;
		var cx:Float = 0;
		var cy:Float = 0;
		if (stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
		{
			cx = stageJson.camera_girlfriend[0];
			cy = stageJson.camera_girlfriend[0];
		}
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Girlfriend:'));
		camGfStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camGfStepperX.onValueChange.add((value:Float) ->
		{
			if (stageJson.camera_girlfriend == null) stageJson.camera_girlfriend = [0, 0];
			stageJson.camera_girlfriend[0] = value;

			_updateCamera();
		});

		camGfStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camGfStepperY.onValueChange.add((value:Float) ->
		{
			if (stageJson.camera_girlfriend == null) stageJson.camera_girlfriend = [0, 0];
			stageJson.camera_girlfriend[1] = value;
			
			_updateCamera();
		});

		objY += 40;
		var cx:Float = 0;
		var cy:Float = 0;
		if (stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			cx = stageJson.camera_boyfriend[0];
			cy = stageJson.camera_boyfriend[0];
		}
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Boyfriend:'));
		camBfStepperX = new PsychUINumericStepper(objX, objY, 50, cx, -10000, 10000, 0);
		camBfStepperX.onValueChange.add((value:Float) ->
		{
			if (stageJson.camera_boyfriend == null) stageJson.camera_boyfriend = [0, 0];
			stageJson.camera_boyfriend[0] = value;
			
			_updateCamera();
		});

		camBfStepperY = new PsychUINumericStepper(objX + 80, objY, 50, cy, -10000, 10000, 0);
		camBfStepperY.onValueChange.add((value:Float) ->
		{
			if (stageJson.camera_boyfriend == null) stageJson.camera_boyfriend = [0, 0];
			stageJson.camera_boyfriend[1] = value;
			
			_updateCamera();
		});

		objY += 45;
		tab_group.add(new FlxText(objX + 55, objY - 18, 100, 'Camera Data:'));
		objY += 20;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Zoom:'));
		zoomStepper = new PsychUINumericStepper(objX, objY, 0.05, stageJson.defaultZoom, minZoom, maxZoom, 2);
		zoomStepper.onValueChange.add((value:Float) ->
		{
			stageJson.defaultZoom = value;
			FlxG.camera.zoom = stageJson.defaultZoom;
		});

		tab_group.add(new FlxText(objX + 80, objY - 18, 100, 'Speed:'));
		cameraSpeedStepper = new PsychUINumericStepper(objX + 80, objY, 0.1, stageJson.camera_speed != null ? stageJson.camera_speed : 1, 0, 10, 2);
		cameraSpeedStepper.onValueChange.add((value:Float) ->
		{
			stageJson.camera_speed = value;
			FlxG.camera.followLerp = 0.04 * stageJson.camera_speed;
		});
		FlxG.camera.followLerp = 0.04 * cameraSpeedStepper.value;

		tab_group.add(hideGirlfriendCheckbox);
		tab_group.add(camDadStepperX);
		tab_group.add(camDadStepperY);
		tab_group.add(camGfStepperX);
		tab_group.add(camGfStepperY);
		tab_group.add(camBfStepperX);
		tab_group.add(camBfStepperY);
		tab_group.add(zoomStepper);
		tab_group.add(cameraSpeedStepper);

		tab_group.add(uiInputText);
		tab_group.add(directoryDropDown);
	}

	function _updateCamera()
	{
		if (focusRadioGroup.checked > -1)
		{
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
		}
	}

	var colorInputText:PsychUIInputText;
	var nameInputText:PsychUIInputText;
	var imgTxt:FlxText;

	var scaleStepperX:PsychUINumericStepper;
	var scaleStepperY:PsychUINumericStepper;
	var scrollStepperX:PsychUINumericStepper;
	var scrollStepperY:PsychUINumericStepper;
	var angleStepper:PsychUINumericStepper;
	var zoomFactorStepper:PsychUINumericStepper;
	var alphaStepper:PsychUINumericStepper;

	var scaleLockCheckbox:PsychUICheckBox;
	var scrollLockCheckbox:PsychUICheckBox;
	var antialiasingCheckbox:PsychUICheckBox;
	var flipXCheckBox:PsychUICheckBox;
	var flipYCheckBox:PsychUICheckBox;
	var lowQualityCheckbox:PsychUICheckBox;
	var highQualityCheckbox:PsychUICheckBox;

	function getSelected(blockReserved:Bool = true):FunkinSprite
	{
		if (spriteListRadioGroup.checked >= 0)
		{
			var idx:Int = spriteListObjectIndexFromRadio();
			var spr = idx >= 0 ? allObjects[idx] : null;
			if (spr != null)
			{
				// If blockReserved is true, don't return characters
				if (blockReserved && Std.isOfType(spr, Character)) return null;
				return spr;
			}
		}
		return null;
	}

	function addObjectTab()
	{
		var tab_group = UI_box.getTab('Object').menu;

		var objX = 10;
		var objY = 30;
		tab_group.add(new FlxText(objX, objY - 18, 150, 'Name (for Lua/HScript):'));
		nameInputText = new PsychUIInputText(objX, objY, 120, '', 8);
		nameInputText.customFilter = ~/[^a-zA-Z0-9_\-]*/g;
		nameInputText.onChange.add((old:String, cur:String) ->
		{
			// change name
			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				var changedName:String = nameInputText.text;
				if (changedName.length < 1)
				{
					showOutput('Sprite name cannot be empty!', true);
					return;
				}

				if (StageData.reservedNames.contains(changedName))
				{
					showOutput('To avoid conflicts, this name cannot be used!', true);
					return;
				}

				for (basic in stageSprites)
				{
					if (Std.isOfType(basic, StageEditorSprite))
					{
						var basicS:StageEditorSprite = cast basic;
						if (s != basicS && basicS.name == changedName)
						{
							showOutput('Name "$changedName" is already in use!', true);
							return;
						}
					}
				}

				s.name = changedName;
				var keepLabelIdx:Int = spriteListGlobalLabelIndex();
				updateSpriteListRadio();
				if (keepLabelIdx >= 0) setSpriteListSelectionToLabelIndex(keepLabelIdx);
				outputTime = 0;
				outputTxt.alpha = 0;
			}
		});
		tab_group.add(nameInputText);

		objY += 35;
		imgTxt = new FlxText(objX, objY - 15, 200, 'Image: ', 8);
		var imgButton:PsychUIButton = new PsychUIButton(objX, objY, 'Change Image', function()
		{
			trace('attempt to load image');
			loadImage();
		});
		tab_group.add(imgButton);
		tab_group.add(imgTxt);

		var animationsButton:PsychUIButton = new PsychUIButton(objX + 90, objY, 'Animations', function()
		{
			var selected = getSelected();
			if (selected == null)
				return;

			if (!Std.isOfType(selected, StageEditorSprite))
			{
				showOutput('Only Stage Sprites can hold Animation data.', true);
				return;
			}
			var s:StageEditorSprite = cast selected;

			if (s.type != 'animatedSprite')
			{
				showOutput('Only Animated Sprites can hold Animation data.', true);
				return;
			}

			unsavedProgress = true;
			openSubState(new StageEditorAnimationSubstate(s));
		});
		tab_group.add(animationsButton);

		objY += 50;
		tab_group.add(new FlxText(objX, objY - 18, 80, 'Color:'));
		colorInputText = new PsychUIInputText(objX, objY, 80, 'FFFFFF', 8);
		colorInputText.inputText.filterMode = ALPHANUMERIC;
		colorInputText.onChange.add((old:String, cur:String) ->
		{
			// change color
			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				s.imageColor = colorInputText.text;
			}
		});
		tab_group.add(colorInputText);

		function updateScale(?changedX:Null<Bool>)
		{
			if (changedX != null && scaleLockCheckbox.checked)
			{
				if (changedX) scaleStepperY.value = scaleStepperX.value;
				else scaleStepperX.value = scaleStepperY.value;
			}

			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				s.scale.x = scaleStepperX.value;
				s.scale.y = scaleStepperY.value;
				s.updateHitbox();
			}
		}

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 100, 'Scale (X/Y):'));
		scaleStepperX = new PsychUINumericStepper(objX, objY, 0.05, 1, 0.05, 10, 2, 58);
		scaleStepperX.onValueChange.add((_) -> updateScale(true));
		scaleStepperY = new PsychUINumericStepper(objX + 67, objY, 0.05, 1, 0.05, 10, 2, 58);
		scaleStepperY.onValueChange.add((_) -> updateScale(true));
		scaleLockCheckbox = new PsychUICheckBox(objX + 135, objY, 'Lock', 50);
		scaleLockCheckbox.onClick = () ->
		{
			if (scaleLockCheckbox.checked)
			{
				scaleStepperY.value = scaleStepperX.value;
				updateScale();
			}
		};
		tab_group.add(scaleStepperX);
		tab_group.add(scaleStepperY);
		tab_group.add(scaleLockCheckbox);

		function updateScroll(?changedX:Null<Bool>)
		{
			if (changedX != null && scrollLockCheckbox.checked)
			{
				if (changedX) scrollStepperY.value = scrollStepperX.value;
				else scrollStepperX.value = scrollStepperY.value;
			}

			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				s.scrollFactor.x = scrollStepperX.value;
				s.scrollFactor.y = scrollStepperY.value;
			}
		}

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 150, 'Scroll Factor (X/Y):'));
		scrollStepperX = new PsychUINumericStepper(objX, objY, 0.05, 1, 0, 10, 2, 58);
		scrollStepperX.onValueChange.add((_) -> updateScroll(true));
		scrollStepperY = new PsychUINumericStepper(objX + 67, objY, 0.05, 1, 0, 10, 2, 58);
		scrollStepperY.onValueChange.add((_) -> updateScroll(false));
		scrollLockCheckbox = new PsychUICheckBox(objX + 135, objY, 'Lock', 50);
		scrollLockCheckbox.onClick = () ->
		{
			if (scrollLockCheckbox.checked)
			{
				scrollStepperY.value = scrollStepperX.value;
				updateScroll();
			}
		};
		tab_group.add(scrollStepperX);
		tab_group.add(scrollStepperY);
		tab_group.add(scrollLockCheckbox);

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 80, 'Opacity:'));
		alphaStepper = new PsychUINumericStepper(objX, objY, 0.1, 1, 0, 1, 2, true);
		alphaStepper.onValueChange.add((value:Float) ->
		{
			// alpha/opacity
			var selected = getSelected();
			if (selected != null) selected.alpha = value;
		});
		tab_group.add(alphaStepper);

		antialiasingCheckbox = new PsychUICheckBox(objX + 90, objY - 7, 'Anti-Aliasing', 80);
		antialiasingCheckbox.onClick = function()
		{
			// antialiasing
			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				if (s.type != 'square') s.antialiasing = antialiasingCheckbox.checked;
				else
				{
					antialiasingCheckbox.checked = false;
					s.antialiasing = false;
				}
			}
		};
		tab_group.add(antialiasingCheckbox);

		objY += 40;
		tab_group.add(new FlxText(objX, objY - 18, 80, 'Angle:'));
		angleStepper = new PsychUINumericStepper(objX, objY, 10, 0, -360, 360, 0);
		angleStepper.onValueChange.add((value:Float) ->
		{
			// alpha/opacity
			var selected = getSelected();
			if (selected != null) selected.angle = value;
		});
		tab_group.add(angleStepper);

		tab_group.add(new FlxText(objX + 80, objY - 18, 80, 'Zoom Factor:'));
		zoomFactorStepper = new PsychUINumericStepper(objX + 80, objY, 0.05, 1, 0, 10, 2);
		zoomFactorStepper.onValueChange.add((value:Float) ->
		{
			// zoom factor
			var selected = getSelected();
			if (selected != null) selected.zoomFactor = value;
		});
		tab_group.add(zoomFactorStepper);

		function updateFlip()
		{
			// flip X and flip Y
			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				if (s.type != 'square')
				{
					s.flipX = flipXCheckBox.checked;
					s.flipY = flipYCheckBox.checked;
				}
				else
				{
					flipXCheckBox.checked = flipYCheckBox.checked = false;
					s.flipX = s.flipY = false;
				}
			}
		}

		objY += 25;
		flipXCheckBox = new PsychUICheckBox(objX, objY, 'Flip X', 60);
		flipXCheckBox.onClick = updateFlip;
		flipYCheckBox = new PsychUICheckBox(objX + 90, objY, 'Flip Y', 60);
		flipYCheckBox.onClick = updateFlip;
		tab_group.add(flipXCheckBox);
		tab_group.add(flipYCheckBox);

		objY += 45;
		function recalcFilter()
		{
			// low and/or high quality
			var selected = getSelected();
			if (selected != null && Std.isOfType(selected, StageEditorSprite))
			{
				var s:StageEditorSprite = cast selected;
				var filt = 0;
				if (lowQualityCheckbox.checked) filt |= LOW_QUALITY;
				if (highQualityCheckbox.checked) filt |= HIGH_QUALITY;
				s.viewFilters = filt;
			}
		};
		tab_group.add(new FlxText(objX + 60, objY - 18, 100, 'Visible in:'));
		lowQualityCheckbox = new PsychUICheckBox(objX, objY, 'Low Quality', 70);
		highQualityCheckbox = new PsychUICheckBox(objX + 90, objY, 'High Quality', 70);
		lowQualityCheckbox.onClick = recalcFilter;
		highQualityCheckbox.onClick = recalcFilter;
		tab_group.add(lowQualityCheckbox);
		tab_group.add(highQualityCheckbox);
	}

	var oppDropdown:PsychUIDropDownMenu;
	var gfDropdown:PsychUIDropDownMenu;
	var plDropdown:PsychUIDropDownMenu;
	function addMetaTab()
	{
		var tab_group = UI_box.getTab('Meta').menu;

		var characterList = Mods.mergeAllTextsNamed('data/characterList.txt');
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'characters/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if (file.toLowerCase().endsWith('.json'))
				{
					var charToCheck:String = file.substr(0, file.length - 5);
					if (!characterList.contains(charToCheck))
						characterList.push(charToCheck);
				}

		if (characterList.length < 1) characterList.push(''); // Prevents crash

		var objX = 10;
		var objY = 20;

		function setMetaData(data:String, char:String)
		{
			if (stageJson._editorMeta == null) stageJson._editorMeta = {dad: 'dad', gf: 'gf', boyfriend: 'bf'};
			Reflect.setField(stageJson._editorMeta, data, char);
		}

		var openPreloadButton:PsychUIButton = new PsychUIButton(objX, objY, 'Preload List', function()
		{
			var lockedList:Array<String> = [];
			var currentMap:Map<String, LoadFilters> = [];
			for (spr in stageSprites)
			{
				if (spr == null || !Std.isOfType(spr, StageEditorSprite)) continue;

				switch (spr.type)
				{
					case 'sprite', 'animatedSprite':
						if (spr.image != null && spr.image.length > 0 && !lockedList.contains(spr.image))
							lockedList.push(spr.image);
				}
			}

			if (stageJson.preload != null)
			{
				for (field in Reflect.fields(stageJson.preload))
				{
					if (!currentMap.exists(field) && !lockedList.contains(field))
						currentMap.set(field, Reflect.field(stageJson.preload, field));
				}
			}

			openSubState(new PreloadListSubState(function(newSave:Map<String, LoadFilters>)
			{
				var len:Int = 0;
				for (name in newSave.keys()) len++;

				stageJson.preload = {};
				for (key => value in newSave) Reflect.setField(stageJson.preload, key, value);

				unsavedProgress = true;
				showOutput('Saved new Preload List with $len files/folders!');
			}, lockedList, currentMap));
		});

		objY += 60;
		oppDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if (selected == null || selected.length < 1) return;
			dad.changeCharacter(selected);
			setMetaData('dad', selected);
			repositionDad();
		});
		oppDropdown.selectedLabel = dad.curCharacter;

		objY += 60;
		gfDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if (selected == null || selected.length < 1) return;
			gf.changeCharacter(selected);
			setMetaData('gf', selected);
			repositionGirlfriend();
		});
		gfDropdown.selectedLabel = gf.curCharacter;

		objY += 60;
		plDropdown = new PsychUIDropDownMenu(objX, objY, characterList, function(sel:Int, selected:String)
		{
			if (selected == null || selected.length < 1) return;
			boyfriend.changeCharacter(selected);
			setMetaData('boyfriend', selected);
			repositionBoyfriend();
		});
		plDropdown.selectedLabel = boyfriend.curCharacter;

		tab_group.add(openPreloadButton);
		tab_group.add(new FlxText(plDropdown.x, plDropdown.y - 18, 100, 'Player:'));
		tab_group.add(plDropdown);
		tab_group.add(new FlxText(gfDropdown.x, gfDropdown.y - 18, 100, 'Girlfriend:'));
		tab_group.add(gfDropdown);
		tab_group.add(new FlxText(oppDropdown.x, oppDropdown.y - 18, 100, 'Opponent:'));
		tab_group.add(oppDropdown);
	}

	var stageDropDown:PsychUIDropDownMenu;
	function addStageTab()
	{
		var tab_group = UI_stagebox.getTab('Stage').menu;
		var reloadStage:PsychUIButton = new PsychUIButton(140, 10, 'Reload', function()
		{
			rpcState = 'Stage: $lastLoadedStage';
			updatePresence();

			stageJson = StageData.getStageFile(lastLoadedStage);
			loadJsonAssetDirectory();
			updateSpriteList();
			updateStageDataUI();
			reloadCharacters();
			reloadStageDropDown();
		});

		var dummyStage:PsychUIButton = new PsychUIButton(140, 40, 'Load Template', function()
		{
			rpcState = 'Stage: New Stage';
			updatePresence();

			stageJson = StageData.dummy();
			loadJsonAssetDirectory();
			updateSpriteList();
			updateStageDataUI();
			reloadCharacters();
		});
		dummyStage.normalStyle.bgColor = FlxColor.RED;
		dummyStage.normalStyle.textColor = FlxColor.WHITE;

		stageDropDown = new PsychUIDropDownMenu(10, 30, [''], function(sel:Int, selected:String)
		{
			var characterPath:String = 'stages/$selected.json';
			var path:String = Paths.getPath(characterPath, null, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
			#else
			if (Assets.exists(path))
			#end
			{
				stageJson = StageData.getStageFile(selected);
				lastLoadedStage = selected;
				updatePresence();

				loadJsonAssetDirectory();
				updateSpriteList();
				updateStageDataUI();
				reloadCharacters();
				reloadStageDropDown();
			}
			else
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadStageDropDown();
			}
		});
		reloadStageDropDown();

		tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 18, 60, 'Stage:'));
		tab_group.add(reloadStage);
		tab_group.add(dummyStage);
		tab_group.add(stageDropDown);
	}

	function updateStageDataUI()
	{
		// input texts
		uiInputText.text = (stageJson.stageUI != null ? stageJson.stageUI : '');
		// checkboxes
		hideGirlfriendCheckbox.checked = (stageJson.hide_girlfriend);
		gf.visible = !hideGirlfriendCheckbox.checked;
		// steppers
		zoomStepper.value = FlxG.camera.zoom = stageJson.defaultZoom;

		if (stageJson.camera_speed != null)
			cameraSpeedStepper.value = stageJson.camera_speed;
		else
			cameraSpeedStepper.value = 1;
		FlxG.camera.followLerp = 0.04 * cameraSpeedStepper.value;

		if (stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
		{
			camDadStepperX.value = stageJson.camera_opponent[0];
			camDadStepperY.value = stageJson.camera_opponent[1];
		}
		else
			camDadStepperX.value = camDadStepperY.value = 0;

		if (stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
		{
			camGfStepperX.value = stageJson.camera_girlfriend[0];
			camGfStepperY.value = stageJson.camera_girlfriend[1];
		}
		else
			camGfStepperX.value = camGfStepperY.value = 0;

		if (stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
		{
			camBfStepperX.value = stageJson.camera_boyfriend[0];
			camBfStepperY.value = stageJson.camera_boyfriend[1];
		}
		else
			camBfStepperX.value = camBfStepperY.value = 0;

		if (focusRadioGroup.checked > -1)
		{
			var point = focusOnTarget(focusRadioGroup.labels[focusRadioGroup.checked]);
			camFollow.setPosition(point.x, point.y);
		}
		loadJsonAssetDirectory();
	}

	var displayX:Null<Float> = null;
	var displayY:Null<Float> = null;
	function updateSelectedUI()
	{
		var selected = getSelected(false);
		if (selected == null)
			return;

		displayX = Math.round(selected.x);
		displayY = Math.round(selected.y);

		if (Std.isOfType(selected, Character))
		{
			var char:Character = cast selected;
			displayX -= char.positionArray[0];
			displayY -= char.positionArray[1];

			if (nameInputText != null) nameInputText.text = '';
			if (colorInputText != null) colorInputText.text = 'FFFFFF';
			if (imgTxt != null) imgTxt.text = 'Image: Character';

			return;
		}

		if (!Std.isOfType(selected, StageEditorSprite)) return;
		var s:StageEditorSprite = cast selected;

		// Texts/Input Texts
		colorInputText.text = s.imageColor;
		nameInputText.text = s.name;
		imgTxt.text = 'Image: ' + s.image;

		// Steppers
		if (s.type != 'square')
		{
			scaleStepperX.decimals = scaleStepperY.decimals = 2;
			scaleStepperX.max = scaleStepperY.max = 10;
			scaleStepperX.min = scaleStepperY.min = 0.05;
			scaleStepperX.step = scaleStepperY.step = 0.05;
		}
		else
		{
			scaleStepperX.decimals = scaleStepperY.decimals = 0;
			scaleStepperX.max = scaleStepperY.max = 10000;
			scaleStepperX.min = scaleStepperY.min = 50;
			scaleStepperX.step = scaleStepperY.step = 50;
		}
		scaleStepperX.value = s.scale.x;
		scaleStepperY.value = s.scale.y;
		scrollStepperX.value = s.scrollFactor.x;
		scrollStepperY.value = s.scrollFactor.y;
		zoomFactorStepper.value = s.zoomFactor;
		angleStepper.value = s.angle;
		alphaStepper.value = s.alpha;

		// Checkboxes
		antialiasingCheckbox.checked = s.antialiasing;
		flipXCheckBox.checked = s.flipX;
		flipYCheckBox.checked = s.flipY;
		lowQualityCheckbox.checked = (s.viewFilters & LOW_QUALITY) == LOW_QUALITY;
		highQualityCheckbox.checked = (s.viewFilters & HIGH_QUALITY) == HIGH_QUALITY;
	}

	function reloadCharacters()
	{
		if (stageJson._editorMeta != null)
		{
			gf.changeCharacter(stageJson._editorMeta.gf);
			dad.changeCharacter(stageJson._editorMeta.dad);
			boyfriend.changeCharacter(stageJson._editorMeta.boyfriend);
		}

		repositionGirlfriend();
		repositionDad();
		repositionBoyfriend();

		focusRadioGroup.checked = -1;
		FlxG.camera.target = null;
		var point = focusOnTarget('boyfriend');
		FlxG.camera.scroll.set(point.x - FlxG.width * 0.5, point.y - FlxG.height * 0.5);
		FlxG.camera.zoom = stageJson.defaultZoom;
		oppDropdown.selectedLabel = dad.curCharacter;
		gfDropdown.selectedLabel = gf.curCharacter;
		plDropdown.selectedLabel = boyfriend.curCharacter;
	}

	function reloadStageDropDown()
	{
		var stageList:Array<String> = [];
		var foldersToCheck:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'stages/');
		for (folder in foldersToCheck)
			for (file in FileSystem.readDirectory(folder))
				if (file.toLowerCase().endsWith('.json'))
				{
					var stageToCheck:String = file.substr(0, file.length - '.json'.length);
					if (!stageList.contains(stageToCheck)) stageList.push(stageToCheck);
				}

		if (stageList.length < 1) stageList.push('');

		if (stageDropDown != null) {
			stageDropDown.list = stageList;
			stageDropDown.selectedLabel = lastLoadedStage;
		}

		if (directoryDropDown != null) directoryDropDown.selectedLabel = stageJson.directory;
	}

	function checkUIOnObject()
	{
		if (UI_box.selectedName == 'Object')
		{
			if (spriteListRadioGroup.checked >= 0)
			{
				var idx:Int = spriteListObjectIndexFromRadio();
				var spr = idx >= 0 ? allObjects[idx] : null;
				if (spr != null && Std.isOfType(spr, Character)) UI_box.selectedName = 'Data';
			}
			else UI_box.selectedName = 'Data';
		}
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		switch (id)
		{
			case PsychUIRadioGroup.CLICK_EVENT, PsychUIBox.CLICK_EVENT:
				if (sender == spriteListRadioGroup || sender == UI_box) checkUIOnObject();
			case PsychUICheckBox.CLICK_EVENT:
				unsavedProgress = true;
			case PsychUIInputText.CHANGE_EVENT, PsychUINumericStepper.CHANGE_EVENT:
				unsavedProgress = true;
		}
	}

	var showUI:Bool = true;
	function toggleUI(?show:Bool = false)
	{
		UI_box.visible = show;
		UI_box.active = show;

		var objs = [UI_stagebox, spriteListRadioGroup, spriteList_box];
		for (obj in objs)
		{
			obj.visible = show;
			if (!(obj is FlxText))
				obj.active = show;
		}

		spriteListRadioGroup.updateRadioItems();
	}

	var outputTime:Float = 0;
	var timeSinceLastClick:Float = 1.0;
	override function update(elapsed:Float)
	{
		if (createPopup.visible && (FlxG.mouse.justPressedRight || (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(createPopup, camHUD))))
			createPopup.visible = createPopup.active = false;
		
		super.update(elapsed);

		for (spr in allObjects)
		{
			if (curFilters == 0) continue;

			if (Std.isOfType(spr, StageEditorSprite))
			{
				var s:StageEditorSprite = cast spr;
				if ((s.viewFilters & curFilters) == 0) continue;
			}
			
			spr.update(elapsed);
		}

		if (outputTime > 0)
		{
			outputTime -= elapsed;
			if (outputTime <= 0)
			{
				outputTxt.alpha = 0;
				outputTime = 0;
			}
			else if (outputTime < 0.5) outputTxt.alpha = outputTime * 2;
			else outputTxt.alpha = 1;
		}

		if (PsychUIInputText.focusOn != null) return;

		if (controls.BACK)
		{
			if (!unsavedProgress)
			{
				MusicBeatState.switchState(new states.MainMenuState(true));
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}
			else openSubState(new ExitConfirmationPrompt());

			return;
		}

		if (FlxG.keys.justPressed.W)
		{
			if (spriteListRadioGroup.labels.length > 0)
			{
				var L:Int = Std.int(Math.max(0, spriteListGlobalLabelIndex()));
				L = FlxMath.wrap(L - 1, 0, spriteListRadioGroup.labels.length - 1);
				setSpriteListSelectionToLabelIndex(L);
			}
			checkUIOnObject();
			updateSelectedUI();
			updateSpriteListButtons();
		}
		else if (FlxG.keys.justPressed.S)
		{
			if (spriteListRadioGroup.labels.length > 0)
			{
				var L:Int = Std.int(Math.max(0, spriteListGlobalLabelIndex()));
				L = FlxMath.wrap(L + 1, 0, spriteListRadioGroup.labels.length - 1);
				setSpriteListSelectionToLabelIndex(L);
			}
			checkUIOnObject();
			updateSelectedUI();
			updateSpriteListButtons();
		}

		if (FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
		{
			helpBg.visible = !helpBg.visible;
			helpTexts.visible = helpBg.visible;
		}

		#if FLX_DEBUG
		if (FlxG.keys.justPressed.F3 && !FlxG.mouse.pressedRight)
		#else
		if (FlxG.keys.justPressed.F2 && !FlxG.mouse.pressedRight)
		#end
		{
			showUI = !showUI;
			toggleUI(showUI);
		}

		if (FlxG.keys.justPressed.F12)
			showSelectionQuad = !showSelectionQuad;

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		if (FlxG.keys.pressed.SHIFT) shiftMult = 4;
		if (FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// CAMERA CONTROLS
		var camX:Float = 0;
		var camY:Float = 0;
		var camMove:Float = elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.J) camX -= camMove;
		if (FlxG.keys.pressed.K) camY += camMove;
		if (FlxG.keys.pressed.L) camX += camMove;
		if (FlxG.keys.pressed.I) camY -= camMove;

		if (camX != 0 || camY != 0)
		{
			FlxG.camera.scroll.x += camX;
			FlxG.camera.scroll.y += camY;
			if (FlxG.camera.target != null) FlxG.camera.target = null;
			if (focusRadioGroup.checked > -1) focusRadioGroup.checked = -1;
		}

		if (FlxG.mouse.pressedMiddle)
		{
			FlxG.camera.scroll.x -= FlxG.mouse.deltaViewX * shiftMult * ctrlMult;
			FlxG.camera.scroll.y -= FlxG.mouse.deltaViewY * shiftMult * ctrlMult;

			if (FlxG.camera.target != null) FlxG.camera.target = null;
			if (focusRadioGroup.checked > -1) focusRadioGroup.checked = -1;
		}

		if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL)
		{
			FlxG.camera.zoom = stageJson.defaultZoom;
			zoomStepper.value = FlxG.camera.zoom;
		}
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < maxZoom) FlxG.camera.zoom = Math.min(maxZoom, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > minZoom) FlxG.camera.zoom = Math.max(minZoom, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);

		if (FlxG.mouse.wheel != 0 && !FlxG.mouse.pressedMiddle && (!spriteList_box.active || !FlxG.mouse.overlaps(spriteList_box, camHUD)))
		{
			FlxG.camera.zoom += (FlxG.mouse.wheel * 0.1) * FlxG.camera.zoom * shiftMult * ctrlMult;
			FlxG.camera.zoom = Math.max(minZoom, Math.min(maxZoom, FlxG.camera.zoom));
		}

		// SPRITE X/Y
		shiftMult = 1;
		ctrlMult = 1;
		if (FlxG.keys.pressed.SHIFT) shiftMult = 4;
		if (FlxG.keys.pressed.CONTROL) ctrlMult = 0.2;

		var moveX:Float = 0;
		var moveY:Float = 0;
		if (FlxG.keys.justPressed.LEFT) moveX -= 5 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.RIGHT) moveX += 5 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.UP) moveY -= 5 * shiftMult * ctrlMult;
		if (FlxG.keys.justPressed.DOWN) moveY += 5 * shiftMult * ctrlMult;

		if (FlxG.mouse.pressedRight && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
		{
			moveX += FlxG.mouse.deltaViewX * ctrlMult;
			moveY += FlxG.mouse.deltaViewY * ctrlMult;
			_updateCamera();
		}

		if (moveX != 0 || moveY != 0)
		{
			if (spriteListRadioGroup.checked < 0) return;

			if (FlxG.mouse.pressedRight) toggleUI(false);

			var moveIdx:Int = spriteListObjectIndexFromRadio();
			var spr = moveIdx >= 0 ? allObjects[moveIdx] : null;
			if (spr != null)
			{
				spr.x = displayX = Math.round(spr.x + moveX);
				spr.y = displayY = Math.round(spr.y + moveY);

				if (Std.isOfType(spr, Character))
				{
					var char:Character = cast spr;
					if (spr == boyfriend)
					{
						stageJson.boyfriend[0] = displayX = spr.x - char.positionArray[0];
						stageJson.boyfriend[1] = displayY = spr.y - char.positionArray[1];
					}
					else if (spr == gf)
					{
						stageJson.girlfriend[0] = displayX = spr.x - char.positionArray[0];
						stageJson.girlfriend[1] = displayY = spr.y - char.positionArray[1];
					}
					else if (spr == dad)
					{
						stageJson.opponent[0] = displayX = spr.x - char.positionArray[0];
						stageJson.opponent[1] = displayY = spr.y - char.positionArray[1];
					}
				}
			}
		}
		else if (showUI && FlxG.mouse.justReleasedRight) toggleUI(true);

		timeSinceLastClick += elapsed;

		// Check if mouse is over any UI element before allowing sprite selection
		var mouseOverUI:Bool = FlxG.mouse.overlaps(spriteList_box, camHUD)
			|| FlxG.mouse.overlaps(UI_box, camHUD)
			|| FlxG.mouse.overlaps(UI_stagebox, camHUD)
			|| FlxG.mouse.overlaps(buttonMoveUp, camHUD)
			|| FlxG.mouse.overlaps(buttonMoveDown, camHUD)
			|| FlxG.mouse.overlaps(buttonCreate, camHUD)
			|| FlxG.mouse.overlaps(buttonDuplicate, camHUD)
			|| FlxG.mouse.overlaps(buttonDelete, camHUD)
			|| (createPopup.active && FlxG.mouse.overlaps(createPopup, camHUD));

		if (FlxG.mouse.justPressed && !mouseOverUI)
		{
			var prevIdx:Int = spriteListObjectIndexFromRadio();
			var prevSelected:FunkinSprite = (spriteListRadioGroup.checked >= 0 && prevIdx >= 0) ? allObjects[prevIdx] : null;

			var mousePos = FlxG.mouse.getWorldPosition(camGame);
			var overlappingSprites:Array<FunkinSprite> = getOverlapsSprites(mousePos);

			var isRapidClick:Bool = (timeSinceLastClick < 0.3);

			var currentSelectionIndex:Int = 0;
			if (overlappingSprites.length > 0)
			{
				if (isRapidClick)
				{
					final pidx = overlappingSprites.indexOf(prevSelected);
					if (pidx >= 0) currentSelectionIndex = (pidx + 1) % overlappingSprites.length;
					else currentSelectionIndex = 0;
				}
				else currentSelectionIndex = 0;

				final newSel = overlappingSprites[currentSelectionIndex];
				final idx = allObjects.indexOf(newSel);
				if (idx >= 0)
				{
					var labelIdx:Int = spriteListRadioGroup.labels.length - 1 - idx;
					setSpriteListSelectionToLabelIndex(labelIdx);
					checkUIOnObject();
					updateSelectedUI();
					updateSpriteListButtons();
				}
			}

			timeSinceLastClick = 0;
		}

		posTxt.text = 'Camera Zoom: ' + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + 'x\nX: ' + (displayX != null ? Std.string(displayX) : 'NONE') + '\nY: '
			+ (displayY != null ? Std.string(displayY) : 'NONE');
	}

	var curFilters:LoadFilters = (LOW_QUALITY) | (HIGH_QUALITY);

	override function draw()
	{
		if (persistentDraw || subState == null)
		{
			for (basic in allObjects)
			{
				if (basic.visible)
				{
					if (curFilters == 0)
						continue;

					if (Std.isOfType(basic, StageEditorSprite))
					{
						var s:StageEditorSprite = cast basic;
						if ((s.viewFilters & curFilters) == 0)
							continue;
					}

					basic.draw();
				}
			}

			if (showSelectionQuad && spriteListRadioGroup.checkedRadio != null)
			{
				var dbgIdx:Int = spriteListObjectIndexFromRadio();
				var spr = dbgIdx >= 0 ? allObjects[dbgIdx] : null;
				if (spr != null) drawDebugOnCamera(spr);
			}
		}

		super.draw();
	}

	function focusOnTarget(target:String)
	{
		var focusPoint:FlxPoint = FlxPoint.weak(0, 0);
		switch (target)
		{
			case 'boyfriend':
				focusPoint.x += boyfriend.getMidpoint().x - boyfriend.cameraPosition[0] - 100;
				focusPoint.y += boyfriend.getMidpoint().y + boyfriend.cameraPosition[1] - 100;
				if (stageJson.camera_boyfriend != null && stageJson.camera_boyfriend.length > 1)
				{
					focusPoint.x += stageJson.camera_boyfriend[0];
					focusPoint.y += stageJson.camera_boyfriend[1];
				}
			case 'dad':
				focusPoint.x += dad.getMidpoint().x + dad.cameraPosition[0] + 100;
				focusPoint.y += dad.getMidpoint().y + dad.cameraPosition[1] - 100;
				if (stageJson.camera_opponent != null && stageJson.camera_opponent.length > 1)
				{
					focusPoint.x += stageJson.camera_opponent[0];
					focusPoint.y += stageJson.camera_opponent[1];
				}
			case 'gf':
				if (gf.visible)
				{
					focusPoint.x += gf.getMidpoint().x + gf.cameraPosition[0];
					focusPoint.y += gf.getMidpoint().y + gf.cameraPosition[1];
				}

				if (stageJson.camera_girlfriend != null && stageJson.camera_girlfriend.length > 1)
				{
					focusPoint.x += stageJson.camera_girlfriend[0];
					focusPoint.y += stageJson.camera_girlfriend[1];
				}
		}
		return focusPoint;
	}

	function repositionGirlfriend()
	{
		gf.setPosition(stageJson.girlfriend[0], stageJson.girlfriend[1]);
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
	}
	function repositionDad()
	{
		dad.setPosition(stageJson.opponent[0], stageJson.opponent[1]);
		dad.x += dad.positionArray[0];
		dad.y += dad.positionArray[1];
	}
	function repositionBoyfriend()
	{
		boyfriend.setPosition(stageJson.boyfriend[0], stageJson.boyfriend[1]);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
	}

	var _bounds:FlxRect = new FlxRect();
	public function drawDebugOnCamera(spr:Dynamic)
	{
		if (spr == null || !spr.isOnScreen(camera)) return;
	
		spr.getScreenBounds(_bounds, camera);
	
		var lineSize:Float = 3 / Math.abs(camera.zoom);
		if (lineSize > 500) lineSize = 500;
	
		for (num => sel in selectionSprites.members)
		{
			sel.x = _bounds.x + camera.scroll.x;
			sel.y = _bounds.y + camera.scroll.y;
	
			switch (num)
			{
				case 0: // Top
					sel.x -= lineSize;
					sel.y -= lineSize;
					sel.setGraphicSize(_bounds.width + lineSize * 2, lineSize);
				case 1: // Bottom
					sel.x -= lineSize;
					sel.y += _bounds.height;
					sel.setGraphicSize(_bounds.width + lineSize * 2, lineSize);
				case 2: // Left
					sel.x -= lineSize;
					sel.setGraphicSize(lineSize, _bounds.height);
				case 3: // Right
					sel.x += _bounds.width;
					sel.setGraphicSize(lineSize, _bounds.height);
			}
	
			sel.updateHitbox();
		}
	
		selectionSprites.draw();
	}

	function getOverlapsSprites(mousePos:FlxPoint):Array<FunkinSprite>
	{
		var found:Array<FunkinSprite> = [];

		for (i in 0...allObjects.length)
		{
			var spr:FunkinSprite = cast allObjects[allObjects.length - i - 1];
			if (spr == null || (!spr.visible || spr.alpha == 0)) continue;

			// Respeta filtros si es StageEditorSprite
			if (Std.isOfType(spr, StageEditorSprite))
			{
				var s:StageEditorSprite = cast spr;
				if ((s.viewFilters & curFilters) == 0) continue;
			}

			// Use overlapsPoint for robust checking (automatically handles scale, offset, etc.)
			if (spr.overlapsPoint(mousePos, true)) found.push(spr);
		}

		return found;
	}

	// save

	function saveObjectsToJson()
	{
		stageJson.objects = [];
		for (basic in allObjects)
		{
			if (Std.isOfType(basic, StageEditorSprite))
			{
				var s:StageEditorSprite = cast basic;
				stageJson.objects.push(s.formatToJson());
			}
			else if (basic == gf)
				stageJson.objects.push({type: 'gf'});
			else if (basic == dad)
				stageJson.objects.push({type: 'dad'});
			else if (basic == boyfriend)
				stageJson.objects.push({type: 'boyfriend'});
		}
	}

	function saveData()
	{
		if (_file != null) return;

		saveObjectsToJson();
		var data = haxe.Json.stringify(stageJson, '\t');
		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, '$lastLoadedStage.json');
		}
	}

	var _file:FileReference;

	function onSaveComplete(_):Void
	{
		if (_file == null) return;

		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		FlxG.log.notice('Successfully saved file.');
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		if (_file == null) return;

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
		if (_file == null) return;

		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;

		FlxG.log.error('Problem saving file');
	}

	var _makeNewSprite = null;

	public function loadImage(onNewSprite:String = null)
	{
		if (_file != null) return;

		_makeNewSprite = onNewSprite;
		_file = new FileReference();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		final filters = [
			new FileFilter('PNG (Image)', '*.png'),
			new FileFilter('XML (Sparrow)', '*.xml'),
			new FileFilter('JSON (Aseprite)', '*.json'),
			new FileFilter('TXT (Packer)', '*.txt')
		];
		_file.browse(#if !mac filters #else [] #end);
	}

	private function onLoadComplete(_):Void
	{
		if (_file == null) return;

		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if (_file.__path != null) fullPath = _file.__path;

		function getImageName(path:String):String
		{
			var relPath = path.substring(path.indexOf('/images/') + '/images/'.length);
			var folder = relPath.substring(0, relPath.lastIndexOf('/'));
			var fileName = relPath.substring(0, relPath.lastIndexOf('.'));

			trace('$relPath, $folder, $fileName');
		
			if (Paths.fileExists('images/$folder/Animation.json')) return folder;
			return fileName;
		}

		function loadSprite(imageToLoad:String)
		{
			var selected;
			if (_makeNewSprite != null)
			{
				if (_makeNewSprite == 'animatedSprite'
					&& !Paths.fileExists('images/$imageToLoad.xml')
					&& !Paths.fileExists('images/$imageToLoad.json')
					&& !Paths.fileExists('images/$imageToLoad.txt'))
				{
					showOutput('No Animation file found with the same name of the image!', true);
					_makeNewSprite = null;
					_file = null;
					return;
				}
				var data:Dynamic = {type: _makeNewSprite, name: findUnoccupiedName(), image: imageToLoad};
				var meta:StageEditorSprite = new StageEditorSprite(data);
				insertMeta(meta);
				selected = getSelected();
			}
			else
			{
				selected = getSelected();
				tryLoadImage(selected, imageToLoad);
			}

			if (_makeNewSprite != null)
			{
				selected.x = Math.round(FlxG.camera.scroll.x + FlxG.width / 2 - selected.width / 2);
				selected.y = Math.round(FlxG.camera.scroll.y + FlxG.height / 2 - selected.height / 2);
			}
			_makeNewSprite = null;
		}
		_file = null;

		if (fullPath != null)
		{
			fullPath = fullPath.replace('\\', '/');
			var exePath = Sys.getCwd().replace('\\', '/');
			if (fullPath.startsWith(exePath))
			{
				fullPath = fullPath.substr(exePath.length);
				if ((fullPath.startsWith('assets/') #if MODS_ALLOWED || fullPath.startsWith('mods/') #end)
					&& fullPath.contains('/images/'))
				{
					loadSprite(getImageName(fullPath));
					return;
				}
			}

			createPopup.visible = createPopup.active = false;
			#if MODS_ALLOWED
			var modFolder:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Paths.mods('${Mods.currentModDirectory}/images/') : Paths.mods('images/');
			openSubState(new BasePrompt(480, 160, 'This file is not inside Psych Engine.', function(state:BasePrompt)
			{
				var txt:FlxText = new FlxText(0, state.bg.y + 60, 460, 'Copy to: "$modFolder"?', 11);
				txt.alignment = CENTER;
				txt.screenCenter(X);
				txt.cameras = state.cameras;
				state.add(txt);

				var btnY = 390;
				var btn:PsychUIButton = new PsychUIButton(0, btnY, 'OK', function()
				{
					var fileName:String = fullPath.substring(fullPath.lastIndexOf('/') + 1, fullPath.lastIndexOf('.'));
					var pathNoExt:String = fullPath.substring(0, fullPath.lastIndexOf('.'));

					function saveFile(ext:String)
					{
						var p1:String = '$pathNoExt.$ext';
						var p2:String = modFolder + '$fileName.$ext';
						trace(p1, p2);

						if (FileSystem.exists(p1)) File.saveBytes(p2, File.getBytes(p1));
					}

					FileSystem.createDirectory(modFolder);
					saveFile('png');
					saveFile('xml');
					saveFile('txt');
					saveFile('json');
					state.close();
					loadSprite(getImageName('$modFolder$fileName.png'));
				});
				btn.normalStyle.bgColor = FlxColor.GREEN;
				btn.normalStyle.textColor = FlxColor.WHITE;
				btn.screenCenter(X);
				btn.x -= 100;
				btn.cameras = state.cameras;
				state.add(btn);

				var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Cancel', function()
				{
					_makeNewSprite = null;
					state.close();
				});
				btn.screenCenter(X);
				btn.x += 100;
				btn.cameras = state.cameras;
				state.add(btn);
			}));
			#else
			showOutput('ERROR! File cannot be used, move it to "assets" and recompile.', true);
			#end
		}
		_file = null;
		#else
		trace('File couldn\'t be loaded! You aren\'t on Desktop, are you?');
		#end
	}

	function tryLoadImage(spr:FunkinSprite, imgPath:String)
	{
		if (spr == null || !Std.isOfType(spr, StageEditorSprite)) return;

		var s:StageEditorSprite = cast spr;
		if (s.type == 'square' || imgPath == null) return;

		s.image = imgPath;
		updateSelectedUI();
		updateSpriteListButtons();
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	private function onLoadCancel(_):Void
	{
		if (_file == null) return;

		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;

		if (_makeNewSprite != null)
		{
			createPopup.visible = createPopup.active = false;
			_makeNewSprite = null;
		}

		trace('Cancelled file loading.');
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	private function onLoadError(_):Void
	{
		if (_file == null) return;

		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;

		if (_makeNewSprite != null)
		{
			createPopup.visible = createPopup.active = false;
			_makeNewSprite = null;
		}

		trace('Problem loading file');
	}
}

class StageEditorAnimationSubstate extends MusicBeatSubstate
{
	var originalZoom:Float;
	var originalCamPoint:FlxPoint;
	var originalPosition:FlxPoint;
	var originalCamTarget:FlxObject;
	var originalAlpha:Float = 1;

	var target:StageEditorSprite;

	var curAnim:Int = 0;
	var animsTxtGroup:FlxTypedGroup<FlxText>;

	var camHUD:FlxCamera;
	var UI_animationbox:PsychUIBox;

	public function new(?target:StageEditorSprite)
	{
		super();

		this.target = target;
		this.bgColor = FlxColor.TRANSPARENT;
	}

	override function create()
	{
		super.create();

		FlxG.state.persistentDraw = false;
		FlxG.state.persistentUpdate = false;

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		curAnim = 0;
		originalZoom = FlxG.camera.zoom;
		originalCamPoint = FlxPoint.weak(FlxG.camera.scroll.x, FlxG.camera.scroll.y);
		originalPosition = FlxPoint.weak(target.x, target.y);
		originalCamTarget = FlxG.camera.target;
		originalAlpha = target.alpha;
		FlxG.camera.zoom = 0.5;
		FlxG.camera.scroll.set(0, 0);

		animsTxtGroup = new FlxTypedGroup<FlxText>();
		animsTxtGroup.cameras = [camHUD];
		add(animsTxtGroup);

		UI_animationbox = new PsychUIBox(FlxG.width - 330, 15, 310, 400, ['Animations']);
		UI_animationbox.cameras = [camHUD];
		UI_animationbox.scrollFactor.set();
		add(UI_animationbox);
		addAnimationsUI();

		target.alpha = 1;
		target.screenCenter();
		reloadAnimList();
		trace('Opened substate');
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
	var mainAnimTxt:FlxText;

	function addAnimationsUI()
	{
		var tab_group = UI_animationbox.getTab('Animations').menu;

		mainAnimTxt = new FlxText(15, 6, 0, 'Main Animation: ');
		var initAnimButton:PsychUIButton = new PsychUIButton(15, 22, 'Set as main', function()
		{
			if (target.animations == null || target.animations.length < 1) return;
			var anim:AnimationData = target.animations[curAnim];
			if (anim == null) return;

			mainAnimTxt.text = 'Main Animation: ${anim.anim}';
			target.firstAnimation = anim.anim;
		});
		tab_group.add(mainAnimTxt);
		tab_group.add(initAnimButton);

		animationInputText = new PsychUIInputText(15, 58, 150, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 38, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 38, 220, '', 8);
		animationFileInputText = new PsychUIInputText(animationIndicesInputText.x, animationIndicesInputText.y + 38, 220, '', 8);
		animationFramerate = new PsychUINumericStepper(animationIndicesInputText.x + 240, animationIndicesInputText.y + 4, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationFileInputText.x + 240, animationFileInputText.y - 1, 'Looped', 40);
		animationFlipXCheckBox = new PsychUICheckBox(animationNameInputText.x + 174, animationNameInputText.y - 1, 'Flip X', 40);
		animationFlipYCheckBox = new PsychUICheckBox(animationFlipXCheckBox.x + 74, animationNameInputText.y - 1, 'Flip Y', 40);

		animationTypeDropDown = new PsychUIDropDownMenu(190, animationFileInputText.y + 38, ['Symbol', 'FrameLabel']);
		animationRenderDropDown = new PsychUIDropDownMenu(35, animationTypeDropDown.y, ['Sparrow', 'AnimateAtlas']);
		animationRenderDropDown.onChangeList = (selectedAnim:Int, pressed:String) -> {
			animationTypeDropDown.alpha = (selectedAnim != 1 ? 0.5 : 1.0);
			animationTypeDropDown.active = (selectedAnim != 0);
		};
		animationRenderDropDown.selectedIndex = 0;

		animationDropDown = new PsychUIDropDownMenu(190, animationInputText.y - 3, ['']);
		animationDropDown.onChangeList = (selectedAnim:Int, pressed:String) -> {
			if (target.animations == null || target.animations.length < 1) return;
			if (pressed == 'NO ANIMATIONS' || selectedAnim < 0 || selectedAnim >= target.animations.length) return;

			var anim:AnimationData = target.animations[selectedAnim];
			if (anim == null) return;

			animationInputText.text = anim.anim;
			animationFileInputText.text = anim.image != null ? anim.image : '';
			animationNameInputText.text = anim.name != null ? anim.name : '';
			animationLoopCheckBox.checked = anim.loop == true;
			animationFramerate.value = anim.fps != null ? anim.fps : 24;
			animationFlipXCheckBox.checked = anim.flipX == true;
			animationFlipYCheckBox.checked = anim.flipY == true;
			animationTypeDropDown.selectedLabel = CoolUtil.capitalizeAt(anim.animType != null ? anim.animType : 'symbol', ['label']);
			animationRenderDropDown.selectedLabel = CoolUtil.capitalizeAt(anim.renderType != null ? anim.renderType : 'sparrow', ['atlas']);

			var indicesStr:String = (anim.indices != null) ? anim.indices.toString() : '[]';
			animationIndicesInputText.text = indicesStr.length > 2 ? indicesStr.substr(1, indicesStr.length - 2) : '';

			playAnim(anim.anim, true);
			curAnim = Std.int(Math.max(0, selectedAnim));
			updateTextColors();
		};

		var addUpdateButton:PsychUIButton = new PsychUIButton(70, animationRenderDropDown.y + 34, 'Add/Update', function()
		{
			if (animationInputText.text == '') return;

			var indicesText:String = animationIndicesInputText.text.trim();
			var indices:Array<Int> = [];
			if (indicesText.length > 0)
			{
				var indicesStr:Array<String> = indicesText.split(',');
				if (indicesStr.length > 0)
				{
					for (ind in indicesStr)
					{
						ind = ind.trim();
						if (ind.length < 1) continue;
						if (ind.contains('-'))
						{
							var splitIndices:Array<String> = ind.split('-');
							var indexStart:Int = Std.parseInt(splitIndices[0]);
							if (Math.isNaN(indexStart) || indexStart < 0)
								indexStart = 0;

							var indexEnd:Int = Std.parseInt(splitIndices[1]);
							if (Math.isNaN(indexEnd) || indexEnd < indexStart)
								indexEnd = indexStart;

							for (index in indexStart...indexEnd + 1)
								indices.push(index);
						}
						else
						{
							var index:Int = Std.parseInt(ind);
							if (!Math.isNaN(index) && index > -1)
								indices.push(index);
						}
					}
				}
			}

			var lastOffsets:Array<Int> = [0, 0];
			for (anim in target.animations)
				if (animationInputText.text == anim.anim)
				{
					lastOffsets = (anim.offsets != null && anim.offsets.length > 1) ? anim.offsets : [0, 0];
					if (target.hasAnimation(animationInputText.text))
						target.animation.remove(animationInputText.text);
					target.animations.remove(anim);
				}

			var addedAnim:AnimationData = FunkinAnimationUtil.newAnimation();
			addedAnim.anim = animationInputText.text;
			addedAnim.name = animationNameInputText.text;
			addedAnim.fps = Math.round(animationFramerate.value);
			addedAnim.loop = animationLoopCheckBox.checked;
			addedAnim.indices = indices;
			addedAnim.offsets = lastOffsets;
			addedAnim.image = animationFileInputText.text;
			addedAnim.flipX = animationFlipXCheckBox.checked;
			addedAnim.flipY = animationFlipYCheckBox.checked;
			addedAnim.animType = animationTypeDropDown.text.toLowerCase();
			addedAnim.renderType = animationRenderDropDown.text.toLowerCase();

			target.animations.push(addedAnim);
			target.reloadFrames();

			curAnim = Std.int(Math.max(0, target.animations.indexOf(addedAnim)));
			reloadAnimList();
			updateTextColors();
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:PsychUIButton = new PsychUIButton(195, addUpdateButton.y, 'Remove', function()
		{
			for (anim in target.animations)
			{
				if (animationInputText.text == anim.anim)
				{
					var resetAnim:Bool = false;
					if (!target.isAnimationNull() && anim.anim == target.getAnimationName()) resetAnim = true;

					if (target.animOffsets.exists(anim.anim)) target.animOffsets.remove(anim.anim);

					target.animations.remove(anim);
					if (target.hasAnimation(anim.anim)) target.animation.remove(anim.anim);

					if (resetAnim && target.animations.length > 0)
					{
						curAnim = FlxMath.wrap(curAnim, 0, target.animations.length - 1);
						target.reloadFrames();
						playAnim(target.animations[curAnim].anim, true);
						updateTextColors();
					}

					trace('Removed animation: ' + animationInputText.text);
					reloadAnimList();
					break;
				}
			}
		});

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 15, 120, 'ANIMATION LIST:'));
		tab_group.add(new FlxText(animationFileInputText.x, animationFileInputText.y - 15, 200, 'OPTIONAL - Animation file:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 15, 120, 'Animation name:'));
		tab_group.add(new FlxText(animationTypeDropDown.x, animationTypeDropDown.y - 15, 120, 'Animation type:'));
		tab_group.add(new FlxText(animationRenderDropDown.x, animationRenderDropDown.y - 15, 140, 'Animation render:'));
		tab_group.add(new FlxText(animationFramerate.x, animationFramerate.y - 15, 100, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 15, 160, 'Animation prefix:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 15, 200, 'ADVANCED - Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationFileInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationFlipXCheckBox);
		tab_group.add(animationFlipYCheckBox);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationTypeDropDown);
		tab_group.add(animationRenderDropDown);
		tab_group.add(animationDropDown);
	}

	function reloadAnimList()
	{
		if (target.animations == null) target.animations = [];

		if (target.animations.length > 0)
			curAnim = FlxMath.wrap(curAnim, 0, target.animations.length - 1);
		else
			curAnim = 0;

		for (text in animsTxtGroup) text.kill();

		var spr:FunkinSprite = target;
		if (target.animations.length > 0)
		{
			if (target.firstAnimation == null || !spr.hasAnimation(target.firstAnimation))
				target.firstAnimation = target.animations[0].anim;

			mainAnimTxt.text = 'Main Animation: ${target.firstAnimation}';
			playAnim(target.animations[curAnim].anim, true);
		}
		else
		{
			target.firstAnimation = null;
			mainAnimTxt.text = '(No Main Animation)';
		}

		for (num => anim in target.animations)
		{
			var text:FlxText = animsTxtGroup.recycle(FlxText);
			text.x = 10;
			text.y = 32 + (20 * num);
			text.fieldWidth = 400;
			text.fieldHeight = 20;
			
			if (anim.offsets != null) text.text = '${anim.anim}: ${spr.animOffsets.get(anim.anim)}';
			else text.text = '${anim.anim}: No offsets';

			text.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 1;
			animsTxtGroup.add(text);
		}
		updateTextColors();
		reloadAnimationDropDown();
	}

	function reloadAnimationDropDown()
	{
		var animList:Array<String> = [];
		for (anim in target.animations) animList.push(anim.anim);
		if (animList.length < 1) animList.push('NO ANIMATIONS');

		animationDropDown.list = animList;
		if (animList.length > 0 && animList[0] != 'NO ANIMATIONS')
			animationDropDown.selectedIndex = FlxMath.wrap(curAnim, 0, animList.length - 1);
	}

	inline function updateTextColors()
	{
		for (num => text in animsTxtGroup)
		{
			text.color = FlxColor.WHITE;
			if (num == curAnim) text.color = FlxColor.LIME;
		}
	}

	function playAnim(name:String, force:Bool = false)
	{
		var spr:FunkinSprite = target;

		spr.playAnim(name, force);
		if (!spr.animOffsets.exists(name)) spr.updateHitbox();
	}

	override function draw()
	{
		super.draw();
		if (target != null) target.draw();
	}

	final minZoom = 0.25;
	final maxZoom = 2;
	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (PsychUIInputText.focusOn != null) return;

		if (target != null) target.update(elapsed);
		else return;

		// ANIMATION SCROLLING (W/S, clic en lista)
		if (target.animations.length > 1)
		{
			var changedAnim:Bool = false;
			if (FlxG.keys.justPressed.W && (changedAnim = true)) curAnim--;
			else if (FlxG.keys.justPressed.S && (changedAnim = true)) curAnim++;

			if (!changedAnim && FlxG.mouse.justPressed)
			{
				for (num in 0...animsTxtGroup.length)
				{
					var text:FlxText = animsTxtGroup.members[num];
					if (text == null || !text.exists) continue;
					if (FlxG.mouse.overlaps(text, camHUD))
					{
						if (curAnim != num)
						{
							curAnim = num;
							changedAnim = true;
						}
						break;
					}
				}
			}

			if (changedAnim)
			{
				curAnim = FlxMath.wrap(curAnim, 0, target.animations.length - 1);
				playAnim(target.animations[curAnim].anim, true);
				updateTextColors();
				if (animationDropDown.list.length > 0 && animationDropDown.list[0] != 'NO ANIMATIONS')
					animationDropDown.selectedIndex = curAnim;
			}
		}

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if (FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if (FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// OFFSET
		var spr:FunkinSprite = target;
		if (!spr.isAnimationNull())
		{
			final moveKeys = ["LEFT", "RIGHT", "UP", "DOWN"];
			var isMoveKeys:Array<Bool> = moveKeys.map(k -> Reflect.getProperty(FlxG.keys.pressed, k));
			var isMoveKeysP:Array<Bool> = moveKeys.map(k -> Reflect.getProperty(FlxG.keys.justPressed, k));

			var anim:String = spr.getAnimationName();
			var changedOffset:Bool = false;

			var moveOffsets = (keys:Array<Bool>) -> {
				if (spr.animOffsets.get(anim) != null) {
					spr.frameOffset.x += ((keys[0] ? 1 : 0) - (keys[1] ? 1 : 0)) * shiftMultBig;
					spr.frameOffset.y += ((keys[2] ? 1 : 0) - (keys[3] ? 1 : 0)) * shiftMultBig;
				}
				else spr.frameOffset.x = spr.frameOffset.y = 0;

				changedOffset = true;
			}

			if (isMoveKeys.indexOf(true) != -1) {
				holdingArrowsTime += elapsed;
				if (holdingArrowsTime > 0.6)
				{
					holdingArrowsElapsed += elapsed;
					while (holdingArrowsElapsed > (1 / 60))
					{
						moveOffsets(isMoveKeys);
						holdingArrowsElapsed -= (1 / 60);
					}
				}
			}
			else holdingArrowsTime = 0;

			if (isMoveKeysP.indexOf(true) != -1) moveOffsets(isMoveKeysP);

			if (FlxG.mouse.pressedRight && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
			{
				spr.frameOffset.x -= FlxG.mouse.deltaViewX;
				spr.frameOffset.y -= FlxG.mouse.deltaViewY;
				changedOffset = true;
			}

			if (FlxG.keys.justPressed.R && FlxG.keys.pressed.CONTROL)
			{
				target.animations[curAnim].offsets = null;
				spr.animOffsets.remove(anim);
				spr.frameOffset.set(0, 0);
				spr.updateHitbox();
				animsTxtGroup.members[curAnim].text = '${anim}: No offsets';
			}

			if (changedOffset)
			{
				var offX = Math.round(spr.frameOffset.x);
				var offY = Math.round(spr.frameOffset.y);
				
				spr.addOffset(anim, offX, offY);
				target.animations[curAnim].offsets = [offX, offY];
				animsTxtGroup.members[curAnim].text = '${anim}: ${spr.animOffsets.get(anim)}';
			}
		}
		else
		{
			holdingArrowsTime = 0;
			holdingArrowsElapsed = 0;
		}

		// CAMERA CONTROLS
		var camX:Float = 0;
		var camY:Float = 0;
		var camMove:Float = elapsed * 500 * shiftMult * ctrlMult;
		var camZoom:Float = elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;

		if (FlxG.keys.pressed.J) camX -= camMove;
		if (FlxG.keys.pressed.K) camY += camMove;
		if (FlxG.keys.pressed.L) camX += camMove;
		if (FlxG.keys.pressed.I) camY -= camMove;

		if (camX != 0 || camY != 0)
		{
			FlxG.camera.scroll.x += camX;
			FlxG.camera.scroll.y += camY;
		}

		var lastZoom = FlxG.camera.zoom;
		if (FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 0.5;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < maxZoom) FlxG.camera.zoom = Math.min(maxZoom, FlxG.camera.zoom + camZoom);
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > minZoom) FlxG.camera.zoom = Math.max(minZoom, FlxG.camera.zoom - camZoom);

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.state.persistentDraw = true;
			FlxG.state.persistentUpdate = true;

			FlxG.camera.zoom = originalZoom;
			FlxG.camera.scroll.set(originalCamPoint.x, originalCamPoint.y);
			FlxG.camera.target = originalCamTarget;

			target.x = originalPosition.x;
			target.y = originalPosition.y;
			target.alpha = originalAlpha;

			if (target.animations.length > 0)
			{
				if (target.firstAnimation == null)
					target.firstAnimation = target.animations[0].anim;
				playAnim(target.firstAnimation);
			}

			close();
		}
	}
}

class StageEditorSprite extends FunkinSprite
{
	public var name:String;
	public var type:String;

	public var image(default, set):String = 'unknown';
	public var imageColor(default, set):String = 'FFFFFF';

	public var viewFilters:LoadFilters = (LOW_QUALITY) | (HIGH_QUALITY);

	public var firstAnimation:String;
	public var animations:Array<AnimationData>;

	public function new(data:Dynamic)
	{
		super(x, y);

		if (data == null) return;

		type = data.type;

		switch (type)
		{
			case 'sprite', 'square', 'animatedSprite':
				if (type == 'square')
				{
					try
					{
						makeGraphic(1, 1, FlxColor.WHITE);
						antialiasing = false;
					}
					catch (e:Dynamic) {}
				}

				if (data.image != null) image = data.image;
				if (data.color != null) imageColor = data.color;
				
				if (type == 'animatedSprite')
				{
					animations = data.animations;
					firstAnimation = data.firstAnimation;

					reloadFrames();
				}

				for (key in ['name', 'x', 'y', 'scale', 'scroll', 'viewFilters', 'antialiasing', 'zoomFactor', 'alpha', 'angle', 'flipX', 'flipY'])
				{
					var prop:Dynamic = Reflect.field(data, key);
					if (prop != null)
					{
						switch (key)
						{
							case 'scale':
								scale.set(prop[0], prop[1]);
								updateHitbox();
							case 'scroll':
								scrollFactor.set(prop[0], prop[1]);
							default:
								Reflect.setProperty(this, key, prop);
						}
					}
				}
		}
	}

	public function formatToJson()
	{
		var obj:Dynamic = {type: type};
		switch (type)
		{
			case 'square', 'sprite', 'animatedSprite':
				obj.name = name;
				obj.x = x;
				obj.y = y;
				obj.alpha = alpha;
				obj.angle = angle;
				obj.filters = viewFilters;
				obj.color = imageColor;
				obj.zoomFactor = zoomFactor;
				obj.scale = [scale.x, scale.y];
				obj.scroll = [scrollFactor.x, scrollFactor.y];

				if (type != 'square')
				{
					obj.flipX = flipX;
					obj.flipY = flipY;
					obj.image = image;
					obj.antialiasing = antialiasing;

					if (type == 'animatedSprite')
					{
						obj.animations = animations;
						obj.firstAnimation = firstAnimation;
					}
				}
		}

		return obj;
	}

	public function reloadFrames():Void
	{
		if (animations == null || type != 'animatedSprite') return;

		for (anim in animations) anim = cast FunkinAnimationUtil.newAnimationFromData(anim);

		FunkinAnimationUtil.reloadFrames(this, animations, [image]);
		FunkinAnimationUtil.addMultiAnimations(this, animations);

		trace(animations);

		if (firstAnimation != null) playAnim(firstAnimation, true);
	}

	function set_image(value:String)
	{
		try
		{
			switch (type)
			{
				case 'sprite':
					loadGraphic(Paths.image(value));
				case 'animatedSprite':
					frames = Paths.getAnimateAtlas(value);
			}

			updateHitbox();
		}
		catch (e:Dynamic) {}
		
		return (image = value);
	}

	function set_imageColor(value:String)
	{
		color = CoolUtil.colorFromString(value);
		return (imageColor = value);
	}

	override function set_antialiasing(value:Bool)
		return super.set_antialiasing(value && ClientPrefs.data.antialiasing);

	override function set_flipX(value:Bool)
		return super.set_flipX(value && (type != 'square'));

	override function set_flipY(value:Bool)
		return super.set_flipY(value && (type != 'square'));
}