import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip"
// BS3 tooltips are "opt-in", so they require on-page activation
export default class extends Controller {

  connect() {
    this.element.dataset.tooltip = "connected";
    this.activateTooltips();
  }

  activateTooltips() {
    $('[data-toggle="tooltip"]').tooltip()
  }
}
