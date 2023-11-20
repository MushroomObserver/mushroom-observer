import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-input"
export default class extends Controller {
  static targets = ['input', 'name']

  connect() {
    this.max_size = Number(this.inputTarget.dataset.maxUploadSize);
    this.error_msg = this.inputTarget.dataset.maxUploadMsg;
    this.old_callback = this.inputTarget.onchange;
  }

  // Override onchange callback with one which checks file size.
  // If exceeded, it gives an alert and clears the field.
  // If not, it passes execution to the original callback (if any).
  validate(event) {
    if (!this.max_size) alert("Missing max_upload_size attribute for #" + id);
    if (!this.error_msg) alert("Missing max_upload_msg attribute for #" + id);

    // alert("Applying validation to " + field.id);
    if (this.inputTarget.files[0].size > this.max_size) {
      alert(this.error_msg);
      // clear_file_input_field(this);
      this.inputTarget.value = "";
    } else if (this.old_callback) {
      this.old_callback.bind(event.target).call();
    } else {
      this.nameTarget.innerHTML = this.inputTarget.files[0].name
    }
  }
}
