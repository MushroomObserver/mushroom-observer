import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip", once, on <body> -- every
// tooltip trigger element on the page carries a `tip` TARGET of this
// one instance, not its own controller. BS3 tooltips are "opt-in" and
// need per-element activation; Stimulus's own target tracking (a
// MutationObserver scoped to this.element) calls tipTargetConnected
// for every matching element automatically, whether it's present at
// initial page load or added later by any means (a turbo-frame fetch,
// a Turbo Stream, raw JS) -- no manual sweep or extra event listener
// needed for the dynamic case.
export default class extends Controller {
  static targets = ["tip"]

  connect() {
    this.element.dataset.tooltip = "connected";
  }

  tipTargetConnected(element) {
    $(element).tooltip()
  }
}
