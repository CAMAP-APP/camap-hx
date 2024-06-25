package;
import Common;
using Std;

/**
 * Formatting tools used on both client and server side.
 * 
 * @author fbarbut
 */
class Formatting
{
	
	public static function formatNum(n:Float):String {
		if (n == null) return "";
		
		//arrondi a 2 apres virgule
		var out  = Std.string(roundTo(n, 2));		
		
		//ajout un zéro, 1,8-->1,80
		if (out.indexOf(".")!=-1 && out.split(".")[1].length == 1) out = out +"0";
		
		//virgule et pas point
		return out.split(".").join(",");
	}
	
	
	/**
	 * Round a number to r digits after coma.
	 */
	public static function roundTo(n:Float, r:Int):Float {
		return Math.round(n * Math.pow(10,r)) / Math.pow(10,r) ;
	}

	public static function parseFloat(s:String):Float{
		if(s.indexOf(",")>0){
			return Std.parseFloat(StringTools.replace(s,",","."));
		}else{
			return Std.parseFloat(s);
		}
	}
	
	/**
	 *  Display a unit
	 */
	public static function unit(u:Unit,?quantity=1.0):String{
		/*t = sugoi.i18n.Locale.texts;
		if(u==null) return t._("piece||unit of a product)");
		return switch(u){
			case Kilogram: 	t._("Kg.||kilogramms");
			case Gram: 		t._("g.||gramms");
			case Piece: 	t._("piece||unit of a product)");
			case Litre: 	t._("L.||liter");
			case Centilitre: 	t._("cl.||centiliter");
		}*/

		return switch(u){
			case Kilogram: 	 "Kg.";
			case Gram: 		 "g.";			
			case Litre: 	 "L.";
			case Centilitre: "cl.";
			case Millilitre:"ml.";
			case null,Piece: if(quantity==1.0) "pièce" else "pièces";
			
		}
		
	}

