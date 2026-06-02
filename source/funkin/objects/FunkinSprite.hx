package funkin.objects;

import openfl.filters.BitmapFilter;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.graphics.frames.FlxFrame;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import flixel.math.FlxRect;

import animate.internal.RenderTexture;

import funkin.backend.display.FunkinFilterRenderer;
import funkin.backend.animation.FunkinAnimationController;

class FunkinSprite extends FlxAnimate
{
	/**
	 * The filters array to be applied to the sprite.
	 */
	public var filters(default, set):Null<Array<BitmapFilter>> = null;

	public var animOffsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();

	public var animEnabled:Bool = true;
	public var animPaused(get, set):Bool;

	public var debugMode:Bool = false;

	public var zoomFactor:Float = 1;
	var _zRect:FlxRect;

	var hitbox:FlxSprite;
	var showHitbox:Bool = false;
	var isHitboxOverlaps:Bool = false;

	public function new(?x:Float, ?y:Float, ?graphic:FlxGraphicAsset)
	{
		super(x, y);

		filterRenderer = new FunkinFilterRenderer(this);

		if (graphic != null) loadGraphic(graphic);

		antialiasing = ClientPrefs.data.antialiasing;

		hitbox = new FlxSprite(x, y).makeGraphic(1, 1, FlxColor.RED);
		hitbox.scrollFactor.set();
		hitbox.alpha = 0.5;
	}

	override function initVars()
	{
		super.initVars();
		
		anim = new FunkinAnimationController(this);
		_zRect = FlxRect.get();
	}

	public override function draw()
	{
		if (hitbox != null && showHitbox && (visible && alpha > 0)) hitbox.draw();

		for (filter in filters ?? [])
		{
			@:privateAccess
			if (filter.__renderDirty) _renderTextureDirty = true;
		}

		super.draw();
	}

	public override function destroy()
	{
		if (animOffsets != null) {
			for (key in animOffsets.keys()) {
				final point = animOffsets[key];
				animOffsets.remove(key);

				if (point != null) point.put();
			}
			animOffsets = null;
		}

		frames = null;
		filterRenderer.destroy();

		FlxTween.cancelTweensOf(this);

		super.destroy();
	
		_zRect = FlxDestroyUtil.put(_zRect);
	}

	override public function loadGraphic(graphic:FlxGraphicAsset, animated:Bool = false, frameWidth:Int = 0, frameHeight:Int = 0, unique:Bool = false, ?key:String):FunkinSprite
	{
		super.loadGraphic(graphic, animated, frameWidth, frameHeight, unique, key);
		return this;
	}

