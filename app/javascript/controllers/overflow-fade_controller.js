import { Controller } from "@hotwired/stimulus"

// Toggles `at-top`/`at-bottom` classes on the controller's own element
// as it scrolls, so CSS can hide a top/bottom fade affordance once
// there's nothing left to scroll to in that direction. Generic --
// attach to any scrollable element that wants this behavior, not just
// a checkbox panel.
//
// A ResizeObserver, not just a one-shot initial check, because this
// element can start inside a collapsed Bootstrap panel: while
// `display: none`, clientHeight/scrollHeight both read 0, so a
// connect()-time measurement alone would wrongly conclude "at bottom"
// and never correct itself once the panel expands. ResizeObserver
// re-fires whenever the element's real size resolves, covering both
// the initial-layout and the collapse-to-expand case.
// Connects to data-controller="overflow-fade"
export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    this.element.addEventListener("scroll", this.update, { passive: true })
    this.resizeObserver = new ResizeObserver(this.update)
    this.resizeObserver.observe(this.element)
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.update)
    this.resizeObserver.disconnect()
  }

  update() {
    const el = this.element
    const atTop = el.scrollTop <= 0
    const atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight
    el.classList.toggle("at-top", atTop)
    el.classList.toggle("at-bottom", atBottom)
  }
}
