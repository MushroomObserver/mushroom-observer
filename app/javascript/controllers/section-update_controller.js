import { Controller } from "@hotwired/stimulus"

// Handles page sections that get updated by Turbo Stream actions (e.g.
// ApplicationController::SectionUpdater's render_obs_section_update)
// after a successful form submit. Dispatching an event here allows
// triggering other Stimulus controller actions that "clean up", e.g.
// remove or hide a modal (see modal_controller.js#remove).
// Connects to data-controller="section-update"
//
// A Turbo Stream `replace` action patches this element's content in
// place -- it does not tear down and rebuild the element, so Stimulus's
// own connect()/disconnect() lifecycle never re-fires from a replace.
// The only reliable signal is Turbo's own `turbo:before-stream-render`
// event, dispatched on the `<turbo-stream>` element (and bubbling to
// `document`) right before each stream action runs; its target's
// `target` attribute is the id of the element the action will act on.
export default class extends Controller {
  static values = { user: Number }

  connect() {
    this.element.dataset.sectionUpdate = "connected"

    if (this.userValue == undefined) {
      alert("Sections monitored by section-update require a userValue.")
    }
    this.boundUpdated = this.updated.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundUpdated)
  }

  disconnect() {
    document.removeEventListener(
      "turbo:before-stream-render", this.boundUpdated
    )
  }

  // Dispatch a custom event from this.element, containing the user_id
  // of the user initiating the update (modifying the record updated).
  // It bubbles up to window, where listeners (e.g. modal_controller's
  // `@window`-scoped action) receive it. The user_id is compared with
  // the modal controller's userValue -- if they are the same, a
  // stream render targeting this section should hide the modal.
  updated(event) {
    const stream = event.target
    if (stream.target !== this.element.id) return

    this.dispatch("updated", { detail: { user: this.userValue } })
  }
}
