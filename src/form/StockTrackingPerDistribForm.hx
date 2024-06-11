package form;

import db.ProductDistributionStock;
import sugoi.form.elements.StringInput;
import sugoi.form.elements.Selectbox;
import sugoi.form.Form;
import sugoi.form.FormElement;
import sugoi.form.ListData.FormData;
import sugoi.form.elements.RadioGroup;
import Common;

class StockTrackingPerDistribForm extends FormElement<Int> {
	public var stockElement:FormElement<Dynamic>;
	public var distributionsStocks:List<db.ProductDistributionStock>;
	public var distribs:List<db.Distribution>;
	public var enumStrings:Array<String> = new Array<String>();

	public function new(name:String, label:String, value:Int, stockElement:FormElement<Dynamic>, distributionsStocks:List<db.ProductDistributionStock>,
			distribs:List<db.Distribution>) {
		super();
		this.name = name;
		this.label = label;
		this.value = value;
		this.stockElement = stockElement;
		this.distributionsStocks = distributionsStocks;
		this.distribs = distribs;
		this.enumStrings = Type.getEnumConstructs(StockTrackingPerDistribution);
	}

	override function isValid():Bool {
		var regularValid = super.isValid();

		// additional validation
		var additionValid = true;
		if (this.value == AlwaysTheSame.getIndex()) {
			if (Math.isNaN(Std.parseFloat(App.current.params.get(parentForm.name + "_stock_AlwaysTheSame")))) {
				this.errors.add("<span class=\"formErrorsField\">\"" + ((label != null && label != "") ? label : name) + "\"</span>: le stock doit être un nombre.");
				additionValid = false;
			}
		}
		if (this.value == FrequencyBased.getIndex()) {
			if (Math.isNaN(Std.parseFloat(App.current.params.get(parentForm.name + "_stock_FrequencyBased")))) {
				this.errors.add("<span class=\"formErrorsField\">\"" + ((label != null && label != "") ? label : name) + "\"</span>: le stock doit être un nombre.");
				additionValid = false;
			}
			if (Math.isNaN(Std.parseInt(App.current.params.get(parentForm.name + "_firstDistrib")))) {
				this.errors.add("<span class=\"formErrorsField\">\"" + ((label != null && label != "") ? label : name) + "\"</span>: la date de début de l'alternance des stocks est obligatoire.");
				additionValid = false;
			}
			if (Math.isNaN(Std.parseInt(App.current.params.get(parentForm.name + "_frequencyRatio")))) {
				this.errors.add("<span class=\"formErrorsField\">\"" + ((label != null && label != "") ? label : name) + "\"</span>: il faut choisir un fréquence d'alternance des stocks (1/2, 1/3 ou 1/4).");
				additionValid = false;
			}
		}
		if (this.value == PerPeriod.getIndex()) {
			var startDistribs = neko.Web.getParamValues(parentForm.name + "_startDistributionId");
			var endDistribs = neko.Web.getParamValues(parentForm.name + "_endDistributionId");
			var stocks = neko.Web.getParamValues(parentForm.name + "_stockPerDistribution");
			if (startDistribs.length != stocks.length || endDistribs.length != stocks.length) {
				this.errors.add("<span class=\"formErrorsField\">\"" + ((label != null && label != "") ? label : name) + "\"</span>: une erreur est survenue au niveau de la définition des périodes. Chaque période doit comporter une distribution de début, de fin et un stock.");
				additionValid = false;
			}
			for (i in 0...stocks.length) {
				if (Math.isNaN(Std.parseFloat(stocks[i]))) {
					this.errors.add('<span class="formErrorsField">"${(label != null && label != "") ? label : name} > Stock [${i}]"</span>: le stock doit être un nombre.');
					additionValid = false;
				}
			}
		}

		return regularValid && additionValid;
	}

	override function getFullRow():String {
		var s = new StringBuf();
		if (Form.USE_TWITTER_BOOTSTRAP) s.add('<div class="form-group">\n');
		s.add('<div class="col-sm-2"></div>');
		s.add(this.render());
		// s.add('</div>\n');
		if (Form.USE_TWITTER_BOOTSTRAP) s.add('</div>\n');
		return s.toString();
	}

