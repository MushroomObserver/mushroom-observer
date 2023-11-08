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
    this.element.setAttribute("data-stimulus", "connected")
    // The localized text is for the modal progress. Maybe not needed here.
    Object.assign(this.localized_text,
      JSON.parse(this.element.dataset.localization));
  }

  // Pause the UI on change and show the progress modal. Maybe no need?
  // Send the vote submit
  sendVote() {
    // console.log("Sending Vote")
    // console.log("Pausing UI")
    // $('#mo_ajax_progress_caption').html(
    //   this.localized_text.saving + "... "
    // );
    // $("#mo_ajax_progress").modal({ backdrop: 'static', keyboard: false });
    // this.element.setAttribute("data-stimulus", "sending")
    this.element.requestSubmit()
  }
}
