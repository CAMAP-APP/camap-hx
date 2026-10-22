package tools;

class StringTool {

	static var ACCENTS = [
		"a" => ["à", "á", "â", "ã", "ä", "å", "À", "Á", "Â", "Ã", "Ä", "Å"],
		"ae" => ["æ", "Æ"],
		"c" => ["ç", "Ç"],
		"e" => ["è", "é", "ê", "ë", "È", "É", "Ê", "Ë"],
		"i" => ["ì", "í", "î", "ï", "Ì", "Í", "Î", "Ï"],
		"n" => ["ñ", "Ñ"],
		"o" => ["ò", "ó", "ô", "õ", "ö", "ø", "Ò", "Ó", "Ô", "Õ", "Ö", "Ø"],
		"oe" => ["œ", "Œ"],
		"u" => ["ù", "ú", "û", "ü", "Ù", "Ú", "Û", "Ü"],
		"y" => ["ý", "ÿ", "Ý", "Ÿ"],
	];

	/**
	 * Lowercase and accent-free version of a string, to be used as a sorting key
	 */
	public static function toSortingKey(s:String):String {
		if (s == null) return "";
		for (plain => accented in ACCENTS) {
			for (a in accented) s = StringTools.replace(s, a, plain);
		}
		return s.toLowerCase();
	}

	/**
	 * Alphabetical comparison, ignoring case and accents
	 */
	public static function compare(a:String, b:String):Int {
		return Reflect.compare(toSortingKey(a), toSortingKey(b));
	}
}
