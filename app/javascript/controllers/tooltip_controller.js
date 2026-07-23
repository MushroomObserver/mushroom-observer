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
    this.activateTooltips(this.element);
    // Content added later via a turbo-frame fetch (e.g. the external
    // links "Shared with" pane) never gets this controller's one-time
    // connect() sweep -- turbo:frame-load fires once per frame
    // navigation, scoped to just that frame's new content.
    this.frameLoadListener = (event) => this.activateTooltips(event.target);
    document.addEventListener("turbo:frame-load", this.frameLoadListener);
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.frameLoadListener);
  }

  activateTooltips(scope) {
    $(scope).find('[data-trigger="tooltip"]').tooltip()
  }
}
