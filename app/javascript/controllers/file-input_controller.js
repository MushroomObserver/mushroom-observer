import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-input"
export default class extends Controller {
  static targets = ['input', 'name']

  connect() {
    this.element.dataset.fileInput = "connected";
    this.max_size = Number(this.inputTarget.dataset.maxUploadSize);
    this.error_msg = this.inputTarget.dataset.maxUploadMsg;
    this.old_callback = this.inputTarget.onchange;
  }

  // Override onchange callback with one which checks file type and size.
  // If invalid, it gives an alert and clears the field.
  // If not, it passes execution to the original callback (if any).
  validate(event) {
    if (!this.max_size) alert("Missing max_upload_size attribute for #" + id);
    if (!this.error_msg) alert("Missing max_upload_msg attribute for #" + id);

    const file = this.inputTarget.files[0];
    if (!file) return;

    // Check file type - folders have empty type, reject non-images
    if (!file.type || !file.type.startsWith('image/')) {
      alert("Please select an image file (JPG, PNG, GIF, etc.)");
      this.inputTarget.value = "";
      return;
    }

    // Check file size
    if (file.size > this.max_size) {
      alert(this.error_msg);
      this.inputTarget.value = "";
      return;
    }

    if (this.old_callback) {
      this.old_callback.bind(event.target).call();
    } else {
      this.nameTarget.innerHTML = file.name
    }
  }
}
