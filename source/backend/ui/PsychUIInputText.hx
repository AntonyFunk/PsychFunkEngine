package backend.ui;

import flixel.text.FlxInputText;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxSignal.FlxTypedSignal;

class PsychUIInputText extends FlxSpriteGroup
{
    public static final CHANGE_EVENT = "inputtext_change";

    public static var focusOn(default, set):PsychUIInputText = null;

    public final onChange = new FlxTypedSignal<(lastText:String, text:String)->Void>();
    
    public var name:String;
    public var inputText:PsychInputText;

    public var text(get, set):String;
    public var customFilter(default, set):EReg;

    public function new(x:Float = 0, y:Float = 0, width:Int = 150, text:String = '', size:Int = 8)
    {
        super(x, y);

        inputText = new PsychInputText(1, 1, Std.int(Math.max(1, width - 2)), text, size);
        inputText.onTextChange.add(_onInputCallback);
        inputText.onFocusChange.add(_onFocusCallback);
        inputText.caretColor = FlxColor.BLACK;
        inputText.selectionColor = 0xFF6B27BE;
        add(inputText);
    }

    public var broadcastEvent:Bool = true;
    function _onInputCallback(text:String, action:String)
    {
        if (broadcastEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
        onChange.dispatch(inputText.lastText, text);
    }

    function _onFocusCallback(focused:Bool)
    {
        focusOn = (focused ? this : null);
    }

	public static function set_focusOn(v:PsychUIInputText)
	{
		if (focusOn != v && focusOn != null && focusOn.exists) {
			var prev = focusOn;
			focusOn = v;
			
			prev.inputText.endFocus();
		}

		return focusOn = v;
	}

    function set_customFilter(Value:EReg):EReg
	{
		if (inputText != null) inputText.filterMode = REG(Value);
		return this.customFilter = Value;
	}

    function get_text():String return inputText.text;
    function set_text(Value:String):String return inputText.text = (Value ?? '');
}

class PsychInputText extends FlxInputText
{
    public final onSelectionChange = new FlxTypedSignal<Void->Void>();

    public var lastText:String = '';

    public var bg(get, default):FlxSprite;
    public var behindText(get, default):FlxSprite;
    public var selectionBoxes(get, default):Array<FlxSprite>;
    public var caret(get, default):FlxSprite;

    public var selectIndex(get, set):Int;

    override function regenBackground()
    {
        if (!background) return;

		_regenBackground = false;

        if (fieldBorderThickness > 0)
		{
			_fieldBorderSprite.makeGraphic(1, 1, fieldBorderColor);
            _fieldBorderSprite.setGraphicSize(Std.int(fieldWidth) + (fieldBorderThickness * 2), Std.int(fieldHeight) + (fieldBorderThickness * 2));
            _fieldBorderSprite.updateHitbox();
			_fieldBorderSprite.visible = true;
		}
		else _fieldBorderSprite.visible = false;
		
		if (backgroundColor.alpha > 0)
		{
			_backgroundSprite.makeGraphic(1, 1, backgroundColor);
            _backgroundSprite.setGraphicSize(Std.int(fieldWidth), Std.int(fieldHeight));
            _backgroundSprite.updateHitbox();
			_backgroundSprite.visible = true;
		}
		else _backgroundSprite.visible = false;

        updateBackgroundPosition();
    }

    override function updateSelectionBoxes()
    {
        super.updateSelectionBoxes();
        onSelectionChange.dispatch();
    }

    override function set_text(Value:String):String
    {
        lastText = text;
        return super.set_text(Value);
    }

    override function set_alpha(Value:Float):Float
    {
        bg.alpha = behindText.alpha = Value;
        return super.set_alpha(Value);
    }

    function get_bg():FlxSprite return this._fieldBorderSprite;
    function get_behindText():FlxSprite return this._backgroundSprite;
    function get_selectionBoxes():Array<FlxSprite> return this._selectionBoxes;
    function get_caret():FlxSprite return this._caret;

    function get_selectIndex():Int return this._selectionIndex;
    function set_selectIndex(Value:Int):Int return this._selectionIndex = Value;
}