// No way to clear file field, so replace with new empty clone(!)
// Tried jQuery.clone(), but doesn't work -- copying value any all??
function clear_file_input_field(old_field) {
  var new_field = document.createElement("input");
  for (var i=0; i<old_field.attributes.length; i++) {
    var attr = old_field.attributes[i];
    new_field.setAttribute(attr.name, attr.value);
  }
  old_field.parentNode.replaceChild(new_field, old_field);
  apply_file_input_field_validation(new_field.id);
}

// Override onchange callback with one which checks file size.
// If exceeded, it gives an alert and clears the field.
// If not, it passes execution to the original callback (if any).
function apply_file_input_field_validation(id) {
  var field = document.getElementById(id);
  var old_callback = field.onchange;
  var max_size = field.getAttribute("max_upload_size");
  var error_msg = field.getAttribute("max_upload_msg");
  if (!max_size) alert("Missing max_upload_size attribute for #" + id);
  if (!error_msg) alert("Missing max_upload_msg attribute for #" + id);
  // alert("Applying validation to " + field.id);
  field.onchange = function() {
    var file_size = this.files[0].size;
    // alert("Changed " + id + " to " + file_size);
    if (file_size > max_size) {
      alert(error_msg);
      clear_file_input_field(this);
    } else if (old_callback) {
      old_callback.bind(this).call();
    }
  };
}

// Initializer moved to initializers.js
