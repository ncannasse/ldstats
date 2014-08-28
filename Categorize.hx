
@:enum
abstract Techno(String) {
	var Python = "python";
	var Java = "java";
	var Lua = "lua";
	var Cpp = "cpp";
	var Csharp = "csharp";
	var GameMaker = "gamemaker";
	var Unity = "unity";
}

@:enum
abstract Library(String) {
	var Pygame = "pygame";
	var Love = "love";
	var SDL = "sdl";
	var Monogame = "monogame";
	var JOGL = "jogl"; // Java OpenGL
	var DirectX = "directx";
	var SFML = "sfml"; // c++ lib
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
	];

}