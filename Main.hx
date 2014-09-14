import Categorize;

@:enum abstract Category(Int) {
	var Overall = 0;
	var Graphics = 1;
	var Theme = 2;
	var Innovation = 3;
	var Fun = 4;
	var Audio = 5;
	var Humor = 6;
	var Mood = 7;
	var Community = 8; // LD <= 22
	public function toInt() return this;
}

typedef GameInfos = {
	var uid : Int;
	var img : String;
	var title : String;
	var user : String;
	@:optional var data : GameData;
	@:optional var cat : GameCategory;
}

typedef GameData = {
	var jam : Bool;
	var htmlDesc : String;
	var links : Array<{ url : String, title : String }>;
	var ratings : Array<Float>;
	var rankings : Array<Int>;
	var coolness : Int;
	var screens : Array<{ thumb : String, url : String }>;
}

typedef GameCategory = {
	var tech : Techno;
	var lib : Library;
}

typedef GamesDB = Array<GameInfos>

class Main {

	var games : GamesDB;
	var ld : Int;
	var dbFile : String;
	var dataDir : String;
	var rankings : Bool = true;

	function new() {
	}

	function load( ld : Int ) {
		this.ld = ld;
		dbFile = "data/ld" + ld + ".dat";
		dataDir = "games/ld" + ld;
		games = try haxe.Json.parse(sys.io.File.getContent(dbFile)) catch( e : Dynamic ) [];
	}

	function fetch() {
		if( games.length == 0 ) {
			log("Getting game list");

			var url = "http://www.ludumdare.com/compo/ludum-dare-" + ld + "/?action=preview&q=&etype=&start=";
			var h = get(url);
			var entries = Std.parseInt(extract(h,~/<h3>All Entries \(([0-9]+)\)/));
			for ( i in 1...Math.ceil(entries / 24) ) {
				h += get(url + (i * 24));
				Sys.print(".");
			}

			var gamelink = new EReg("<div><a href='\\?action=preview&uid=([0-9]+)'><img src='([^']+)'><div class='title'><i>([^<]+)</i></div>([^<]+)</a>","");
			while( gamelink.match(h) ) {
				games.push( {
					uid : Std.parseInt(gamelink.matched(1)),
					img : gamelink.matched(2),
					title : utf(gamelink.matched(3)),
					user : gamelink.matched(4),
				});
				h = gamelink.matchedRight();
			}
			log(games.length+ " found");
			save();
		}

		for( g in games )
			fetchGame(g);
	}

	function utf( s : String ) {
		if( haxe.Utf8.validate(s) )
			return s;
		return haxe.Utf8.encode(s);
	}

	function get( url : String ) {
		var lastError = null;
		for( i in 0...3 ) {
			try {
				var h = new haxe.Http(url);
				var data = null;
				var status = 0;
				h.onStatus = function(s) status = s;
				h.onData = function(d) data = d;
				h.onError = function(e) throw e;
				h.request();
				if( data == null ) throw "Missing data for " + url;
				if( status >= 300 && status < 400 ) {
					var l = h.responseHeaders.get("Location");
					if( l == null ) l = h.responseHeaders.get("location");
					if( l == null ) throw "Unknown redir " + h.responseHeaders;
					return get(l);
				}
				return data;
			} catch( e:Dynamic ) {
				lastError = Std.string(e);
				log("Failed to retrieve " + url + ", retrying (" + lastError +")");
				Sys.sleep(1);
			}
		}
		throw "Aborted ("+lastError+")";
	}

	function extract( str : String, e : EReg, match = 1 ) {
		if( !e.match(str) )
			throw "Reg not matched in " + str;
		return e.matched(match);
	}

	function progress( g : GameInfos ) {
		return (Std.int(games.indexOf(g) * 1000 / games.length) / 10) + "%";
	}

