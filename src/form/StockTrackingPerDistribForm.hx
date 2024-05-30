package form;

import sugoi.form.FormElement;
import sugoi.form.ListData.FormData;
import sugoi.form.elements.RadioGroup;
import Common;

class StockTrackingPerDistribForm extends FormElement<Int> {
	public var enumStrings:Array<String> = new Array<String>();

	public function new(name:String, label:String, value:Int) {
		super();
		this.name = name;
		this.label = label;
		this.value = value;
		this.enumStrings = Type.getEnumConstructs(StockTrackingPerDistribution);
	}

	override public function render():String {
		var _ = sugoi.i18n.Locale.texts.get;

		var n = parentForm.name + "_" + name;
		var s = '<div id="' + parentForm.name + '_StockTrackingPerDistribFormContainer" class="flex-col">';

		var c = 0;
		for (enumString in this.enumStrings) {
			var isChecked = c == this.value;
			var radio = '<input type="radio" name="${n}" id="${n + c}" value="${Std.string(c)}" ${isChecked ? "checked" : ""} ${c > 0 ? "disabled" : ""}/>\n';
			s += '<label for="${n + c}" style="display: inline-block;color:${c > 0 ? "gray" : "inherit"}">${radio} ${App.t._(enumString)}</label>';
			c++;
		}
		s += '</div>';
		s += '
<script type="text/javascript">
	_Camap.InitStockTrackingComponent("'+parentForm.name+'");
</script>';

		return s;
	}

	override function getTypedValue(str:String):Int {
		if (str == null)
			return null;
		str = StringTools.trim(str);
		var value = Std.parseInt(str);
		if (value == null)
			return null;
		if (value >= 0 && value < this.enumStrings.length)
			return value;
		return null;
	}

	override function getValue():Int {
		if (value == null)
			return null;
		return cast StockTrackingPerDistribution.createByIndex(value);
	}
}
