import { Controller } from "@hotwired/stimulus"

// Bootstrap 3's collapse data-API (bootstrap-sass collapse.js) only
// calls preventDefault() on a [data-toggle=collapse] click when the
// trigger has no data-target attribute. Components::Link::CollapseToggle's
// fallback_href option sets both an href and data-target (so collapse.js
// can still find the pane), so Bootstrap doesn't prevent the default
// navigation -- the click both toggles the pane and follows the href.
// This controller's only job is the preventDefault(); the :prevent
// action modifier calls it, and collapse.js's own delegated document
// click handler still runs and does the actual toggling.
//
// Bootstrap 3-specific workaround. Re-check whether this is still
// needed when MO migrates to Bootstrap 4/5 (issue #3797) --
// collapse.js's data-API may behave differently there.
// Connects to data-controller="collapse-fallback"
export default class extends Controller {
  intercept() {}
}
