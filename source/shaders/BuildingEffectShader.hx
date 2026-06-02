package shaders;

import flixel.addons.display.FlxRuntimeShader;

class BuildingEffectShader extends FlxRuntimeShader
{
	var effectAlpha:Float = 1.0;

	public var effectSpeed:Float = 1.0;

	public function new(speed:Float = 1.0)
	{
		super('
			#pragma header
		
			uniform float alphaShit;
		
			void main() {
				vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);
				if (color.a > 0.0)
				color -= alphaShit;

				gl_FragColor = color;
			}
		');

		this.effectSpeed = speed;
	}

	public function setAlpha(value:Float):Void
	{
		this.effectAlpha = value;
		this.setFloat('alphaShit', this.effectAlpha);
	}

	public function update(elapsed:Float):Void
	{
		setAlpha(effectAlpha + effectSpeed * elapsed);
	}

	public function reset()
	{
		setAlpha(0);
	}
}
