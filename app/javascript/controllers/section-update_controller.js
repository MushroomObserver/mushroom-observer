import { Controller } from "@hotwired/stimulus"

// Handles page sections that get updated by Turbo on successful form submit.
// Dispatching an event here allows triggering other Stimulus controller actions
// that "clean up", e.g. remove or hide a modal.
// Connects to data-controller="section-update"
export default class extends Controller {
  static values = { user: Number }

  connect() {
    this.element.dataset.sectionUpdate = "connected"

    if (this.userValue == undefined) {
      alert("Sections monitored by section-update require a userValue.")
    }
    // Currently we're just using this to trigger modal:remove or modal:hide
    this.element.addEventListener("turbo:frame-render", this.updated())
  }

  // Dispatch a custom event to the window element, containing a user_id
  // of the user initiating the update (modifying the record updated).
  // This is compared with the modal controller's userValue -- if they are the
  // same, a turbo_frame-render dispatching this event should hide the modal.
  updated() {
    // console.log(this.element.id + " turbo:frame-render section updated")
    this.dispatch("updated", { detail: { user: this.userValue } })
  }
}
