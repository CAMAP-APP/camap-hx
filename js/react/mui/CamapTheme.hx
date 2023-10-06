package react.mui;

import classnames.ClassNames.fastNull as classNames;
import mui.icon.Icon;
import react.ReactMacro.jsx;
import mui.core.Typography;
import js.Object;
import Common;

@:enum 
abstract CGColors(String) to String {
	var Primary = "#eb702f";
	var Secondary = "#eb702f";

	var White = "#FFFFFF";

	var Bg1 = "#FFFFFF"; // "#E5D3BF"; //light greyed-pink-purple
	var Bg2 = "#FFFFFF"; // "#F8F4E5"; //same but lighter
	var Bg3 = "#FFFFFF"; // "#F2EBD9"; //used for active category BG

	var DarkGrey = "#404040";//ex first font
	var MediumGrey = "#7F7F7F";//ex second font
	var LightGrey = "#DDDDDD";
}

// This is not complete but exposes what we are currently using of the theme
typedef Theme = {
	var mixins:Mixins;
	var palette:ColorPalette;
	var spacing:Spacings;
	var zIndex:ZIndexes;
}

typedef Spacings = {
	var unit:Int;
}

typedef Mixins = {
	var appBar:Object;
	var leftPanel:Object;
}

@:enum abstract PaletteType(String) from String to String {
	var Light = "light";
	var Dark = "dark";
}

typedef ColorPalette = {
	var type:PaletteType;
	var contrastThreshold:Int;
	var tonalOffset:Float;
	var getContrastText:haxe.Constraints.Function;
	var augmentColor:haxe.Constraints.Function;

	var primary:Dynamic;
	var secondary:Dynamic;
	var error:Dynamic;
	var action:Dynamic;

	var cgColors: CGColors;

	var divider:String;

	var background:{
		paper:String,
		dark:String,

		cgBg01:CGColors,
		cgBg02:CGColors,
		cgBg03:CGColors,
	};

	var text:{
		primary:String,
		secondary:String,
		disabled:String,
		hint:String,
		// custom values
		inverted: String,
		cgFirstfont: CGColors,
		cgSecondfont: CGColors,
	};

	var common:{
		black:String,
		white:String
	};

	// custom values
	var indicator:IndicatorsPalette;
}

typedef IndicatorsPalette = {
	var green:String;
	var yellow:String;
	var orange:String;
	var red:String;
}

typedef ZIndexes = {
	var mobileStepper:Int;
	var appBar:Int;
	var drawer:Int;
	var modal:Int;
	var snackbar:Int;
	var tooltip:Int;
}

class CamapTheme{

	public static function get(){
		return mui.core.styles.MuiTheme.createMuiTheme({
			palette: {
				primary: 	{main: cast CGColors.Primary},
				secondary: 	{main: cast CGColors.Secondary},
			},
			typography: {
				fontFamily:['Cabin', 'icons', '"Helvetica Neue"','Arial','sans-serif',],
				fontSize:16, 
			},
			overrides: {
				MuiButton: { // Name of the component ⚛️ / style sheet
					root: { // Name of the rule
						minHeight: 'initial',
						minWidth: 'initial',
					},
                },
                MuiCssBaseline: {
                    "@global": {
                        body: {
                            backgroundColor: CGColors.Bg2
                        }
                    }
                  },
			},
		});
	}

	/**
        Get a mui Icon using Camap's icon font
    **/
    public static function getIcon(iconId:String,?style:Dynamic){
        var classes = {'icons':true};
        Reflect.setField(classes,"icon-"+iconId,true);
        var iconObj = classNames(classes);
        return jsx('<Icon component="i" className=${iconObj} style=$style></Icon>');
    }

}
