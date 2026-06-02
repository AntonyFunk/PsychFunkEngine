package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

class PsychUIDropDownMenu extends PsychUIInputText
{
	public static final REVEAL_EVENT = "dropdown_reveal";
	public static final CLICK_EVENT = "dropdown_click";

	public static var focusOn(default, set):PsychUIDropDownMenu = null;

	public var list(default, set):Array<String> = [];
	public var button:FlxSprite;
	
	public var onSelect:Int->String->Void;
	public var onChangeList:Int->String->Void;

	public var selectedIndex(default, set):Int = -1;
	public var selectedLabel(default, set):String = null;

	var _curFilter:Array<String>;
	var _itemWidth:Float = 0;
	public function new(x:Float, y:Float, list:Array<String>, callback:Int->String->Void = null, ?width:Int = 100)
	{
		super(x, y, width);

		if (list == null) list = [];
		_itemWidth = width - 2;

		button = new FlxSprite(inputText.fieldWidth).loadGraphic(Paths.image('psych-ui/dropdown_button', 'embed'), true, 20, 20);
		button.animation.add('normal', [0], false);
		button.animation.add('pressed', [1], false);
		button.animation.play('normal', true);
		add(button);

		inputText.fieldWidth = _itemWidth;
		inputText.fieldHeight = button.height - 2;
		inputText.y = button.getMidpoint().y - (inputText.height * 0.5);
		inputText.wordWrap = false;

		// fix to center (for now-)
		inputText.offset.y = inputText.caret.offset.y = -2;
		inputText.onSelectionChange.add(() -> 
		{
			for (i => box in inputText.selectionBoxes)
				if (box != null) box.offset.y = -2;
		});

		onSelect = callback;

		onChange.add((old:String, cur:String) ->
		{
			if (old != cur)
			{
				_curFilter = this.list.filter(function(str:String) return str.startsWith(cur));
				showDropDown(true, 0, _curFilter);
			}
		});

		for (option in list) addOption(option);
		
		showDropDown(false);

		if (this.list.length > 0) selectedIndex = 0;
		else selectedIndex = -1;
	}

	public static function set_focusOn(v:PsychUIDropDownMenu)
	{
		PsychUIInputText.focusOn = v;
		return focusOn = v;
	}

	function set_selectedIndex(v:Int)
	{
		selectedIndex = v;
		if (list.length < 1) selectedIndex = -1;
		else if (selectedIndex < 0 || selectedIndex >= list.length) selectedIndex = 0;

		if (selectedIndex >= 0 && list.length > 0) @:bypassAccessor selectedLabel = list[selectedIndex];
		else @:bypassAccessor selectedLabel = null;
		
		text = (selectedLabel != null) ? selectedLabel : '';

		if (onChangeList != null && selectedLabel != null) onChangeList(selectedIndex, selectedLabel);

		return selectedIndex;
	}

	function set_selectedLabel(v:String)
	{
		var id:Int = list.indexOf(v);
		if (list.length < 1) selectedIndex = -1;
		else selectedIndex = Std.int(Math.max(0, id));
	
		return v;
	}

	var _items:Array<PsychUIDropDownItem> = [];
	public var curScroll:Int = 0;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
	
		if (focusOn == this)
		{
			var wheel:Int = FlxG.mouse.wheel;
			if (FlxG.keys.justPressed.UP) wheel++;
			if (FlxG.keys.justPressed.DOWN) wheel--;
	
			if (wheel != 0) showDropDown(true, curScroll - wheel, _curFilter);
		}
	
