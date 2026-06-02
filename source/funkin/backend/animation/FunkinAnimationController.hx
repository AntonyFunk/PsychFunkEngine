package funkin.backend.animation;

import backend.animation.PsychAnimateController;

@:access(objects.FunkinSprite)
class FunkinAnimationController extends PsychAnimateController
{
	/**
	 * The sprite that this animation controller is attached to.
	 */
	var _parentSprite:FunkinSprite;

	public function new(sprite:FunkinSprite)
	{
		super(sprite);
		
		_parentSprite = sprite;
	}

	override function set_frameIndex(frame:Int):Int
	{
		@:privateAccess _parentSprite._renderTextureDirty = true;

		return super.set_frameIndex(frame);
	}
}