package backend.ui;

import flixel.util.FlxSignal.FlxTypedSignal;

class PsychUINumericStepper extends PsychUIInputText
{
	public static final CHANGE_EVENT = "numericstepper_change";

	public final onValueChange = new FlxTypedSignal<(value:Float)->Void>();

	public var buttonPlus:FlxSprite;
	public var buttonMinus:FlxSprite;

	public var step:Float = 0;

	public var min(default, set):Float = 0;
	public var max(default, set):Float = 0;

	public var decimals(default, set):Int = 0;
	public var isPercent(default, set):Bool = false;

	public var value(default, set):Float;

	public var broadcastStepperEvent:Bool = true;

	public function new(x:Float = 0, y:Float = 0, step:Float = 1, value:Float = 0, min:Float = -999, max:Float = 999, decimals:Int = 0, ?width:Int = 60, ?isPercent:Bool = false)
	{
		super(x, y, width, '');
		
		@:bypassAccessor this.decimals = decimals;
		@:bypassAccessor this.isPercent = isPercent;
		@:bypassAccessor this.min = min;
		@:bypassAccessor this.max = max;

		this.step = step;
		_updateFilter();

		buttonMinus = new FlxSprite().loadGraphic(Paths.image('psych-ui/stepper_minus', 'embed'), true, 16, 16);
		buttonMinus.antialiasing = ClientPrefs.data.antialiasing;
		buttonMinus.animation.add('normal', [0], false);
		buttonMinus.animation.add('pressed', [1], false);
		buttonMinus.animation.play('normal');
		add(buttonMinus);

		inputText.fieldWidth = Std.int(inputText.behindText.width - 2);
		inputText.onTextChange.add((_, _) -> _onValueCallback());
		inputText.alignment = CENTER;
		inputText.wordWrap = false;

		inputText.x += buttonMinus.width - 1;
		inputText.fieldWidth = width - buttonMinus.width - 16;
		
		buttonPlus = new FlxSprite(inputText.fieldWidth + buttonMinus.width).loadGraphic(Paths.image('psych-ui/stepper_plus', 'embed'), true, 16, 16);
		buttonPlus.antialiasing = ClientPrefs.data.antialiasing;
		buttonPlus.animation.add('normal', [0], false);
		buttonPlus.animation.add('pressed', [1], false);
		buttonPlus.animation.play('normal');
		add(buttonPlus);

		this.value = value;
	}

	function _onValueCallback()
	{
		_updateValue();
		_internalOnChange();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (buttonMinus == null || buttonPlus == null) return;

		if (FlxG.mouse.justPressed && PsychUIDropDownMenu.focusOn == null)
		{
			for (i => button in [buttonMinus, buttonPlus])
			{
				if (button.animation.curAnim == null) continue;

				if (button.exists && FlxG.mouse.overlaps(button, camera))
				{
					button.animation.play('pressed');

					value += step * (i != 0 ? 1 : -1);
					_internalOnChange();

					break;
				}
			}
		}
		else if (FlxG.mouse.released)
		{
			for (button in [buttonMinus, buttonPlus])
			{
				if (button.animation.curAnim == null) continue;

				if (button.exists && button.animation.curAnim.name != 'normal')
					button.animation.play('normal');
			}
		}
	}

	function set_value(Value:Float)
	{
		value = Math.max(min, Math.min(max, Value));
		text = Std.string(isPercent ? (value * 100) : value);

		_updateValue();

		return value;
	}

	function set_min(Value:Float)
	{
		min = Value;
		@:bypassAccessor if (min > max) max = min;

		_updateFilter();
		_updateValue();
		
		return min;
	}

	function set_max(Value:Float)
	{
		max = Value;
		@:bypassAccessor if (max < min) min = max;

		_updateFilter();
		_updateValue();

		return max;
	}

	function set_decimals(Value:Int)
	{
		decimals = Value;

		_updateFilter();

		return decimals;
	}

	function set_isPercent(Value:Bool)
	{
		final changed = (isPercent != Value);

		isPercent = Value;
		_updateFilter();

		if (changed)
		{
			text = Std.string(value * 100);
			_updateValue();
		}

		return isPercent;
	}

	function _updateValue()
	{
		var txt:String = text.replace('%', '');
		if (txt.indexOf('-') > 0) txt.replace('-', '');

		while(txt.indexOf('.') > -1 && txt.indexOf('.') != txt.lastIndexOf('.'))
		{
			final lastId = txt.lastIndexOf('.');
			txt = txt.substr(0, lastId) + txt.substring(lastId + 1);
		}

		var val:Float = Std.parseFloat(txt);

		if (Math.isNaN(val)) val = 0;
		if (isPercent) val /= 100;

		if (val < min) val = min;
		else if (val > max) val = max;
		val = FlxMath.roundDecimal(val, decimals);
		@:bypassAccessor value = val;

		if (isPercent)
		{
			text = Std.string(val * 100);
			text += '%';
		}
		else text = Std.string(val);

		if (inputText.caretIndex > text.length) inputText.caretIndex = text.length;
		if (inputText.selectIndex > text.length) inputText.selectIndex = text.length;
	}
	
	function _updateFilter()
	{
		if (decimals > 0)
		{
			if (isPercent) customFilter = InputFilterPatterns.PERCENT_DECIMAL;
			else customFilter = InputFilterPatterns.DECIMAL;
		}
		else
		{
			if (isPercent) InputFilterPatterns.PERCENT;
			else customFilter = InputFilterPatterns.INTEGER;
		}
	}

	function _internalOnChange()
	{
		onValueChange.dispatch(value);
		if (broadcastStepperEvent) PsychUIEventHandler.event(CHANGE_EVENT, this);
	}
}