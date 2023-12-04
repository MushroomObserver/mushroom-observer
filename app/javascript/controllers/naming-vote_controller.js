import { Controller } from "@hotwired/stimulus"

// Controller deals with naming vote select bindings ** per select. **
// the controller is on the <form>
export default class extends Controller {
  static targets = ["select", "submit"]

  initialize() {
    this.localized_text = {}
  }

  connect() {
    // console.log("Hello Modal");
    this.element.dataset.stimulus = "connected";
    // The localized text is for the modal progress caption.
    Object.assign(this.localized_text,
      JSON.parse(this.element.dataset.localization));
  }

  // Pause the UI on change and show the progress modal. Maybe no need?
  // Send the vote submit
  sendVote() {
    // console.log("Sending Vote")
    // console.log("Pausing UI")
    document.getElementById('mo_ajax_progress_caption').innerHTML =
      this.localized_text.saving + "... ";

    // Must be in jQuery for Bootstrap 3 and 4
    $("#mo_ajax_progress").modal('show');
    // this.element.setAttribute("data-stimulus", "sending")
    this.element.requestSubmit();
  }
}
