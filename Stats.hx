import Categorize;
import Main;

class Stats {

	public var count : Int;
	var missingData : Int;
	var techs : Map<String,{ t : Techno, count : Int, libs : Map<String,Int> }>;

	public function new() {
		count = 0;
		missingData = 0;
		techs = new Map();
	}

	public function add( g : GameInfos ) {
		if( g.cat == null )
			missingData++;
		else
			addTech(g.cat.tech, g.cat.lib);
	}

	function addTech( tech : Techno, lib : Library ) {
		if( tech == null ) tech = Unknown;
		var inf = techs.get(tech.toString());
		if( inf == null ) {
			inf = { t : tech, count : 0, libs : new Map() };
			techs.set(tech.toString(), inf);
		}
		if( lib != null ) {
			var lib = lib.toString();
			var n = inf.libs.get(lib);
			if( n == null ) n = 0;
			n++;
			inf.libs.set(lib, n);
		}
		inf.count++;
		count++;
	}

	public function toString() {

		inline function pc(v:Float) {
			return StringTools.lpad(Std.int(v * 100) + "." + (Std.int(v * 1000) % 10) + "%", " ", 5);
		}
		inline function num(v:Int) {
			return StringTools.lpad("" + v, " ", 4);
		}
		inline function title(s:String) {
			return StringTools.rpad(s, " ", 40);
		}

		var totalGames = missingData + count;
		var lines = [];
		lines.push(title("Games which we didn't download") + " "+num(missingData) + " " + pc(missingData / totalGames));
		var tech = Lambda.array(techs);
		tech.sort(function(t1, t2) return t2.count - t1.count);

		var unk = [];
		var knownGames = 0;
		for( t in tech )
			switch( t.t ) {
			case Unknown, CantDownloadDirectly, NotAvailable:
				unk.push(t);
			default:
				knownGames += t.count;
			}
		for( u in unk ) {
			tech.remove(u);
			var k;
			switch( u.t ) {
			case Unknown:
				k = "Technology could not be detected";
			case NotAvailable:
				k = "Game Data is not available (404, etc.)";
			case CantDownloadDirectly:
				k = "We don't know how to download game data";
			default:
				k = "????" + u.t.toString();
			}
			lines.push(title(k) + " " + num(u.count) + " " + pc(u.count / totalGames));
			for( l in u.libs.keys() )
				if( l != "null" )
					lines.push("LIB " + l + "=" + u.libs.get(l) + " FOUND ?");
		}

		lines.push(title("Games that we have detected") + " " + num(knownGames) + " " + pc(knownGames / totalGames));
		lines.push("--- used technologies ---");
		for( t in tech ) {
			lines.push(StringTools.rpad(t.t.toString(), " ", 20) + " " + num(t.count) + " " + pc(t.count / knownGames));
			var libs = [for( l in t.libs.keys() ) { l : l, n : t.libs.get(l) } ];
			libs.sort(function(l1, l2) return l2.n - l1.n);
			for( l in libs )
				lines.push("    " + StringTools.rpad(l.l, " ", 16) + " " + num(l.n) + " " + pc(l.n / knownGames));
		}

		return lines.join("\n");
	}

}