	override public function render():String {
		var _ = sugoi.i18n.Locale.texts.get;

		var n = parentForm.name + "_" + name;
		var s = '<div id="' + parentForm.name + '_stockTrackingPerDistribFormContainer" class="flex-col col-sm-10">';

		// identique à chaque distrib
		var choiceIdx:Int = StockTrackingPerDistribution.AlwaysTheSame.getIndex();
		var isChecked = choiceIdx == this.value;
		var radio = '<input type="radio" name="${n}" id="${n}_AlwaysTheSame" value="${choiceIdx}" style="margin-right: 6px;" ${isChecked ? "checked" : ""} />';
		s += '<label for="${n}_AlwaysTheSame" style="display: inline-block;">${radio} ${choiceIdx+1}. ${App.t._(StockTrackingPerDistribution.AlwaysTheSame.getName())}</label>';
		s += '<fieldset id="${n}_AlwaysTheSame_fieldset" disabled="disabled" style="padding:12px 24px;">';
		s += '	<div>${App.t._("A chaque distribution, le stock défini sera disponible à la vente.")}</div>';
		var alwaysTheSameStockElem = new StringInput("stock_AlwaysTheSame", stockElement.label, stockElement.value, stockElement.required);
		alwaysTheSameStockElem.parentForm = parentForm;
		s += '	<div class="flex-row"><label for="${parentForm.name}_stock_AlwaysTheSame" class="control-label" style="padding-right: 16px;">${alwaysTheSameStockElem.label}</label>' +  alwaysTheSameStockElem.render() + '</div>';
		s += '</fieldset>';

		// à fréquence régulière
		choiceIdx = StockTrackingPerDistribution.FrequencyBased.getIndex();
		isChecked = choiceIdx == this.value;
		var radio = '<input type="radio" name="${n}" id="${n}_FrequencyBased" value="${choiceIdx}" style="margin-right: 6px;" ${isChecked ? "checked" : ""} />';
		s += '<label for="${n}_FrequencyBased" style="display: inline-block;">${radio} ${choiceIdx+1}. ${App.t._(StockTrackingPerDistribution.AlwaysTheSame.getName())}</label>';
		s += '<fieldset id="${n}_FrequencyBased_fieldset" disabled="disabled" style="padding:12px 24px;display:flex;flex-direction:column;gap:8px;margin-bottom:16px;">';
		s += '	<div>${App.t._("Le stock définit ici sera disponible uniquement à la fréquence choisir et égal à 0 sinon.")}<br/>';
		s += '	${App.t._("La date de départ permet de choisir la première date de distribution où le produit est disponible.")}</div>';
	
		// 		Choix de la distrib de début d'alternance
		var distribsData = Lambda.map(this.distribs, function(c) return {label:c.date.toString().substr(0, 10),value: Std.string(c.id)} ).array();
		var selectedDistrib = distributionsStocks.length > 0 ? Std.string(distributionsStocks.first().startDistribution.id) : null;
		var distribSelector = new Selectbox("firstDistrib", "Date de départ de l'alternance", distribsData, selectedDistrib, false, "");
		distribSelector.parentForm = this.parentForm;
		s += '	<div class="flex-row"><label for="${parentForm.name}_firstDistrib" class="control-label" style="padding-right: 16px;white-space:nowrap;">${distribSelector.label}</label>${distribSelector.render()}</div>';

		//  	Stock pour l'alternance
		var frequencyBasedStockElem = new StringInput("stock_FrequencyBased", stockElement.label, stockElement.value, stockElement.required);
		frequencyBasedStockElem.parentForm = parentForm;
		s += '	<div class="flex-row"><label for="${parentForm.name}_stock_FrequencyBased" class="control-label" style="padding-right: 16px; white-space:nowrap;">${frequencyBasedStockElem.label}</label>${frequencyBasedStockElem.render()}</div>';

		//  	Choix de la fréquence
		var freqRadioName = parentForm.name + "_frequencyRatio";
		s += '<div class="flex-row">';
		s += '	<label for="${freqRadioName}" class="control-label" style="padding-right: 16px; width: 350px;text-align:left;">${App.t._("Fréquence choisie (1/2 = 1 distribution sur 2 à partir de la Date de départ de l'alternance)")}</label>';
		var frequencies = [2,3,4]; // 1/2, 1/3, 1/4.
		for (freq in frequencies) {
			var isFreqChecked = distributionsStocks.length > 0 && distributionsStocks.first().frequencyRatio == freq;
			var radio = '<input type="radio" name="${freqRadioName}" id="${freqRadioName + freq}" value="${freq}" style="margin-right: 6px;" ${isFreqChecked ? "checked" : ""}/>\n';
			s += '<label for="${freqRadioName + freq}" style="margin-right: 14px;display:inline-block;align-self: center;">1/${freq} ${radio}</label>';
		}
		s += '</div>';
		s += '</fieldset>';

		
		// Par période
		choiceIdx = StockTrackingPerDistribution.PerPeriod.getIndex();
		isChecked = choiceIdx == this.value;
		var radio = '<input type="radio" name="${n}" id="${n}_PerPeriod" value="${choiceIdx}" style="margin-right: 6px;" ${isChecked ? "checked" : ""} />';
		s += '<label for="${n}_PerPeriod" style="display: inline-block;">${radio} ${choiceIdx+1}. ${App.t._(StockTrackingPerDistribution.PerPeriod.getName())}</label>';
		s += '<fieldset id="${n + "_PerPeriod_fieldset"}" disabled="disabled" style="padding:12px 24px;">';
		s += '	<div>${App.t._("Vous pouvez définir ici une ou plusieurs périodes pour lesquelles indiquer un stock disponible à chaque distribution. Le stock des distributions non incluses dans les périodes définies sera égale à 0.")}</div>';
		s += '	<button type="button" class="btn btn-primary btn-noAntiDoubleClick" id="${n}_addPeriodButton" style="margin: 12px 0;">${_("Add period")}</button>';
		s += '<div class="periods">';
		var c = 0;
		if (distributionsStocks.length == 0) {
			var initial = new ProductDistributionStock();
			initial.stockPerDistribution = stockElement.value;
			initial.startDistribution = this.distribs.first();
			initial.endDistribution = this.distribs.last();
			distributionsStocks.add(initial);
		}
		for (distribStock in distributionsStocks) {
			s += '<div class="flex-row stockTrackingPeriod" style="align-items:center;gap:8px;margin: 6px 0">Du ';
			s += renderDistribSelect('Première distribution de la période ${c+1}', '${parentForm.name}_startDistributionId[${c}]','${parentForm.name}_startDistributionId[]', distribsData, Std.string(distribStock.startDistribution.id));
			s += ' Au ';
			s += renderDistribSelect('Dernière distribution de la période ${c+1}', '${parentForm.name}_endDistributionId[${c}]','${parentForm.name}_endDistributionId[]', distribsData, Std.string(distribStock.endDistribution.id));
			var periodStockElem = new StringInput('stockPerDistribution[]', stockElement.label, Std.string(distribStock.stockPerDistribution), stockElement.required);
			periodStockElem.parentForm = parentForm;
			s += '	<label for="${parentForm.name}_stockPerDistribution[]" class="control-label" style="white-space:nowrap;">${periodStockElem.label}</label>${periodStockElem.render()}';
			s += '	<button type="button" class="btn btn-primary" onclick="(e=>{e.preventDefault();e.currentTarget.parentElement.remove();})(event)">${_("Remove")}</button>';
			s+= '</div>';
			c++;
		}
		s += '</div>';
		s += '</fieldset>';


		s += '</div>';
		s += '
<script type="text/javascript">
	_Camap.InitStockTrackingComponent("'+parentForm.name+'", "'+name+'");
</script>';
		s += '
<style>
	fieldset[disabled="disabled"] {opacity: 0.5;}
	.stockTrackingPeriod:only-child button {display:none;}
</style>';
		return s;
	}

	function renderDistribSelect(title: String, id:String, name:String, data:Array<{label:String,value:String}>, selectedValue:String) {
		var s = "";
		s += '\n<select name="${name}" id="${id}" class="form-control" title="${title}" />';

		if (data != null){	
			for (row in data) {
				s += '<option value="${row.value}" ${row.value == selectedValue ? "selected":""}>${row.label}</option>';
			}
		}
		s += "</select>";

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
