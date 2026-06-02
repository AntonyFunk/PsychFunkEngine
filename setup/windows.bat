@echo off
color 0a
cd ..
@echo on
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install lime 8.3.2
haxelib install openfl 9.5.2
haxelib install flixel 6.1.2
haxelib install flixel-addons 4.0.1
haxelib install flixel-tools 1.5.1
haxelib install flixel-animate 1.5.0
haxelib install tjson 1.4.0
haxelib install hxdiscord_rpc 1.3.0
haxelib install hxvlc 2.2.6 --skip-dependencies
haxelib git hscript-insanity https://github.com/inky03/hscript-insanity.git
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis.git 1966f8fbbbc509ed90d4b520f3c49c084fc92fd6
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git
echo Finished!
pause
