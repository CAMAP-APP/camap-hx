package form;

import sugoi.form.Form;
import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;

typedef FieldTypeToElementMap = Map<String, (name: String, label: String, value: Dynamic, ?required: Bool) -> Dynamic>;

class CamapForm extends Form {

	override public static function fromSpod(obj:sys.db.Object, ?customMap:FieldTypeToElementMap) {
    	var fieldTypeToElementMap:FieldTypeToElementMap = null;
    	if(customMap!=null){
      		fieldTypeToElementMap = customMap;
    	}else{
      		fieldTypeToElementMap = new FieldTypeToElementMap();
      		fieldTypeToElementMap["DDate"] = CamapForm.renderDDate;
      		fieldTypeToElementMap["DTimeStamp"] = CamapForm.renderDTimeStamp;
      		fieldTypeToElementMap["DDateTime"] = CamapForm.renderDTimeStamp;
    	}
        return sugoi.form.Form.fromSpod(obj, fieldTypeToElementMap);
  	}

	public static function addRichText(form:Form, selector:String)
	{
		if (form.getElement('richtext') != null)
			throw new thx.Error('richtext already added to form.');
		form.addElement(new form.RawHtml("richtext", '
<script src="/js/tinymce/tinymce.min.js"></script>
<script>
	tinymce.init({ 
		selector: "${selector}",
		plugins: "autolink emoticons image code link lists",
		toolbar: "bold italic alignleft aligncenter emoticons image bullist numlist outdent indent forecolor link code",
		language: "${App.current.session.lang}",
		menubar: false,
		statusbar: false,
		license_key: "gpl"
	});
</script>
'));
	}


	public static function renderDDate(name: String, label: String, value: Dynamic, ?required: Bool) {
		// hack
		var namesToOpenInYear = ['birthdate','birthday'];
		var openTo = "date";
		if (namesToOpenInYear.indexOf(name.toLowerCase()) != -1) {
			openTo = "year";
		}

		return new form.CamapDatePicker(name, label, value, NativeDatePickerType.date, required, "", openTo);
	}

	public static function renderDTimeStamp(name: String, label: String, value: Dynamic, ?required: Bool) {
		return new form.CamapDatePicker(name, label, value, NativeDatePickerType.datetime, required);
	}
}