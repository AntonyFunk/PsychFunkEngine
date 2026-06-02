package backend.ui.utils;

class InputFilterPatterns
{
    public static final ALPHA = ~/[^a-zA-Z]*/g;

    public static final NUMERIC = ~/[^0-9]*/g;

    public static final ALPHANUMERIC = ~/[^a-zA-Z0-9]*/g;

    public static final HEXADECIMAL = ~/[^a-fA-F0-9]/g;

    public static final INTEGER = ~/[^0-9\-]/g;

    public static final DECIMAL = ~/[^0-9.\-]/g;

    public static final PERCENT = ~/[^0-9%\-]/g;

    public static final PERCENT_DECIMAL = ~/[^0-9.%\-]/g;
}