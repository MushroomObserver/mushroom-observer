import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ["source"]
  static values = { copied: String, text: String }

  connect() {
    this.element.dataset.clipboard = "connected";
  }

  // Text to copy comes either from a `text` value (set directly by
  // the caller, e.g. content not rendered in the DOM) or, when no
  // `text` value is given, from the `source` target's visible text
  // (e.g. the id badge, which displays the value it copies).
  copy() {
    const text = this.hasTextValue ? this.textValue : this.sourceTarget.innerText
    navigator.clipboard.writeText(text)
    // `container: false` (Bootstrap tooltip default) inserts the
    // tooltip markup as the next sibling of the trigger element.
    const tooltipInner = this.element.querySelector(".tooltip-inner") ||
      this.element.nextElementSibling?.querySelector(".tooltip-inner")
    if (tooltipInner) { tooltipInner.innerText = this.copiedValue }
  }
}
