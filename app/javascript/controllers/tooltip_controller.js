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

  // Opt-in only -- default (no data-tooltip-container attribute) stays
  // Bootstrap's own `container: false`, which inserts the tooltip as
  // the trigger's next DOM sibling. clipboard_controller.js depends on
  // that default to find and rewrite its own tooltip text, so this
  // must never become the global default. Pass a CSS selector (e.g.
  // ".panel") to append the tooltip to the trigger's closest matching
  // ancestor instead -- needed when the trigger sits inside a tightly
  // sized container (e.g. the image vote button group) that clips or
  // misplaces a sibling-inserted tooltip.
  tipTargetConnected(element) {
    const containerSelector = element.dataset.tooltipContainer
    const container = containerSelector
      ? element.closest(containerSelector) || false
      : false
    $(element).tooltip({ container })
  }
}
