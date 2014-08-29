
@:enum
abstract Techno(String) {
	var Python = "python";
	var Java = "java";
	var Lua = "lua";
	var Cpp = "cpp";
	var Csharp = "csharp";
	var GameMaker = "gamemaker";
	var Unity = "unity";
	var Unknown = "unknown";
	var NoData = "nodata"; // we couldn't tell
}

@:enum
abstract Library(String) {
	var Pygame = "pygame";
	var Love = "love";
	var SDL = "sdl";
	var Monogame = "monogame";
	var JOGL = "jogl"; // Java OpenGL binding
	var DirectX = "directx";
	var SFML = "sfml"; // c++ lib
	var LWJGL = "lwjgl"; // Java Lib
}

typedef CatInfos = {
	@:optional var tech : Techno;
	@:optional var lib : Library;
	@:optional var priority : Int;
}

class Categorize {

	static var FILES : Map<String,CatInfos> = [
		"pygame.base.pyd" =>
			{
				tech : Python,
				lib : Pygame,
			},
		"SDL([0-9]*).dll" =>
			{
				tech : Cpp,
				lib : SDL,
				priority : -20,
			},
		"Monogame.Framework.dll" =>
			{
				tech : Csharp,
				lib : Monogame,
			},
		"love.dll" =>
			{
				tech : Lua,
				lib : Love,
			},
		"lua([0-9]*).dll" =>
			{
				tech : Lua,
				priority : -5,
			},
		"mono([0-9]*).dll" =>
			{
				tech : Csharp,
				priority : -9,
			},
		"python([0-9]*).dll" =>
			{
				tech : Python,
				priority : -5,
			},
		"UnityEngine.dll" =>
			{
				tech : Unity,
			},
		"YoYo([0-9]+)" => // OSX
			{
				tech : GameMaker,
			},

		"*.jar" =>
			{
				tech : Java,
				priority : -9,
			},

		"jogl-all.jar" =>
			{
				tech : Java,
				lib : JOGL,
			},

		"d3dx([0-9_]*).dll" =>
			{
				tech : Cpp,
				lib : DirectX,
				priority : -15
			},

		"sfml-system([0-9-]*).dll" =>
			{
				tech : Cpp,
				lib : SFML,
			},

		"*.gmk" =>
			{
				tech : GameMaker
			},

		"*.exe" =>
			{
				tech : Cpp,
				priority : -100,
			},

		"org/lwjgl/*" =>
			{
				tech : Java,
				lib : LWJGL,
			}
	];

	static var EREGS = null;
	public static function check( files : Array<String>, cat : Main.GameCategory ) {
		if( EREGS == null ) {
			var files = [for( f in FILES.keys() ) { f : f, d : FILES.get(f) } ];
			files.sort(function(f1, f2) {
				var p1 = f1.d.priority == null ? 0 : f1.d.priority;
				var p2 = f2.d.priority == null ? 0 : f2.d.priority;
				return p2 - p1;
			});
			EREGS = [for( f in files ) {
				var r = f.f.toLowerCase().split(".").join("\\.");
				if( StringTools.startsWith(r, "*") )
					r = r.substr(1);
				else
					r = "^" + r;
				if( StringTools.endsWith(r, "*") )
					r = r.substr(0, -1);
				else
					r = r + "$";
				{ r : new EReg(r, ""), d : f.d };
			}];
		}
		files = [for( f in files ) f.toLowerCase()];
		for( r in EREGS ) {
			for( f in files )
				if( r.r.match(f) ) {
					if( r.d.lib != null ) cat.lib = r.d.lib;
					if( r.d.tech != null ) cat.tech = r.d.tech;
				}
		}
	}

}