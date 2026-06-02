package backend;

enum abstract MessageBoxType(Int) from Int to Int
{
    public var ERROR = 0;
    public var WARNING = 1;
    public var INFORMATION = 2;
}

#if (cpp && windows)
@:buildXml('
<target id="haxe">
    <lib name="user32.lib" if="windows"/>
    <lib name="gdi32.lib" if="windows"/>
</target>
')
@:cppFileCode('
#include <windows.h>
#include <string>

static std::wstring hxToWString(const char* s)
{
	if (!s || !*s) return L"";

	int len = MultiByteToWideChar(CP_UTF8, 0, s, -1, nullptr, 0);
	if (len <= 1) return L"";

	std::wstring result(len - 1, L\'\\0\');
	MultiByteToWideChar(CP_UTF8, 0, s, -1, &result[0], len);
	
	return result;
}

static int windowAlertImpl(int type, const char* message, const char* title)
{
    UINT flags = MB_OK | MB_SETFOREGROUND | MB_TOPMOST;
    switch(type)
	{
        case 0: flags |= MB_ICONERROR; break;
        case 1: flags |= MB_ICONWARNING; break;
        case 2: flags |= MB_ICONINFORMATION; break;
    }

    std::wstring wMsg = hxToWString(message);
    std::wstring wTitle = hxToWString(title);

    HWND parent = GetActiveWindow();
    if (!parent) parent = GetForegroundWindow();

    MessageBoxW(parent, wMsg.c_str(), wTitle.c_str(), flags);
}
')
#end
class Native
{
    public static function __init__():Void
    {
        registerDPIAware();
    }

    public static function registerDPIAware():Void
    {
        #if (cpp && windows)
        untyped __cpp__('
            #ifdef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
            SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
            #else
            SetProcessDPIAware();
            #endif
        ');
        #end
    }

    private static var fixedScaling:Bool = false;
    public static function fixScaling():Void
    {
        if (fixedScaling) return;
        fixedScaling = true;

        #if (cpp && windows)
        final dpiScale = FlxG.stage.window.display.dpi / 96.0;
        FlxG.stage.window.width = Std.int(Main.game.width * dpiScale);
        FlxG.stage.window.height = Std.int(Main.game.height * dpiScale);

        FlxG.stage.window.x = Std.int((FlxG.stage.window.display.bounds.width - FlxG.stage.window.width) * 0.5);
        FlxG.stage.window.y = Std.int((FlxG.stage.window.display.bounds.height - FlxG.stage.window.height) * 0.5);

        untyped __cpp__('
            HWND hwnd = GetActiveWindow();
            if (hwnd)
			{
                HDC hdc = GetDC(hwnd);
                if (hdc)
				{
                    RECT rect;

                    if (GetClientRect(hwnd, &rect)) FillRect(hdc, &rect, (HBRUSH)GetStockObject(BLACK_BRUSH));
                    ReleaseDC(hwnd, hdc);
                }
            }
        ');
        #end
    }

    public static function windowAlert(?type:MessageBoxType = INFORMATION, message:String = '', title:String = ''):Int
    {
        #if (cpp && windows)
        return untyped __cpp__('windowAlertImpl({0}, {1}.c_str(), {2}.c_str())', type, message, title);
        #else
        return FlxG.stage.window.alert(message, title);
        #end
    }
}