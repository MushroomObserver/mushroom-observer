import { Controller } from "@hotwired/stimulus"
import { delegate, abnegate } from 'jquery-events-to-dom-events'

// Shows/hides panels based on a select or radio group value, using
// Bootstrap 3 collapse for animated transitions.
//
// Panels are shown when their data-type-switch-type matches the
// current select/radio value. The server renders panels with the
// correct Bootstrap collapse classes (collapse + in for open,
// collapse alone for closed) so there is no flash on page load.
// connect() only disables inputs in hidden panels.
//
// Usage with select:
//   <div data-controller="type-switch">
//     <select data-type-switch-target="select"
//             data-action="type-switch#switch">
//     <div data-type-switch-target="panel"
//          data-type-switch-type="user"
//          class="collapse in">...</div>
//     <div data-type-switch-target="panel"
//          data-type-switch-type="location"
//          class="collapse">...</div>
//
// Usage with radio:
//   <div data-controller="type-switch">
//     <input type="radio" value="all"
//            data-action="change->type-switch#switch">
//     <input type="radio" value="ids"
//            data-action="change->type-switch#switch">
//     <div data-type-switch-target="panel"
//          data-type-switch-type="ids"
//          class="collapse">...</div>
//
// https://github.com/leastbad/jquery-events-to-dom-events
// delegate/abnegate bridge jQuery events (shown.bs.collapse etc.)
// to native DOM events (prefixed $) for use in data-action.
// If moving to BS5, remove this import and use native events directly.
export default class extends Controller {
  static targets = ["select", "panel"]

  connect() {
    this.delegateShown = delegate('shown.bs.collapse')
    this.delegateHidden = delegate('hidden.bs.collapse')
    // Server renders initial collapse state. Only disable inputs in
    // panels that start closed so they aren't submitted.
    this.panelTargets.forEach(panel => {
      if (!panel.classList.contains('in')) {
        this.disablePanelInputs(panel)
      }
    })
  }

  disconnect() {
    abnegate('shown.bs.collapse', this.delegateShown)
    abnegate('hidden.bs.collapse', this.delegateHidden)
  }

  switch() {
    const selectedValue = this.getSelectedValue()
    this.panelTargets.forEach(panel => {
      const panelType = panel.dataset.typeSwitchType
      if (panelType === selectedValue) {
        this.enablePanelInputs(panel)
        $(panel).collapse('show')
      } else {
        this.disablePanelInputs(panel)
        $(panel).collapse('hide')
      }
    })
  }

  getSelectedValue() {
    if (this.hasSelectTarget) {
      return this.selectTarget.value.toLowerCase()
    }
    const checked = this.element.querySelector('input[type="radio"]:checked')
    return checked ? checked.value.toLowerCase() : null
  }

  disablePanelInputs(panel) {
    panel.querySelectorAll(
      "input[type='text'], input[type='hidden'], textarea, select"
    ).forEach(input => {
      if (input.name && input.name.includes("[")) {
        input.disabled = true
        input.value = ""
      }
    })
  }

  enablePanelInputs(panel) {
    panel.querySelectorAll(
      "input[type='text'], input[type='hidden'], textarea, select"
    ).forEach(input => {
      if (input.name && input.name.includes("[")) {
        input.disabled = false
      }
    })
  }
}
