# **Psych Funk Engine** forked from **Psych Engine Mint** by [**inky03**](https://github.com/inky03).

## **Classes:**
### FlxSprite (`flixel`):
- Added `frameOffset` [`FlxPoint`] property for offset animation.
- Added `frameOffsetAngle` [`Null<Float>`] property for angle to be applied to `frameOffset`.

### FlxTrail (`flixel.addons.effects`)
- Added `frameOffset` and `frameOffsetAngle` support.

## **Psych Classes:**
### Paths (`backend`):
- Deprecated `loadAnimateAtlas` function.
- Added `getAnimateAtlas` function (for `FlxAnimate`) [returns `flixel.graphics.frames.FlxAtlasFrames`].
- Added `getMultiAnimateAtlas` function (for `FlxAnimate`) [returns `flixel.graphics.frames.FlxFramesCollection`].
- *(Advanced)* Added `FlxG.stage.context3D` nulleable verification in `cacheBitmap` function.

### Character (`objects`):
- Deprecated `atlas` property.
- Deprecated `AnimArray` typedef (use `AnimationData`).

### *(Advanced)* PsychAnimateController (`backend.animation`):
- Similar to `PsychAnimationController`, but for `FlxAnimate`.

## **Funkin Classes:**
### FunkinSprite (`funkin.objects`):
- Added `animOffsets` [`Map<String, FlxPoint>`] property for offsets animations.
- Added `filters` [`Null<Array<BitmapFilter>>`] property (similar to `flixel.FlxCamera` filters).
- Added `zoomFactor` [`Float`] property (by [CodenameCrew](https://github.com/CodenameCrew) Engine).

### *(Advanced)* FunkinAnimationUtil (`funkin.backend.animation.util`):
- Class util for animations of `FunkinSprite`.

### *(Advanced)* FunkinFilterRenderer (`funkin.backend.display`):
- Coexisting with `FunkinSprite` for `filters` property.
- Coexisting with `FixedBitmapData` in the same folder.

## **Editors:**
### CharacterEditorState (`states.editors`):
- Reworked Code.
- New Animations Features (images, flipX, flipY, renderType, animType) [support multiple Sparrow / Animate Atlas].
- Fix Debug Selection Box (support screen bounds).

### StageEditorState (`states.editors`):
- Reworked Code (`StageEditorMetaSprite` -> `StageEditorSprite` [extends `FunkinSprite`]).
- New Animations Features for Animated Sprites (flipX, flipY and animType) [support Animate Atlas].
- Fixed Debug Selection Box (support angle view).

## **Libraries:**
### FlxAnimate (`animate`):
- Replaced `flxanimate` to `flixel-animate` library.
- Set was `flixel-animate` library to `1.5.0` version.
- Updated `openfl` library to `9.5.2` version.
- Updated `hxvlc` library to `2.2.6` version.

## **Others:**
- TitleState (`states`) *[minimal changes]*
- MainMenuState (`states`) *[minimal changes]*
- OptionsState (`options`) (certains options has been disabled for mobile or html5 targets) *[added VSync, Fullscreen & 30 Framerate limit]*

Using `new-hscript` branch from *inky03/PsychEngineMint*.