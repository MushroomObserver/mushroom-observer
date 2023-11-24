import { Controller } from "@hotwired/stimulus"
import { delegate, abnegate } from 'jquery-events-to-dom-events'

// Connects to data-controller="naming-reason"

// https://github.com/leastbad/jquery-events-to-dom-events
// We use a Stimulus action that listens to `$shown.bs.collapse` on the div
// (note the `$`). This depends on using `delegate` from the imported library
// jquery-events-to-dom-events. `delegate` listens for `shown.bs.collapse`, a
// jQuery event (not a native JS event), and dispatches a native event (with $).
//
// If moving to BS 5, can remove.

export default class extends Controller {
  static targets = ['collapse', 'input']

  connect() {
    this.element.dataset.stimulus = "connected";
    this.delegate = delegate('shown.bs.collapse')
  }

  disconnect() {
    abnegate('shown.bs.collapse', this.delegate)
  }

  focusInput(event) {
    // console.log('Event fired on #' + event.currentTarget.id);
    this.inputTarget.focus()
  }
}
