package funkin.backend;

import openfl.events.Event;

class FunkinGame extends flixel.FlxGame
{
    override function create(_:Event)
    {
        _customSoundTray = funkin.backend.system.ui.FunkinSoundTray;

        super.create(_);
    }
}