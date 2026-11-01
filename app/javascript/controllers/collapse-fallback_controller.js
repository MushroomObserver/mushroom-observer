import { Controller } from "@hotwired/stimulus"

// Bootstrap 3's collapse data-API (bootstrap-sass collapse.js) only
// calls preventDefault() on a [data-toggle=collapse] click when the
// trigger has no data-target attribute. Components::Link::CollapseToggle's
// fallback_href option sets both an href and data-target (so collapse.js
// can still find the pane), so Bootstrap doesn't prevent the default
// navigation -- the click both toggles the pane and follows the href.
// This controller's job is that preventDefault(), EXCEPT when the
// trigger also carries data-turbo-frame: Turbo's own click handling
// already checks event.defaultPrevented before deciding whether to
// intercept a frame-targeted link, so calling preventDefault() here
// first would silently stop Turbo from ever fetching the frame --
// collapse.js still toggles the pane open (a separate, unprevented
// listener), leaving it permanently empty. Turbo already prevents the
// full-page navigation itself once it takes over a data-turbo-frame
// click, so no manual prevention is needed for that case.
//
// Bootstrap 3-specific workaround. Re-check whether this is still
// needed when MO migrates to Bootstrap 4/5 (issue #3797) -- confirmed
// NOT needed there: Bootstrap 4's collapse.js data-API calls
// preventDefault() unconditionally for every <a> trigger.
// Connects to data-controller="collapse-fallback"
export default class extends Controller {
  intercept(event) {
    if (!event.currentTarget.dataset.turboFrame) {
      event.preventDefault()
    }
  }
}
