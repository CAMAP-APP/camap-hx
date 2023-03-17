package form;

import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;
import sugoi.form.elements.NativeDatePicker;

class CamapDatePicker extends NativeDatePicker {

  public var format: String = "EEEE d MMM yyyy";
  public var openTo: String;

  public function new (
    name:String,
    label:String,
    ?_value:Date,
    ?type: NativeDatePickerType = NativeDatePickerType.date,
    ?required:Bool=false,
    ?attibutes:String="",
    ?openTo:String="day"
  ) {
    super(name, label, _value, type, required, attributes);
    this.openTo = openTo;
  }

  override public function getTypedValue(str:String):Date {
		if(str=="" || str==null) return null;
    return Date.fromString(str);
  }
  
  override public function render():String {
    var inputName = (parentForm==null?"":parentForm.name) + "_" + this.name;
    var inputType = renderInputType();
    var pValue = value != null ? ('"' + value.toString() + '"') : null;
    return '
      <div id="$inputName" ></div>
      <script>
        document.addEventListener("DOMContentLoaded", function() {
          neo.createNeoModule("$inputName", "haxeDatePicker", {
            name: "$inputName",
            type: "$inputType",
            value: $pValue,
            required: $required,
            openTo: "$openTo"
          });
        });
      </script>
    ';
  }
}