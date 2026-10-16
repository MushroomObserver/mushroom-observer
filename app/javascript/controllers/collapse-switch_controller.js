import { Controller } from "@hotwired/stimulus"
import { delegate, abnegate } from 'jquery-events-to-dom-events'

// Shows/hides panels based on a select or radio group's value, via
// Bootstrap collapse -- a panel shows when its
// data-collapse-switch-type matches the current value, others
// collapse. Initial state renders server-side (no flash); hidden
// panels' inputs are disabled on connect so they don't submit.

// Wrapper: data-controller="collapse-switch". Select or each radio:
// data-action="[change->]collapse-switch#switch" (select also needs
// data-collapse-switch-target="select"). Each panel:
// data-collapse-switch-target="panel" plus data-collapse-switch-type.

// jquery-events-to-dom-events bridges jQuery's bs.collapse events
// for data-action; drop it if this moves to BS5.
export default class extends Controller {
  static targets = ["select", "panel"]

  connect() {
    this.delegateShown = delegate('shown.bs.collapse')
    this.delegateHidden = delegate('hidden.bs.collapse')
    // Server renders initial collapse state. Only disable inputs in
    // panels that start closed so they aren't submitted.
    this.panelTargets.forEach(panel => {
      if (!panel.classList.contains('show')) {
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
      const panelType = panel.dataset.collapseSwitchType
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
