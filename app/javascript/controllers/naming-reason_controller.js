import { Controller } from "@hotwired/stimulus"
import { delegate, abnegate } from 'jquery-events-to-dom-events'

// https://github.com/leastbad/jquery-events-to-dom-events
// We use a Stimulus action that listens to `$shown.bs.collapse` on the div
// (note the `$`). This depends on using `delegate` from the imported library
// jquery-events-to-dom-events. `delegate` listens for `shown.bs.collapse`, a
// jQuery event (not a native JS event), and dispatches a native event (with $).
//
// If moving to BS 5, can remove.

// Connects to data-controller="naming-reason"
export default class extends Controller {
  static targets = ['collapse', 'input']

  connect() {
    this.element.dataset.namingReason = "connected";
    this.delegateShown = delegate('shown.bs.collapse')
    this.delegateHidden = delegate('hidden.bs.collapse')
  }

  disconnect() {
    abnegate('shown.bs.collapse', this.delegateShown)
    abnegate('hidden.bs.collapse', this.delegateHidden)
  }

  // Focuses the input within, when a collapsed reason panel is shown
  focusInput(event) {
    // console.log('Event fired on #' + event.currentTarget.id);
    this.inputTarget.focus()
  }

  // Clear the input within, when a reason panel is unchecked
  clearInput(event) {
    // console.log('Event fired on #' + event.currentTarget.id);
    this.inputTarget.value = ""
  }
}
