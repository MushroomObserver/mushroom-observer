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
  // must never become the global default. Pass a CSS selector to
  // append the tooltip to the trigger's closest matching ancestor
  // instead -- needed when the trigger sits inside a tightly sized
  // container (e.g. the image vote button group) that clips or
  // misplaces a sibling-inserted tooltip. `closest()` accepts a
  // comma-separated selector list.
  tipTargetConnected(element) {
    const containerSelector = element.dataset.tooltipContainer
    const container = containerSelector
      ? element.closest(containerSelector) || false
      : false
    $(element).tooltip({ container })

    if (element.dataset.activeTitle) this.watchActiveTitle(element)
  }

  tipTargetDisconnected(element) {
    element.mo_activeTitleObserver?.disconnect()
  }

  // A stateful-link trigger (active_icon:/active_content:, see
  // Components::Button::Content) carries data-active-title alongside
  // the icon/label pair _icons.scss's `.stateful-link` rule swaps on
  // `.active`/`.collapsed` -- keep Bootstrap's cached tooltip title in
  // sync with the same class, regardless of what toggles it.
  watchActiveTitle(element) {
    // Bootstrap's tooltip() already moved the original title into
    // data-original-title (and blanked the title attribute) by this
    // point -- read the base text back from there, not from title.
    const baseTitle = element.getAttribute("data-original-title")
    const activeTitle = element.dataset.activeTitle
    const sync = () => {
      const active = element.classList.contains("active") ||
        element.classList.contains("collapsed")
      element.setAttribute("data-original-title",
                           active ? activeTitle : baseTitle)
    }
    const observer = new MutationObserver(sync)
    observer.observe(element, { attributes: true, attributeFilter: ["class"] })
    element.mo_activeTitleObserver = observer
  }
}