	function fetchGame( g : GameInfos ) {
		if( g.data != null ) return;
		log("Fetching " + g.title+"#" + g.uid+" "+progress(g));
		var h = get("http://www.ludumdare.com/compo/ludum-dare-" + ld + "/?action=preview&uid=" + g.uid);

		h = h.split("\r\n").join("\n").split("\n").join(" ");

		var links = [];
		var linkData = extract(h, ~/<p class='links'>(.*?)<\/p>/).split("<a ");
		linkData.shift();
		for( l in linkData ) {
			var r = ~/href="([^"]+)" target='_blank'>([^<]+)<\/a>/;
			if( !r.match(l) ) throw "Invalid link #"+l+"# in " + linkData;
			links.push( { url : StringTools.trim(r.matched(1)), title : utf(r.matched(2)) } );
		}
		g.data = {
			jam : false,
			htmlDesc : utf(extract(h, ~/<p class='links'>.*?<\/p><p>(.*?)<\/p>/)),
			links : links,
			coolness : 0,
			ratings : [],
			rankings : [],
			screens : [],
		};

		var screens = h.split("<p class='links'").pop().split("<h3>Ratings")[0];
		var rscreen = new EReg("<a href='([^']+)' target='_blank'><img src='([^']+)'>", "");
		while( rscreen.match(screens) ) {
			g.data.screens.push( { url : rscreen.matched(1), thumb : rscreen.matched(2) } );
			screens = rscreen.matchedRight();
		}

		if( !rankings ) {
			save();
			return;
		}

		var ratings = extract(h, new EReg("<h3>Ratings</h3><p><table(.*?)</table>", "")).split("<tr>");
		ratings.shift();

		var rank = new EReg('<td align=center>#([0-9]+)<td>([^<]+)<td align=right>([0-9.]+)', '');
		var rank2 = new EReg('<td align=center><img src=\'http://www.ludumdare.com/compo/wp-content/plugins/compo2/images/i(gold|bronze|silver).gif\' align=absmiddle><td>([^<]+)<td align=right>([0-9.]+)', '');
		for( r in ratings ) {
			var irank = 0, scat = "", rate = 0.;
			if( rank.match(r) ) {
				irank = Std.parseInt(rank.matched(1));
				scat = rank.matched(2);
				rate = Std.parseFloat(rank.matched(3));
			} else if( rank2.match(r) ) {
				irank = switch( rank2.matched(1) ) {
				case "gold": 1;
				case "bronze": 2;
				case "silver": 3;
				case x: throw "assert" + x;
				};
				scat = rank2.matched(2);
				rate = Std.parseFloat(rank2.matched(3));
			} else
				throw "Invalid ranking #" + r + "# in " + ratings.join("<tr>");
			if( StringTools.endsWith(scat, "(Jam)") ) {
				g.data.jam = true;
				scat = scat.substr(0, -5);
			}
			var cat = switch( scat ) {
			case "Overall": Overall;
			case "Graphics": Graphics;
			case "Theme": Theme;
			case "Innovation": Innovation;
			case "Fun": Fun;
			case "Audio": Audio;
			case "Humor": Humor;
			case "Mood": Mood;
			case "Community": Community;
			case "Coolness":
				g.data.coolness = Std.int(rate);
				continue;
			case c: throw "Unknown category '" + c+"' in ranking #"+r+"#";
			}
			g.data.ratings[cat.toInt()] = rate;
			g.data.rankings[cat.toInt()] = irank;
		}
		save();
	}

	function log(str:Dynamic) {
		Sys.println(str);
	}

	function save() {
		if( dbFile == null ) return;
		sys.io.File.saveContent(dbFile, haxe.Json.stringify(games, null, "\t"));
	}

	function dataFile( g : GameInfos ) {
		if( g.data == null ) return null;
		var l = g.data.links[0];
		if( l == null ) return null;
		var url = StringTools.htmlUnescape(l.url);
		var ext = url.split("/").pop().split(".");
		var ext = if( ext.length == 1 ) "html" else ext.pop().toLowerCase();
		if( ext.length < 2 || !~/^[a-z]+$/.match(ext) ) ext = "html";
		switch( ext ) {
		case "exe", "com", "bat": ext += "_";
		default:
		}
		var file = dataDir + "/" + g.uid + "." + ext;
		return file;
	}


	function categorize( g : GameInfos ) {

		var dat = dataFile(g);

		if( dat == null || !sys.FileSystem.exists(dat) )
			return null;

		var cat : GameCategory = {
			tech : null,
			lib : null,
		};
		checkCategory(g, cat, dat);

		//if( Categorize.isFinal(cat.tech, cat.lib) )
		//	sys.FileSystem.deleteFile(dat);

		if( cat.tech == null ) Reflect.deleteField(cat, "tech");
		if( cat.lib == null ) Reflect.deleteField(cat, "lib");

		g.cat = cat;
		return cat;
	}


	function baseFile( url : String ) {
		return url.split("/").pop().split("?").shift();
	}

	function checkCategory( g : GameInfos, cat : GameCategory, dat : String ) {

		// we don't know how to directly download the file from these :'(
		var url = g.data.links[0].url;
		for( r in ["http://gamejolt.com", "https://sites.google.com", "https://drive.google.com/file", "https://app.box.com/", "http://www.mediafire.com", "https://mega.co.nz", "https://github.com/"] ) {
			if( StringTools.startsWith(url, r) ) {
				cat.tech = CantDownloadDirectly;
				return;
			}
		}



		for( l in g.data.links )
			switch( l.title.toLowerCase() ) {
			case "love", "löve":
				cat.tech = Lua;
				cat.lib = Love;
				return;
			default:
			}

		var content = sys.io.File.getBytes(dat);

		if( content.length == 0 ) {
			cat.tech = NotAvailable;
			return;
		}

		// ZIP / JAR
		if( content.get(0) == 0x50 && content.get(1) == 0x4B && content.get(2) == 0x03 && content.get(3) == 0x04 ) {
			log("Categorize #" + g.uid + " " + progress(g));
			if( dat.split(".").pop() == "jar" )
				cat.tech = Java;
			// ZIP FILE
			var z = try haxe.zip.Reader.readZip(new haxe.io.BytesInput(content)) catch( e : Dynamic ) { cat.tech = NotAvailable; /* 404 html ? */ new List(); };
			Categorize.check([for( f in z ) f.fileName.split("/").pop()], cat);
			return;
		}

		function use7Z() {
			// .rar
			if( content.get(0) == 'R'.code && content.get(1) == 'a'.code && content.get(2) == 'r'.code && content.get(3) == '!'.code )
				return true;
			// .7z
			if( content.get(0) == '7'.code && content.get(1) == 'z'.code )
				return true;
			return false;
		}
		if( use7Z() ) {
			var outDir = dataDir + "/" + g.uid + "_files";
			if( !sys.FileSystem.exists(outDir) ) {
				if( Sys.command("7z x -y -o" + outDir + " " + dat) < 0 )
					return;
			}
			var files = [];
			function lookRec( dir ) {
				for( f in sys.FileSystem.readDirectory(dir) ) {
					var path = dir + "/" + f;
					files.push(f);
					if( sys.FileSystem.isDirectory(path) )
						lookRec(path);
				}
			}
			lookRec(outDir);
			Categorize.check(files, cat);
			return;
		}

		var contentStr = content.toString();

		if( contentStr.indexOf("https://ssl-webplayer.unity3d.com") != -1 || contentStr.indexOf("http://unity3d.com/webplayer") != -1 ) {
			cat.tech = Unity;
			cat.lib = UnityWebPlayer;
			return;
		}

		if( contentStr.toLowerCase().indexOf('<applet') != -1 ) {
			cat.tech = Java;
			cat.lib = JavaApplet;
			// TODO, download and fetch the library
			return;
		}

		var flashFiles = [], jsScripts = [];

		~/["']([-a-zA-Z0-9_.:\/?,;=% ]+\.[sS][wW][fF])(\?[^'"]*)?["']/g.map(contentStr, function(r) { flashFiles.push(r.matched(1)); return ""; } );
		~/[sS][rR][cC][ \t]*=[ \t]*["']([-a-zA-Z0-9_.:\/,;=% ]+\.[jJ][sS](\?[^'"]*)?)["']/g.map(contentStr, function(r) { jsScripts.push(r.matched(1)); return ""; } );
		// for require.js
		~/data-main[ \t]*=[ \t]*["']([-a-zA-Z0-9_.:\/,;=% ]+\.[jJ][sS](\?[^'"]*)?)["']/g.map(contentStr, function(r) { jsScripts.push(r.matched(1)); return ""; } );

		for( f in flashFiles.copy() ) {
			var fl = f.toLowerCase();
			for( r in ["expressinstall.swf", "playerProductInstall.swf", "internal.kongregate.com","googlevideoadshell","cdn2.kongcdn.com", "cloudfront.net"] ) {
				if( fl.indexOf(r) != -1 ) {
					flashFiles.remove(f);
					break;
				}
			}
		}

		if( baseFile(url).split(".").pop() == "swf" )
			flashFiles.push(baseFile(url));
		if( baseFile(url).split(".").pop() == "js" )
			jsScripts.push(baseFile(url));

		for( s in jsScripts.copy() ) {
			var sl = s.toLowerCase();
			for( r in [".mediafire.com", "ssl.gstatic.com", "caja.js", "require.js", "angularjs", "bootstrap.min", "facebook.net", "apis.google.com", "jquery", "swfobject","show_ads","twitter.com","facebook.com","modernizr","boxcdn.net","cloudfront.net","gravatar.com",".wp.com","google-analytics.com"] )
				if( sl.indexOf(r) != -1 ) {
					jsScripts.remove(s);
					break;
				}
			if( sl.indexOf("unityobject") != -1 ) {
				cat.tech = Unity;
				cat.lib = UnityWebPlayer;
				return;
			}
		}

		if( contentStr.indexOf("WP_UnityObject") != -1 ) {
			cat.tech = Unity;
			cat.lib = UnityWebPlayer;
			return;
		}

		var files = [for( f in jsScripts.concat(flashFiles) ) baseFile(f)];
		Categorize.check(files, cat);

		if( Categorize.isFinal(cat.tech, cat.lib) )
			return;

		if( flashFiles.length == 0 && jsScripts.length == 0 ) {
			if( ~/<script([^<]*?)[\r\n]/.match(contentStr.toLowerCase()) )
				jsScripts.push(null); // consider that the html files contains the html script
		}

		if( flashFiles.length == 0 && jsScripts.length == 0 ) {
			if( cat.tech == null )
				Categorize.check([baseFile(url)], cat);
			if( cat.tech == null )
				log("Don't know what to do with #" + g.uid + "\n" + g.data.links[0].url);
			return;
		}

		if( flashFiles.length > 0 ) {
			var all = [];
			for( f in flashFiles ) {
				var content = downloadData(g, f);
				if( content == null ) continue;
				var swf = try {
					new format.swf.Reader(new haxe.io.BytesInput(content)).read();
				} catch( e : Dynamic ) {
					null;
				}
				if( swf == null ) continue;
				var checks = [];
				for( t in swf.tags )
					switch( t ) {
					case TSymbolClass(cl):
						for( c in cl )
							checks.push(c.className);
					case TActionScript3(data, _):
						var as = try new format.abc.Reader(new haxe.io.BytesInput(data)).read() catch( e : Dynamic ) null;
						inline function idx<T>(i:format.abc.Data.Index<T>) return switch( i ) { case Idx(i): i; };
						if( as != null ) {
							for( cl in as.classes ) {
								try {
									switch( as.names[idx(cl.name) - 1] ) {
									case NName(n, ns):
										var n = as.strings[idx(n) - 1];
										var ns = as.namespaces[idx(ns) - 1];
										switch( ns ) {
										case NPublic(i):
											var pack = as.strings[idx(i) - 1];
											if( pack != "" ) n = pack + "." + n;
										default:
										}
										checks.push(n);
									default:
									}
								} catch( e : Dynamic ) {
									// ignore
								}
							}
						}
					default:
					}
				var old = cat.lib;
				all = all.concat(checks);
				Categorize.check(checks, cat);
				if( old != null && old != cat.lib )
					log("CONFLICTING FLASH LIBS " + old + " and " + cat.lib + " FOR #" + g.uid);
			}
			if( cat.tech == null && all.length > 0 )
				cat.tech = Flash;
			//if( cat.lib == null )
			//	trace(all);
		} else {

			var libs : Map<String,{ ?lib : Library, ?tech : Techno }> = [
				"www.melonjs.org" => { lib : MelonJS },
				"melonJS-" => { lib : MelonJS },
				"Phaser v1." => { lib : Phaser },
				"Photon Storm" => { lib : Phaser },
				"haxe." => { tech : Haxe },
				"yoyogames.com" => { tech : GameMaker },
				"apps.playcanvas.com" => { lib : PlayCanvas },
				"dart2js" => { tech : Dart },
				"craftyjs.com" => { lib : CraftyJS },
				"crafty.js" => { lib : CraftyJS },
				"crafty-min.js" => { lib : CraftyJS },
				"Three.js" => { lib : ThreeJS },
				"mrdoob.com" => { lib : ThreeJS },
				"love.render.js" => { tech : Lua, lib : Love },
				"Pixi.JS - v" => { lib : PixiJS },
			];

			var foundWords = 0;
			var words = [
				"ld"+this.ld,"ld"+this.ld,"ld"+this.ld, // force JS if we have found
				"canvas", "requestAnimationFrame",
				"getContext2d(", "drawImage(", "fill(", "putImageData(",
				"getContextWebGL(", "attachShader(","clear(","texImage2D(","drawArrays(","drawElements("
			];
			for( i in 0...words.length ) words[i] = words[i].toLowerCase();

			for( f in jsScripts ) {
				var content = f == null ? content : downloadData(g, f);
				if( content == null ) continue;
				var contentStr = (url + f + content.toString()).toLowerCase();

				for( w in words )
					foundWords += contentStr.split(w).length - 1;

				for( l in libs.keys() )
					if( contentStr.indexOf(l.toLowerCase()) != -1 ) {
						var old = cat.lib;
						var inf = libs.get(l);
						if( inf.lib != null ) cat.lib = inf.lib;
						if( inf.tech != null ) cat.tech = inf.tech;
						if( old != null && old != cat.lib ) {
							if( old == ThreeJS && cat.lib == PixiJS ) continue;
							log("CONFLICTING JS LIBS " + old + " and " + cat.lib + " FOR #" + g.uid);
						}
					}
			}

			if( cat.lib != null && cat.tech == null ) cat.tech = JS;

			// we are not sure, but let's assume
			if( cat.tech == null && cat.lib == null ) {
				if( jsScripts[0] == "/static/javascript/external/html5shiv.js" )
					cat.tech = NotAvailable; // DropBox 404
				else if( foundWords >= 2 )
					cat.tech = JS;
				else
					log("Could not detect game in JS files #"+g.uid+" " + jsScripts+" in "+url);
			}

		}

	}

	function downloadData( g : GameInfos, fileUrl : String ) {

		var path = dataDir + "/" + g.uid + "_files";

		if( !sys.FileSystem.exists(path) )
			sys.FileSystem.createDirectory(path);

		var file = path + "/" + ~/[^A-Za-z0-9_.-]/g.replace(fileUrl, "_");
		if( sys.FileSystem.exists(file) )
			return sys.io.File.getBytes(file);
		log("Fetching " + g.title+"#" + g.uid + " " + fileUrl);
		try sys.FileSystem.deleteFile(file + ".tmp") catch( e : Dynamic ) { };

		if( !~/^https?:/.match(fileUrl.toLowerCase()) ) {

			// get the relative file from the url

			var url = g.data.links[0].url.split("/");
			var efile = url.length <= 3 ? "" : url.pop();

			if( efile != "" && efile.indexOf(".") == -1 )
				url.push(efile);

			var baseURL = url.join("/")+"/";

			var args = ["-O", file + ".tmp", "--tries", "3", "--no-check-certificate", baseURL + fileUrl ];
			if( Sys.command("wget", args) < 0 )
				return null;

		} else {

			if( Sys.command("wget", ["-O", file + ".tmp", "--tries", "3", "--no-check-certificate", fileUrl]) < 0 )
				return null;
		}
		sys.FileSystem.rename(file + ".tmp", file);
		return sys.io.File.getBytes(file);
	}

	function fetchData( g : GameInfos ) {
		if( g.data == null ) throw "Missing data for #" + g.uid;

		var l = g.data.links[0];
		if( l == null ) {
			log("Not link for #" + g.uid);
			return;
		}
		var url = StringTools.htmlUnescape(l.url);
		var dat = dataFile(g);

		if( sys.FileSystem.exists(dat) ) return;

		// force direct DL on dropbox
		if( StringTools.startsWith(url, "https://www.dropbox.com/") && url.split("?").length == 1 )
			url += "?dl=1";

		log("Saving " + g.title+"#" + g.uid + " (" + l.title + ") " + progress(g));

		try sys.FileSystem.deleteFile(dat + ".tmp") catch( e : Dynamic ) {};

		if( Sys.command("wget", ["-O", dat + ".tmp", "--tries", "3", "--no-check-certificate", url]) < 0 )
			return;

		sys.FileSystem.rename(dat + ".tmp", dat);
	}

	function fetchGameDatas() {
		var out = new neko.vm.Deque();
		var wait = new neko.vm.Deque();
		for( g in games )
			out.add(g);
		for( i in 0...3 )
			neko.vm.Thread.create(function() {
				while( true ) {
					var g = out.pop(false);
					if( g == null ) break;
					fetchData(g);
				}
				wait.add(null);
			});
		// wait
		for( i in 0...3 )
			wait.pop(true);
	}

	function cleanSpecial() {
		for( g in games ) {
			if( g.data == null || g.data.links.length == 0 ) continue;
			var url = g.data.links[0].url;

			if( StringTools.startsWith(url, "https://www.dropbox.com/") && url.split("?").length == 1 )
				try sys.FileSystem.deleteFile(dataFile(g)) catch( e : Dynamic ) { };
		}
	}

	static function main() {
		try {
			var m = new Main();
			var i = 0;
			var args = Sys.args();
			while( i < args.length ) {
				switch( args[i++] ) {
				case x if( ~/^[0-9]+$/.match(x) ):
					m.load(Std.parseInt(x));
				case "-norank":
					m.rankings = false;
				case "cleanSpecial":
					m.cleanSpecial();
				case "fetch":
					if( m.ld == null ) throw "Missing #LD";
					m.fetch();
				case "data":
					if( m.ld == null ) throw "Missing #LD";
					if( !sys.FileSystem.exists(m.dataDir) ) sys.FileSystem.createDirectory(m.dataDir);
					m.fetchGameDatas();
				case "only":
					var gd = Std.parseInt(args[i++]);
					for( g in m.games )
						if( g.uid == gd ) {
							m.games = [g];
							m.dbFile = null; // no save!
							break;
						}
					if( m.games.length > 1 ) throw "Game #"+gd+" not found";
				case "overall":
					var rank = Std.parseInt(args[i++]);
					var sel = [];
					for( g in m.games )
						if( g.data != null && g.data.rankings[Overall.toInt()] != null && g.data.rankings[Overall.toInt()] <= rank )
							sel.push(g);
					m.dbFile = null; // no save!
					m.games = sel;
				case "categorize":
					if( m.ld == null ) throw "Missing #LD";
					var stats = new Stats();
					for( g in m.games ) {
						var c = m.categorize(g);
						stats.add(g);
						if( stats.count % 100 == 0 ) m.save();
					}
					m.save();
					Sys.println("----------------------------------------------------------------");
					Sys.println(stats.toString());
				case "stats":
					var stats = new Stats();
					for( g in m.games )
						stats.add(g);
					Sys.println(stats.toString());
				case x:
					throw "Unknow arg " + x;
				}
			}
			if( m.games != null )
				m.log("Done "+m.games.length+" games");
		} catch( e : Dynamic ) {
			var str = Std.string(e);
			sys.io.File.saveContent("error.log", str);
			if( str.length > 500 ) e = str.substr(0, 500) + "...";
			neko.Lib.rethrow(e);
		}
	}

}