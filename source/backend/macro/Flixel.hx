package backend.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

class FlixelMacro
{
	/**
	 * un-implement FlxText feature introduced in 6.1.1
	**/
	
	static macro function buildFlxText():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields = Context.getBuildFields();

		var antialiasExpr = macro this.antialiasing = backend.ClientPrefs.data.antialiasing; // lmao?

        for (field in fields) {
			if (field.name == 'set_antialiasing') fields.remove(field);
			else if (field.name == 'new') switch (field.kind) {
				case FFun(f):
					switch (f.expr.expr) {
						case EBlock(exprs):
							exprs.push(antialiasExpr);
						default:
							f.expr = macro { ${f.expr}; $antialiasExpr; };
					}
				default:
			}
		}

        return fields;
	}
}
#end