package form;

/**
 * Use this to fill some custom HTML between form elements
 */
class RawHtml extends sugoi.form.FormElement<String> {
	var html:String;

	public function new(name:String, html:String) {
		this.name = name;
		this.html = html;
		super();
	}

	override public function render() {
		return html;
	}

	override public function getTypedValue(str:String):String {
		return null;
	}

	override function getFullRow():String {
		return this.html;
	}
}
