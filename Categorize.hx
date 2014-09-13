
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
	var JS = "js";
	var Flash = "flash";
	var Dart = "dart";
	var Construct2 = "construct2";
	var Stencyl = "stencyl";
	var Haxe = "haxe";
	var Binary = "binary"; // unknown executable
	var CantDownloadDirectly = "nodl";
	public function toString() return this;
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
	var UnityWebPlayer = "unitywebplayer";
	var Phaser = "phaser";
	var MelonJS = "melonjs";
	var FlashPunk = "flashpunk";
	var Flixel = "flixel";
	var NME = "nme";
	var HaxeFlixel = "haxeflixel";
	var XNA = "xna";
	var JawsJS = "jawsjs";
	var NMEBinary = "nmebin";
	var EaseIJS = "easeijs";
	var AXGL = "axgl";
	var OpenFL = "openfl";
	public function toString() return this;
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
				priority : 10,
			},
		"phaser.min.js" =>
			{
				tech : JS,
				lib : Phaser,
			},
		"YoYo([0-9]+)" => // OSX
			{
				tech : GameMaker,
			},
		"dart.js" =>
			{
				tech : Dart,
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

		"*.xnb" =>
			{
				tech : Cpp,
				lib : XNA,
			},

		"*.swf" =>
			{
				tech : Flash,
				priority : -50,
			},

		"*.exe" =>
			{
				tech : Binary,
				priority : -100,
			},

		"org/lwjgl/*" =>
			{
				tech : Java,
				lib : LWJGL,
			},

		"c2runtime.js" =>
			{
				tech : Construct2,
				priority : 10,
			},

		"jaws.js" => { tech : JS, lib : JawsJS },

		"easeljs-[0-9.]+.min.js" => { tech : JS, lib : EaseIJS },

		"org.axgl.*" => { tech : Flash, lib : AXGL },

		"net.flashpunk.Engine" => {	lib : FlashPunk },
		"org.flixel.*" => { lib : Flixel },
		"stencyl.api.engine.*" => { tech : Stencyl, priority : 10 },
		"com.stencyl.*" => { tech : Stencyl, priority : 10 }, // stencyl 2
		"nme.NME_*" => { tech : Haxe, lib : NME, priority : 10 },
		"NME_assets_*" => { tech : Haxe, lib : NME, priority : 9 },
		"nme.ndll" => { tech : Haxe, lib : NMEBinary, priority : 10 },
		"haxe.*" => { tech : Haxe, priority : 9 },
		"flash.Boot" => { tech : Haxe, priority : 8 },
		"openfl.Assets" => { tech : Haxe, lib : OpenFL, priority : 11 },
		"__ASSET__flixel_img_logo_haxeflixel_svg" => { tech : Haxe, lib : HaxeFlixel, priority : 11 },
	];

	static var EREGS = null;
	public static function check( files : Array<String>, cat : Main.GameCategory ) {
		if( EREGS == null ) {
			var files = [for( f in FILES.keys() ) { f : f, d : FILES.get(f) } ];
			files.sort(function(f1, f2) {
				var p1 = f1.d.priority == null ? 0 : f1.d.priority;
				var p2 = f2.d.priority == null ? 0 : f2.d.priority;
				return p1 - p2;
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

	public static function isFinal( tech : Techno, lib : Library ) {
		if( tech != null && lib != null )
			return true;
		switch( tech ) {
		case Dart, Unity, GameMaker, Construct2, Stencyl:
			return true;
		case CantDownloadDirectly, NoData:
			return true;
		default:
		}
		return false;
	}

}