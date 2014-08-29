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
	public function toInt() return this;
}

typedef GameInfos = {
	var uid : Int;
	var img : String;
	var title : String;
	var user : String;
	@:optional var data : GameData;
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
		dbFile = "ld" + ld + ".dat";
		games = try haxe.Json.parse(sys.io.File.getContent(dbFile)) catch( e : Dynamic ) [];
	}

	function loadData() {
		dataDir = "ld" + ld + "_data";
		if( !sys.FileSystem.exists(dataDir) ) sys.FileSystem.createDirectory(dataDir);
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

		for( i in 0...games.length )
			fetchGame(games[i], i);

		log("Done "+games.length+" games");
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

	function fetchGame( g : GameInfos, i : Int ) {
		if( g.data != null ) return;
		log("Fetching " + g.title+"#" + g.uid+" "+(Std.int(i*1000/games.length)/10)+"%");
		var h = get("http://www.ludumdare.com/compo/ludum-dare-"+ld+"/?action=preview&uid=" + g.uid);
		var links = [];
		var linkData = extract(h, ~/<p class='links'>(.*?)<\/p>/).split("<a ");
		linkData.shift();
		for( l in linkData ) {
			var r = ~/href="([^"]+)" target='_blank'>([^<]+)<\/a>/;
			if( !r.match(l) ) throw "Invalid link #"+l+"# in " + linkData;
			links.push( { url : r.matched(1), title : utf(r.matched(2)) } );
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
		sys.io.File.saveContent(dbFile, haxe.Json.stringify(games, null, "\t"));
	}

	function fetchData( g : GameInfos, i : Int ) {
		if( g.data == null ) throw "Missing data for #" + g.uid;

		var l = g.data.links[0];

		var url = StringTools.htmlUnescape(l.url);


		var ext = url.split("/").pop().split(".");
		var ext = if( ext.length == 1 ) "html" else ext.pop().toLowerCase();

		if( ext.length < 2 || !~/^[a-z]+$/.match(ext) ) ext = "html";

		switch( ext ) {
		case "exe", "com", "bat": ext += "_";
		default:
		}

		var dat = dataDir + "/" + g.uid + "." + ext;

		if( sys.FileSystem.exists(dat) ) return;

		log("Saving " + g.title+"#" + g.uid + " (" + l.title + ") "+(Std.int(i*1000/games.length)/10)+"%");


		try sys.FileSystem.deleteFile(dat + ".tmp") catch( e : Dynamic ) {};

		if( Sys.command("wget", ["-O", dat + ".tmp", "--tries", "3", url]) < 0 )
			return;

		sys.FileSystem.rename(dat + ".tmp", dat);

	}

	function fetchGameDatas() {
		var out = new neko.vm.Deque();
		var wait = new neko.vm.Deque();
		for( i in 0...games.length )
			out.add(i);
		for( i in 0...3 )
			neko.vm.Thread.create(function() {
				while( true ) {
					var g = out.pop(false);
					if( g == null ) break;
					fetchData(games[g], g);
				}
				wait.add(null);
			});
		// wait
		for( i in 0...10 )
			wait.pop(true);
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
				case "fetch":
					if( m.ld == null ) throw "Missing #LD";
					m.fetch();
				case "data":
					if( m.ld == null ) throw "Missing #LD";
					m.loadData();
					m.fetchGameDatas();
				case x:
					throw "Unknow arg " + x;
				}
			}
		} catch( e : Dynamic ) {
			var str = Std.string(e);
			sys.io.File.saveContent("error.log", str);
			if( str.length > 500 ) e = str.substr(0, 500) + "...";
			neko.Lib.rethrow(e);
		}
	}

}