package funkin.backend.animation.util;

typedef AnimationData =
{
	var anim:String;

	@:optional var name:String;
	@:optional var image:String;

	@:optional var offsets:Array<Int>;
	@:optional var loop:Bool;

	@:optional var flipX:Bool;
	@:optional var flipY:Bool;

	@:optional var fps:Int;
	@:optional var indices:Array<Int>;

	@:optional var animType:String;
	@:optional var renderType:String;
}

class FunkinAnimationUtil
{
	public static function addAnimation(target:FlxSprite, anim:AnimationData)
	{
		if (target == null || anim == null) return;

		var fps:Int = anim.fps ?? 24;
		var loop:Bool = anim.loop ?? false;
		var flipX:Bool = anim.flipX ?? false;
		var flipY:Bool = anim.flipY ?? false;
		var offsets:Array<Int> = anim.offsets ?? [0, 0];

		if (anim.indices != null && anim.indices.length > 0) target.animation.addByIndices(anim.anim, anim.name, anim.indices, '', fps, loop, flipX, flipY);
		else target.animation.addByPrefix(anim.anim, anim.name, fps, loop, flipX, flipY);

		if (target is FunkinSprite)
		{
			var spr = cast target;

			if (spr != null)
			{
				if (!spr.hasAnimation(anim.anim)) spr.addOffset(anim.anim, 0, 0);
				else spr.addOffset(anim.anim, offsets[0], offsets[1]);
			}
		}
	}

	public static function addAnimateAnim(target:FlxAnimate, anim:AnimationData)
	{
		if (target == null || anim == null || !target.isAnimate) return;

		var fps:Int = anim.fps ?? 24;
		var loop:Bool = anim.loop ?? false;
		var flipX:Bool = anim.flipX ?? false;
		var flipY:Bool = anim.flipY ?? false;
		var animType:String = anim.animType ?? 'framelabel';
		var offsets:Array<Int> = anim.offsets ?? [0, 0];

		if (anim.indices != null && anim.indices.length > 0)
		{
			switch (animType)
			{
				case 'framelabel':
					target.anim.addByFrameLabelIndices(anim.anim, anim.name, anim.indices, fps, loop, flipX, flipY);
				case 'symbol':
					target.anim.addBySymbolIndices(anim.anim, anim.name, anim.indices, fps, loop, flipX, flipY);
			}
		}
		else
		{
			switch (animType)
			{
				case 'framelabel':
					target.anim.addByFrameLabel(anim.anim, anim.name, fps, loop, flipX, flipY);
				case 'symbol':
					target.anim.addBySymbol(anim.anim, anim.name, fps, loop, flipX, flipY);
			}
		}

		if (target is FunkinSprite)
		{
			var spr = cast target;

			if (spr != null)
			{
				if (!spr.hasAnimation(anim.anim)) spr.addOffset(anim.anim, 0, 0);
				else spr.addOffset(anim.anim, offsets[0], offsets[1]);
			}
		}
	}

	public static function addMultiAnimation(target:FlxAnimate, anim:AnimationData)
	{
		if (anim.renderType != 'animateatlas') addAnimation(target, anim);
		else addAnimateAnim(target, anim);
	}

	public static function addAnimations(target:FlxSprite, animations:Array<AnimationData>)
	{
		for (anim in animations)
			addAnimation(target, anim);
	}

	public static function addAnimateAnims(target:FlxAnimate, animations:Array<AnimationData>)
	{
		for (anim in animations)
			addAnimateAnim(target, anim);
	}

	public static function addMultiAnimations(target:FlxAnimate, animations:Array<AnimationData>)
	{
		for (anim in animations)
			addMultiAnimation(target, anim);
	}

	public static function reloadFrames(target:FlxAnimate, animations:Array<AnimationData>, ?images:Array<String>)
	{
		var textureList:Array<String> = [];

		for (anim in animations) textureList.push(anim.image);
		if (images != null) for (image in images) textureList.push(image);

		target.frames = Paths.getMultiAnimateAtlas(textureList);
	}

	public static function newAnimation():AnimationData
	{
		return {
			anim: '',
			name: '',
			image: '',
			fps: 24,
			loop: false,
			indices: [],
			offsets: [0, 0],
			flipX: false,
			flipY: false,
			animType: 'framelabel',
			renderType: ''
		};
	}

	public static function newAnimationFromData(data:Null<AnimationData>):AnimationData
	{
		return {
			anim: data.anim ?? '',
			name: data.name ?? '',
			image: data.image ?? '',
			fps: data.fps ?? 24,
			loop: data.loop ?? false,
			indices: data.indices ?? [],
			offsets: data.offsets ?? [0, 0],
			flipX: data.flipX ?? false,
			flipY: data.flipY ?? false,
			animType: data.animType ?? 'framelabel',
			renderType: data.renderType ?? ''
		};
	}
}