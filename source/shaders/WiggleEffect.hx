package shaders;

import flixel.addons.display.FlxRuntimeShader;
import openfl.Assets;

enum WiggleEffectType
{
	DREAMY; // 0
	WAVY; // 1
	HEAT_WAVE_HORIZONTAL; // 2
	HEAT_WAVE_VERTICAL; // 3
	FLAG; // 4
}

/**
 * To use:
 * 1. Create an instance of the class, specifying speed, frequency, and amplitude.
 * 2. Call `sprite.shader = wiggleEffect` on the target sprite.
 * 3. Call the update() method on the instance every frame.
 */
class WiggleEffect extends FlxRuntimeShader
{
	public static function getEffectTypeId(v:Null<WiggleEffectType>):Int
	{
		return WiggleEffectType.getConstructors().indexOf(Std.string(v));
	}

	public var effectType(default, set):Null<WiggleEffectType> = DREAMY;

	function set_effectType(v:Null<WiggleEffectType>):Null<WiggleEffectType>
	{
		this.setInt('effectType', getEffectTypeId(v));
		return effectType = v;
	}

	public var waveSpeed(default, set):Float = 0;

	function set_waveSpeed(v:Float):Float
	{
		this.setFloat('uSpeed', v);
		return waveSpeed = v;
	}

	public var waveFrequency(default, set):Float = 0;

	function set_waveFrequency(v:Float):Float
	{
		this.setFloat('uFrequency', v);
		return waveFrequency = v;
	}

	public var waveAmplitude(default, set):Float = 0;

	function set_waveAmplitude(v:Float):Float
	{
		this.setFloat('uWaveAmplitude', v);
		return waveAmplitude = v;
	}

	var time(default, set):Float = 0;

	function set_time(v:Float):Float
	{
		this.setFloat('uTime', v);
		return time = v;
	}

	public function new(speed:Float, freq:Float, amplitude:Float, ?effect:WiggleEffectType = DREAMY):Void
	{
		super('
			#pragma header

			const int EFFECT_TYPE_DREAMY = 0;
			const int EFFECT_TYPE_WAVY = 1;
			const int EFFECT_TYPE_HEAT_WAVE_HORIZONTAL = 2;
			const int EFFECT_TYPE_HEAT_WAVE_VERTICAL = 3;
			const int EFFECT_TYPE_FLAG = 4;
			
			/**
			 * The current time. Used to shift the effect over time.
			 */
			uniform float uTime;		
			/**
			 * Which out of several effects should be used.
			 */
			uniform int effectType;
			/**
			 * How fast the waves move over time.
			 */
			uniform float uSpeed;		
			/**
			 * Number of waves over time.
			 */
			uniform float uFrequency;		
			/**
			 * How much the pixels are going to stretch over the waves.
			 */
			uniform float uWaveAmplitude;
			
			vec2 sineWave(vec2 pt) {
				float x = 0.0;
				float y = 0.0;
						
				if (effectType == EFFECT_TYPE_DREAMY) {
					float w = 1.0 / openfl_TextureSize.y;
					float h = 1.0 / openfl_TextureSize.x;
			
					// look mom, I know how to write shaders now
			
					pt.x = floor(pt.x / h) * h;
			
					float offsetX = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
			    
					pt.y += floor(offsetX / w) * w; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
					pt.y = floor(pt.y / w) * w;
			
					float offsetY = sin(pt.y * (uFrequency / 2.0) + uTime * (uSpeed / 2.0)) * (uWaveAmplitude / 2.0);
			    pt.x += floor(offsetY / h) * h; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
				} else if (effectType == EFFECT_TYPE_WAVY)  {
					float offsetY = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
					pt.y += offsetY; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
				} else if (effectType == EFFECT_TYPE_HEAT_WAVE_HORIZONTAL) {
					x = sin(pt.x * uFrequency + uTime * uSpeed) * uWaveAmplitude;
				} else if (effectType == EFFECT_TYPE_HEAT_WAVE_VERTICAL) {
					y = sin(pt.y * uFrequency + uTime * uSpeed) * uWaveAmplitude;
				} else if (effectType == EFFECT_TYPE_FLAG) {
					y = sin(pt.y * uFrequency + 10.0 * pt.x + uTime * uSpeed) * uWaveAmplitude;
					x = sin(pt.x * uFrequency + 5.0 * pt.y + uTime * uSpeed) * uWaveAmplitude;
				}
						
				return vec2(pt.x + x, pt.y + y);
			}
			
			void main() {
				vec2 uv = sineWave(openfl_TextureCoordv);
				gl_FragColor = texture2D(bitmap, uv);
			}
		');

		// These values may not propagate to the shader until later.
		this.waveSpeed = speed;
		this.waveFrequency = freq;
		this.waveAmplitude = amplitude;
		this.effectType = effect;
	}

	public function update(elapsed:Float)
	{
		// The setter tied to this value automatically propagates the value to the shader.
		this.time += elapsed;
	}
}
