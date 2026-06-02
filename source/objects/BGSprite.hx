package objects;

class BGSprite extends FlxSprite
{
	private var idleAnim:String;
	public function new(image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?anims:Array<String> = null, ?loop:Bool = false)
	{
		super(x, y);

		if (anims != null)
		{
			frames = Paths.getSparrowAtlas(image);
			for (anim in anims)
			{
				animation.addByPrefix(anim, anim, 24, loop);
				if (idleAnim == null) animation.play(idleAnim = anim);
			}
		}
		else
		{
			active = false;
			if (image != null) loadGraphic(Paths.image(image));
		}

		scrollFactor.set(scrollX, scrollY);
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function dance(?forceplay:Bool = false)
	{
		if (idleAnim != null) 
			animation.play(idleAnim, forceplay);
	}
}