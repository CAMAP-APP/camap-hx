package tools;

import tink.core.Error;

/**
 * Date tool
 * @author fbarbut
 */
class DateTool {
	private static var utcFrOffsetRanges = [
		[
			new Date(2019, 3 - 1, 31, 1, 0, 0).getTime(),
			new Date(2019, 10 - 1, 27, 1, 0, 0).getTime()
		],
		[
			new Date(2020, 3 - 1, 29, 1, 0, 0).getTime(),
			new Date(2020, 10 - 1, 25, 1, 0, 0).getTime()
		],
		[
			new Date(2021, 3 - 1, 28, 1, 0, 0).getTime(),
			new Date(2021, 10 - 1, 31, 1, 0, 0).getTime()
		],
		[
			new Date(2022, 3 - 1, 27, 1, 0, 0).getTime(),
			new Date(2022, 10 - 1, 30, 1, 0, 0).getTime()
		],
		[
			new Date(2023, 3 - 1, 26, 1, 0, 0).getTime(),
			new Date(2023, 10 - 1, 29, 1, 0, 0).getTime()
		],
		[
			new Date(2024, 3 - 1, 31, 1, 0, 0).getTime(),
			new Date(2024, 10 - 1, 27, 1, 0, 0).getTime()
		],
	];

	public static function now():Date {
		return Date.now();
	}

	public static function deltaDays(d:Date, n:Int):Date {
		return DateTools.delta(d, n * 1000 * 60 * 60 * 24.0);
	}

	public static function setHourMinute(d:Date, hour:Int, minute:Int):Date {
		return new Date(d.getFullYear(), d.getMonth(), d.getDate(), hour, minute, 0);
	}

	public static function setDateMonth(d:Date, date:Int, month:Int):Date {
		return new Date(d.getFullYear(), month, date, d.getHours(), d.getMinutes(), 0);
	}

	public static function setYear(d:Date, year:Int):Date {
		return new Date(year, d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), 0);
	}

	public static function getLastHourRange(?now:Date) {
		if (now == null)
			now = Date.now();
		var HOUR = 1000.0 * 60 * 60;
		var to = setHourMinute(now, now.getHours(), 0);
		var from = DateTools.delta(to, -HOUR);
		return {from: from, to: to};
	}

	public static function getLastMinuteRange(?now:Date) {
		if (now == null)
			now = Date.now();
		var MIN = 1000.0 * 60;
		var to = setHourMinute(now, now.getHours(), now.getMinutes());
		var from = DateTools.delta(to, -MIN);
		return {from: from, to: to};
	}

	public static function getLastDayRange(?now:Date) {
		if (now == null)
			now = Date.now();
		var from = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 0, 0, 0);
		var to = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 23, 59, 59);
		return {from: from, to: to};
	}

	public static function getWhichNthDayOfMonth(date:Date):Int {
		return Math.floor((date.getDate() - 1) / 7) + 1;
	}

	public static function getNthDayOfMonth(year:Int, month:Int, dayOfWeek:Int, n:Int):Date {
		// dayOfWeek and getDay() follow the same value system: from 0 (Sunday) to 6 (Saturday)
		return deltaDays(new Date(year, month, 1 + 7 * n, 0, 0, 0), -new Date(year, month, 8 - (dayOfWeek + 1), 0, 0, 0).getDay() - 1);
	}

	// convert UTC JS date to Haxe french date
	public static function fromJs(value:String) {
		//no need to convert
		if( value.indexOf("T")==-1){
			return Date.fromString(value);
		}

		var d = value.split("T").join(" ");
		d = d.substr(0, d.indexOf("."));
		var utcTime = Date.fromString(d).getTime();

		if (utcTime < DateTool.utcFrOffsetRanges[0][0] || utcTime > DateTool.utcFrOffsetRanges[DateTool.utcFrOffsetRanges.length - 1][1]) {
			throw new Error(500, "DateTool.fromJs out of range");
		}

		var founded = Lambda.find(DateTool.utcFrOffsetRanges, function(range) {
			return utcTime > range[0] && utcTime < range[1];
		});
		var hourToAdd = 1;
		if (founded != null) {
			hourToAdd = 2;
		}

		return Date.fromTime(utcTime + (hourToAdd * 3600 * 1000));
	}

	public static function toJs(value:Date) {
		var time = value.getTime();

		if (time < DateTool.utcFrOffsetRanges[0][0] || time > DateTool.utcFrOffsetRanges[DateTool.utcFrOffsetRanges.length - 1][1]) {
			throw new Error(500, "DateTool.toJs out of range");
			return null;
		}

		var founded = Lambda.find(DateTool.utcFrOffsetRanges, function(range) {
			return time > range[0] && time < range[1];
		});
		var hourToSub = 1;
		if (founded != null) {
			hourToSub = 2;
		}

		var utc = Date.fromTime(time - (hourToSub * 3600 * 1000));

		var reg = ~/ /;

		return reg.replace(utc.toString(), "T") + ".000Z";
	}
}
