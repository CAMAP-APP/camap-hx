package form;

import sugoi.form.elements.NativeDatePicker;
import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;

class CamapDateTimePicker extends CamapDatePicker {

    public function new(name,label,value,?required,?attributes){
        super(name,label,value,NativeDatePickerType.datetime,required,attributes);
    }
  
}