		if (FlxG.mouse.justPressed)
		{
			var clickedItem = false;
	
			if (focusOn == this) {
				for (item in _items) {
					if (item.active && item.visible && FlxG.mouse.overlaps(item.bg, camera)) {
						clickedItem = true;
						break;
					}
				}
			}
	
			if (FlxG.mouse.overlaps(button, camera))
			{
				button.animation.play('pressed', true);
				if (focusOn != this)
				{
					if (broadcastDropDownEvent) PsychUIEventHandler.event(REVEAL_EVENT, this);
					showDropDown(true);
				}
				else showDropDown(false);
			}
			else if (focusOn == this && !FlxG.mouse.overlaps(inputText, camera) && !clickedItem)
			{
				showDropDown(false);
			}
		}
		else if (FlxG.mouse.released && button.animation.curAnim != null && button.animation.curAnim.name != 'normal') 
		{
			button.animation.play('normal', true);
		}
	}

	public function showDropDown(vis:Bool = true, scroll:Int = 0, onlyAllowed:Array<String> = null)
	{
		if (vis)
        {
            if (focusOn != null && focusOn != this) focusOn.showDropDown(false);
            focusOn = this;
        }
        else
        {
            if (focusOn == this) focusOn = null;
        }

		if (!vis)
		{
			text = selectedLabel;
			_curFilter = null;
		}

		curScroll = Std.int(Math.max(0, Math.min(onlyAllowed != null ? (onlyAllowed.length - 1) : (list.length - 1), scroll)));
		if (vis)
		{
			var n:Int = 0;
			for (item in _items)
			{
				if (onlyAllowed != null)
				{
					if (onlyAllowed.contains(item.label))
					{
						item.active = item.visible = (n >= curScroll);
						n++;
					}
					else item.active = item.visible = false;
				}
				else
				{
					item.active = item.visible = (n >= curScroll);
					n++;
				}
			}

			var txtY:Float = inputText.behindText.y + inputText.behindText.height + 1;
			for (num => item in _items)
			{
				if (!item.visible) continue;

				item.x = inputText.behindText.x;
				item.y = txtY;
				txtY += item.height;
				item.forceNextUpdate = true;
			}

			inputText.bg.scale.y = txtY - inputText.behindText.y + 2;
			inputText.bg.updateHitbox();
		}
		else
		{
			for (item in _items) item.active = item.visible = false;

			inputText.bg.scale.y = inputText.fieldHeight + 2;
			inputText.bg.updateHitbox();
		}
	}

	public var broadcastDropDownEvent:Bool = true;
	function clickedOn(num:Int, label:String)
	{
		selectedIndex = num;
		showDropDown(false);
		if (onSelect != null) onSelect(num, label);
		if (broadcastDropDownEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
	}

	function addOption(option:String)
	{
		@:bypassAccessor list.push(option);
		var item:PsychUIDropDownItem = cast recycle(PsychUIDropDownItem, () -> new PsychUIDropDownItem(1, 1, this._itemWidth), true);
		item.cameras = cameras;
		item.label = option;
		item.visible = item.active = false;
		// Resolver el índice al hacer clic: con recycle() un curID capturado al crear el ítem puede quedar desalineado con la lista actual.
		item.onClick = function()
		{
			var idx:Int = list.indexOf(item.label);
			if (idx < 0) idx = list.length - 1;
			clickedOn(idx, item.label);
		};
		item.forceNextUpdate = true;
		_items.push(item);
		insert(1, item);
	}

	function set_list(v:Array<String>)
	{
		var selected:String = selectedLabel;
		if (selected == null || selected == '') selected = text;
		
		showDropDown(false);

		for (item in _items) item.kill();
		
		list = [];
		_items = [];

		for (option in v) addOption(option);

		if (selected != null && selected != '')
			selectedLabel = selected;

		return v;
	}
}

class PsychUIDropDownItem extends FlxSpriteGroup
{
	public var hoverStyle:UIStyleData = {
		bgColor: 0xFF0066FF,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: FlxColor.WHITE,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};

	public var bg:FlxSprite;
	public var text:FlxText;
	public function new(x:Float = 0, y:Float = 0, width:Float = 100)
	{
		super(x, y);

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		bg.setGraphicSize(width, 20);
		bg.updateHitbox();
		add(bg);

		text = new FlxText(0, 0, width, 8);
		text.color = FlxColor.BLACK;
		add(text);
	}

	public var onClick:Void->Void;
	public var forceNextUpdate:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.mouse.justMoved || FlxG.mouse.justPressed || forceNextUpdate)
		{
			var overlapped:Bool = (FlxG.mouse.overlaps(bg, camera));

			var style = overlapped ? hoverStyle : normalStyle;
			bg.color = style.bgColor;
			text.color = style.textColor;
			bg.alpha = style.bgAlpha;
			forceNextUpdate = false;

			if (overlapped && FlxG.mouse.justPressed)
				onClick();
		}
		
		text.x = bg.x;
		text.y = bg.y + (bg.height * 0.5) - (text.height * 0.5);
	}

	public var label(default, set):String;
	function set_label(v:String)
	{
		label = v;
		text.text = v;
		bg.scale.y = text.height + 6;
		bg.updateHitbox();
		return v;
	}
}