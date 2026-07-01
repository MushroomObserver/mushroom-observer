import { Controller } from "@hotwired/stimulus"

// Simple controller to show/hide panels based on a select value.
// Panels are shown when their data-type-switch-type matches the select value.
//
// Usage:
//   <div data-controller="type-switch">
//     <select data-type-switch-target="select"
//             data-action="type-switch#switch">
//       <option value="user">User</option>
//       <option value="location">Location</option>
//     </select>
//     <div data-type-switch-target="panel" data-type-switch-type="user">
//       User autocompleter here
//     </div>
//     <div data-type-switch-target="panel" data-type-switch-type="location">
//       Location autocompleter here
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["select", "panel"]

  connect() {
    this.switch()
  }

  switch() {
    const selectedType = this.selectTarget.value.toLowerCase()

    this.panelTargets.forEach(panel => {
      const panelType = panel.dataset.typeSwitchType
      if (panelType === selectedType) {
        panel.classList.remove("d-none")
        this.enablePanelInputs(panel)
      } else {
        panel.classList.add("d-none")
        this.disablePanelInputs(panel)
      }
    })
  }

  // Disable inputs in hidden panels so they aren't submitted
  disablePanelInputs(panel) {
    panel.querySelectorAll("input[type='text'], input[type='hidden']")
      .forEach(input => {
        if (input.name && input.name.includes("[")) {
          input.disabled = true
          input.value = ""
        }
      })
  }

  // Re-enable inputs when panel becomes visible
  enablePanelInputs(panel) {
    panel.querySelectorAll("input[type='text'], input[type='hidden']")
      .forEach(input => {
        if (input.name && input.name.includes("[")) {
          input.disabled = false
        }
      })
  }
}
