import { Controller } from "@hotwired/stimulus"

// Controller deals with naming vote select bindings ** per select. **
export default class extends Controller {
  static targets = ["form", "select"] // the controller is on the <form>

  connect() {
    // console.log("Hello Modal");
    this.element.setAttribute("data-stimulus", "connected")
  }

  // Pause the UI on change and show the progress modal. Maybe no need?
  // Send the vote submit
  sendVote() {
    // console.log("Sending Vote")
    // console.log("Pausing UI")
    // $('#mo_ajax_progress_caption').html(
    //   translations.show_namings_saving + "... "
    // );
    // $("#mo_ajax_progress").modal({ backdrop: 'static', keyboard: false });
    // this.element.setAttribute("data-stimulus", "sending")
    this.element.requestSubmit()
  }
}