	override public function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, unique:Bool = false, ?key:String):FunkinSprite
	{
		super.makeGraphic(width, height, color, unique, key);
		return this;
	}

	// Zoom Factor Implementation
	private inline function __shouldDoZoomFactor() return zoomFactor != 1;

	private inline function __prepareZoomFactor(?rect:FlxRect, camera:FlxCamera):FlxRect {
		return (rect ?? FlxRect.get()).set(
			camera.width * 0.5,
			camera.height * 0.5,
			(camera.scaleX > 0 ? Math.max : Math.min)(0, FlxMath.lerp(1 / camera.scaleX, 1, zoomFactor)),
			(camera.scaleY > 0 ? Math.max : Math.min)(0, FlxMath.lerp(1 / camera.scaleY, 1, zoomFactor))
		);
	}

	public override function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		super.getScreenBounds(newRect, camera);
		
		if (hitbox != null && (showHitbox && !isHitboxOverlaps)) {
			hitbox.x = newRect.x;
			hitbox.y = newRect.y;
			hitbox.scale.set(newRect.width, newRect.height);
			hitbox.updateHitbox();
		}

		return newRect;
	}

	public override function overlapsPoint(point:FlxPoint, inScreenSpace = false, ?camera:FlxCamera):Bool
	{
		if (!inScreenSpace)
		{
			return (point.x >= x) && (point.x < x + width) && (point.y >= y) && (point.y < y + height);
		}

		if (camera == null)
			camera = getDefaultCamera();

		final xPos = point.x - camera.scroll.x;
		final yPos = point.y - camera.scroll.y;
		getScreenBounds(_rect, camera);
		point.putWeak();

		if (hitbox != null && (showHitbox && isHitboxOverlaps)) {
			hitbox.x = _rect.x;
			hitbox.y = _rect.y;
			hitbox.scale.set(_rect.width, _rect.height);
			hitbox.updateHitbox();
		}

		return (xPos >= _rect.x) && (xPos < _rect.x + _rect.width) && (yPos >= _rect.y) && (yPos < _rect.y + _rect.height);
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		if (camera == null) camera = FlxG.camera;
		
		var bounds = getScreenBounds(_rect, camera);
		if (bounds.width == 0 && bounds.height == 0) return false;
				
		return camera.containsRect(bounds);
	}

	@:access(flixel.FlxCamera)
	override function getBoundingBox(camera:FlxCamera):FlxRect
	{
    	getScreenPosition(_point, camera);

    	_rect.set(_point.x, _point.y, width, height);
    	_rect = camera.transformRect(_rect);

    	if (isPixelPerfectRender(camera))
    	{
    		_rect.width = _rect.width / this.scale.x;
    		_rect.height = _rect.height / this.scale.y;
    		_rect.x = _rect.x / this.scale.x;
    		_rect.y = _rect.y / this.scale.y;
    		_rect.floor();
    		_rect.x = _rect.x * this.scale.x;
    		_rect.y = _rect.y * this.scale.y;
    		_rect.width = _rect.width * this.scale.x;
    		_rect.height = _rect.height * this.scale.y;
		}
		
		return _rect;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = FlxPoint.get(x, y);
	}

	public function switchOffset(anim1:String, anim2:String)
	{
		var old = animOffsets[anim1];
		animOffsets[anim1] = animOffsets[anim2];
		animOffsets[anim2] = old;
	}

	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0)
		playAnimation(name, force, reversed, frame);
	
	public function playAnimation(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0)
	{
		if (name == null || !hasAnimation(name)) return;
		
		animation.play(name, force, reversed, frame);
		
		var daOffset = getAnimationOffset(name);
		frameOffset.set(daOffset.x, daOffset.y);
		daOffset.putWeak();
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		if (!isAnimate) animation.addByPrefix(name, anim, 24, false);
		else this.anim.addBySymbol(name, anim, 24, false);
	}

	public inline function hasAnimation(name:String):Bool
		return animation.exists(name);

	public inline function getAnimationOffset(name:String):FlxPoint
	{
		if (animOffsets.exists(name)) return animOffsets[name];
		return FlxPoint.weak(0, 0);
	}

	public inline function getAnimationFrame():Int
		return !isAnimationNull() ? animation.curAnim.curFrame : -1;

	public inline function getAnimationName():String
		return !isAnimationNull() ? animation.name : '';

	public inline function isAnimationNull():Bool
	{
		if (isAnimate) return anim.curAnim == null;
		return animation.curAnim == null;
	}

	public inline function isAnimationLooped():Bool
		return !isAnimationNull() ? animation.curAnim.looped : false;

	public inline function isAnimationReversed():Bool
		return !isAnimationNull() ? animation.curAnim.reversed : false;

	public inline function isAnimationFinished():Bool
		return !isAnimationNull() ? animation.curAnim.finished : true;

	public function finishAnimation()
		if (!isAnimationNull()) animation.curAnim.finish();

	override function updateAnimation(elapsed:Float)
		if (animEnabled) super.updateAnimation(elapsed);

	function get_animPaused():Bool
		return !isAnimationNull() ? animation.curAnim.paused : true;
	function set_animPaused(value:Bool):Bool 
	{
		if (isAnimationNull()) return value;
		return animation.curAnim.paused = value;
	}

	var filterRenderer:FunkinFilterRenderer;
	var filtered:Bool = false;
	var filterOffsets:Array<Float> = [0, 0];
	
	override function checkRenderTexture():Bool
	{
		// Forcefully enable render texture when we have filters.
		if (filters != null && filters.length > 0) return true;
		
		return super.checkRenderTexture();
	}

	override function drawFrameComplex(frame:FlxFrame, camera:FlxCamera):Void
	{
		final willUseRenderTexture = checkRenderTexture();
		final matrix = this._matrix;
	  
		frame.prepareMatrix(matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		prepareDrawMatrix(matrix, camera);
	  
		if (willUseRenderTexture)
		{
			var bounds:Array<Int> = [Math.ceil(frame.frame.width), Math.ceil(frame.frame.height)];
			if (_renderTexture == null) _renderTexture = new RenderTexture(bounds[0], bounds[1]);
	  
			if (_renderTextureDirty)
			{
				_renderTexture.init(bounds[0], bounds[1]);
				_renderTexture.drawToCamera((camera, mat) ->
				{
					camera.drawPixels(frame, framePixels, mat, null, null, antialiasing, null);
				});
	  
				_renderTexture.render();
	  
				filterRenderer.applyFilters();
				_renderTextureDirty = false;
			}
	  
			if (filtered)
			{
				matrix.translate(filterOffsets[0], filterOffsets[1]);
				camera.drawPixels(filterRenderer.graphic?.imageFrame.frame, null, matrix, colorTransform, blend, antialiasing, shader);
			}
			else
			{
			 	camera.drawPixels(_renderTexture.graphic.imageFrame.frame, framePixels, matrix, colorTransform, blend, antialiasing, shader);
			}
		}
		else
		{
			camera.drawPixels(frame, framePixels, matrix, colorTransform, blend, antialiasing, shader);
		}
	}
	  
	override function drawAnimate(camera:FlxCamera):Void
	{
		final willUseRenderTexture = checkRenderTexture();
		final matrix = _matrix;
		
		matrix.identity();

		@:privateAccess var bounds = timeline._bounds;
		if (!willUseRenderTexture) matrix.translate(-bounds.x, -bounds.y);
	  
		prepareAnimateMatrix(matrix, camera, bounds);
	  
		if (renderStage) drawStage(camera);
	  
		timeline.currentFrame = animation.frameIndex;
	  
		#if !flash
		if (willUseRenderTexture)
		{
			if (_renderTexture == null) _renderTexture = new RenderTexture(Math.ceil(bounds.width), Math.ceil(bounds.height));
	  
			if (_renderTextureDirty)
			{
				_renderTexture.init(Math.ceil(bounds.width), Math.ceil(bounds.height));
				_renderTexture.drawToCamera((camera, matrix) ->
				{
					matrix.translate(-bounds.x, -bounds.y);
					timeline.draw(camera, matrix, null, null, antialiasing, null);
				});
				_renderTexture.render();
	  
				filterRenderer.applyFilters();
				_renderTextureDirty = false;
			}
	  
			if (filtered)
			{
				matrix.translate(filterOffsets[0], filterOffsets[1]);
				camera.drawPixels(filterRenderer.graphic?.imageFrame.frame, null, matrix, colorTransform, blend, antialiasing, shader);
			}
			else
			{
		  		camera.drawPixels(_renderTexture.graphic.imageFrame.frame, framePixels, matrix, colorTransform, blend, antialiasing, shader);
			}
		}
		else
		#end
		{
			timeline.draw(camera, matrix, colorTransform, blend, antialiasing, shader);
		}
	}

	override function prepareDrawMatrix(matrix:FlxMatrix, camera:FlxCamera)
	{
		super.prepareDrawMatrix(matrix, camera);

		if (__shouldDoZoomFactor())
		{
			__prepareZoomFactor(_zRect, camera);
			matrix.setTo(
				matrix.a * _zRect.width, matrix.b * _zRect.height,
				matrix.c * _zRect.width, matrix.d * _zRect.height,
				(matrix.tx - _zRect.x) * _zRect.width + _zRect.x,
				(matrix.ty - _zRect.y) * _zRect.height + _zRect.y,
			);
		}
	}

	override function preparePixelPerfectMatrix(matrix:FlxMatrix)
	{
		matrix.tx = Math.round(matrix.tx / this.scale.x) * this.scale.x;
		matrix.ty = Math.round(matrix.ty / this.scale.y) * this.scale.y;
	}

	@:noCompletion
	override function set_camera(value:FlxCamera):FlxCamera
	{
		if (hitbox != null) hitbox.camera = value;
		return super.set_camera(value);
	}

	@:noCompletion
	override function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		if (hitbox != null) hitbox.cameras = value;
		return super.set_cameras(value);
	}

	function set_filters(value:Null<Array<BitmapFilter>>):Null<Array<BitmapFilter>>
	{
		if (filters != value) _renderTextureDirty = true;
		return filters = value;
	}
}