	public static var DAYS    = ["Dimanche","Lundi", "Mardi", "Mercredi","Jeudi", "Vendredi", "Samedi"];
	public static var MONTHS  = ["Janvier","Février","Mars","Avril", "Mai","Juin", "Juillet", "Aout", "Septembre", "Octobre", "Novembre","Décembre"];
	public static var MONTHS_LOWERCASE  = ["janvier","février","mars","avril", "mai","juin", "juillet", "août", "septembre", "octobre", "novembre","décembre"];
	public static var HOURS   = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23];
	public static var MINUTES = [0,5,10,15,20,25,30,35,40,45,50,55];
	
	/**
	 * human readable date + time
	 */
	public static function hDate(date:Date,?year=false):String {
		if (date == null) return "No date set";
		var out = DAYS[date.getDay()] + " " + date.getDate() + " " + MONTHS[date.getMonth()];
		if(year) out += " " + date.getFullYear();
		if ( date.getHours() != 0 || date.getMinutes() != 0){
			out += " à " + StringTools.lpad(Std.string(date.getHours()), "0", 2) + ":" + StringTools.lpad(Std.string(date.getMinutes()), "0", 2);
		}
		return out;
	}

	/**
		date with year
	**/
	public static  function dDate(date:Date):String{
		return DAYS[date.getDay()] + " " + date.getDate() + " " + MONTHS[date.getMonth()] + " " + date.getFullYear();
	}

	public static function hHour(date:Date){
		return StringTools.lpad(date.getHours().string(), "0", 2) + ":" + StringTools.lpad(date.getMinutes().string(), "0", 2);
	}
	
	public static function getDate(date:Date) {
		return {
			dow: DAYS[date.getDay()],
			d : date.getDate(),
			m: MONTHS[date.getMonth()],
			y: date.getFullYear(),			
			h: StringTools.lpad(Std.string(date.getHours()),"0",2),
			i: StringTools.lpad(Std.string(date.getMinutes()),"0",2)
		};
	}

	public static function dayOfWeek(date:Date):String{
		if (date == null) return "No date set";
		return DAYS[date.getDay()];
	}

	public static function month(date:Date):String{
		if (date == null) return "No date set";
		return MONTHS[date.getMonth()];
	}

	/**
		Time from now to date
	**/
	public static function timeToDate(date:Date):String{
		var now = Date.now();
		var diff = date.getTime()/1000 - now.getTime()/1000;
		var str = new StringBuf();
		if(diff>0) str.add("dans ") else str.add("il y a ");
		diff = Math.abs(diff);
		if(diff < 3600){
			//minutes
			str.add( Math.round(diff/60)+" minutes" );
		}else if (diff < 3600*24 ){
			//hours
			str.add( Math.round(diff/3600)+" heures" );
		}else{
			//days
			str.add( Math.round(diff/(3600*24)) +" jours" );
		}
		return str.toString();
	}

	/**
		date like 01/01/2021
	**/
	public static function shortDate(d:Date):String{
		if(d==null) return "unknown date";
		return DateTools.format(d,"%d/%m/%Y");
	}

	public  static function csaShortDate( d : Date ) {
		if ( d == null ) return "Pas de date";
		var date = Formatting.getDate( d );
		if ( date.m == 'Janvier' || date.m == 'Avril' || date.m == 'Octobre' || date.m == 'Novembre' ) {
			return date.dow + "<br/>" + date.d + " " + date.m.substr(0,3) + ".<br/>" + date.y;
		} else if ( date.m == 'Février' || date.m == 'Juillet' || date.m == 'Septembre' || date.m == 'Décembre' ) {
			return date.dow + "<br/>" + date.d + " " + date.m.substr(0,4) + ".<br/>" + date.y;
		}
		return date.dow + "<br/>" + date.d + " " + date.m + "<br/>" + date.y;
	}

	public static  function csaClosingDate( d : Date ) {
		if ( d == null ) return "Pas de date";
		var date = Formatting.getDate( d );
		var closingDate = 'Commandez avant<br/>';
		if ( date.m == 'Janvier' || date.m == 'Avril' || date.m == 'Octobre' || date.m == 'Novembre' ) {
			closingDate += date.dow + " " + date.d + " " + date.m.substr(0,3) + ".";
		} else if ( date.m == 'Février' || date.m == 'Juillet' || date.m == 'Septembre' || date.m == 'Décembre' ) {
			closingDate += date.dow + " " + date.d + " " + date.m.substr(0,4) + ".";
		} else {
			closingDate += date.dow + " " + date.d + " " + date.m;
		}
		closingDate += "<br/>à " + StringTools.lpad( Std.string( d.getHours() ), "0", 2 ) + ":" + StringTools.lpad( Std.string( d.getMinutes() ), "0", 2 );
		return closingDate;
	}


	public static function getFullAddress(p:PlaceInfos){
		if (p==null) return "";
		var str = new StringBuf();
		str.add(p.name+", \n");
		if (p.address1 != null) str.add(p.address1 + ", \n");
		if (p.address2 != null) str.add(p.address2 + ", \n");
		if (p.zipCode != null) 	str.add(p.zipCode);
		if (p.city != null) 	str.add(" "+p.city);
		return str.toString();
	}

	/**
	 * To safely print a string in javascript
	 * @param	str
	 */
	public static function escapeJS( str : String ) {
		if (str == null) return "";
		return str.split("\\").join("\\\\").split("'").join("\\'").split('\"').join('\\"').split("\r").join("\\r").split("\n").join("\\n");
	}

    /**
		If string is not UTF8 encoded, encode it
	**/
	#if sys
	public  static function utf8(str:String):String{
		// var bytes = haxe.io.Bytes.ofString(csvData);
		try{
			// if (!UnicodeString.validate(bytes,Encoding.UTF8)){
			if(!neko.Utf8.validate(str)){
				/*trace("not UTF8");
				csvData = bytes.getString(0,bytes.length,Encoding.RawNative);
				trace(UnicodeString.validate(bytes,Encoding.UTF8));*/
				str = neko.Utf8.encode(str);
				// trace(csvData);
			}
		}catch (e:Dynamic){ }
		return str;
	}

	// public static function color(id:Int) {
	// 	if (id == null) throw "color cant be null";
	// 	//try{
	// 		return intToHex(db.CategoryGroup.COLORS[id]);
	// 	//}catch (e:Dynamic) return "#000000";
	// }
	#end

    /**
		https://www.w3.org/TR/NOTE-datetime
	**/
	public static function dateToIso(date:Date):String{
		var s = date.toString().split(" ").join("T");
		//add timezone
		var tz = "";
		var summer = new Date(date.getFullYear(),2,29,2,0,0);
		var winter = new Date(date.getFullYear(),9,25,3,0,0);
		// var dateStr = date.toString().substr(5);
		var winterTime = false;

		if( date.getTime() < summer.getTime()  ){
			//jan-march
			winterTime = true;
		}else if (  date.getTime() > summer.getTime() && date.getTime() < winter.getTime() )	{			
			//summer
			winterTime = false;
		}else{
			//oct-dec
			winterTime = true;
		}
		
		if(winterTime){
			tz = "+01:00";
		}else{
			tz = "+02:00";
		}

		return s + tz;

	}

	public static function jsonReplacer(key:Dynamic,value:Dynamic){
		if(Std.is(value,Date)){
			return dateToIso(value);
		}else {
			return value;
		}
	}

	public static function mapToObject(map:Map<Int, Map<Int, Float>>):Dynamic {
		if (map == null) return null;
        var result:haxe.DynamicAccess<Dynamic> = new haxe.DynamicAccess();
        for (distribId in map.keys()) {
            var innerMap = map.get(distribId);
            var innerObj:haxe.DynamicAccess<Float> = new haxe.DynamicAccess();
            for (productId in innerMap.keys()) {
                innerObj.set(Std.string(productId), innerMap.get(productId));
            }
            result.set(Std.string(distribId), innerObj);
        }
        return result;
    }

	/**
		strange float bug in neko : creates a new and clean float
	**/
	public static function cleanFloat(f:Float):Float{
		return Std.string(f).parseFloat();
	}
}