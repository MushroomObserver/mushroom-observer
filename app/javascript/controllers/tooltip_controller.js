import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip"
// BS3/BS4 tooltips are "opt-in", so they require on-page activation.
// We use our own data-trigger="tooltip" marker rather than
// data-toggle="tooltip" -- data-toggle is the attribute Bootstrap's
// own plugins (collapse, dropdown, tab, modal, ...) key off of via
// an exact-string selector, so an element that needs both a
// Bootstrap trigger and a tooltip can't share the two on one
// data-toggle value. data-trigger is entirely ours.
export default class extends Controller {

  connect() {
    this.element.dataset.tooltip = "connected";
    this.activateTooltips();
  }

  activateTooltips() {
    $('[data-trigger="tooltip"]').tooltip()
  }
}
