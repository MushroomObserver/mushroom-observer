import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ["source"]
  static values = { copied: String }

  connect() {
    this.element.dataset.clipboard = "connected";
  }

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.innerText)
    // this.sourceTarget.dataset.title = "Copied"
    const tooltipInner =
      this.sourceTarget.nextElementSibling.querySelector(".tooltip-inner")
    if (tooltipInner) { tooltipInner.innerText = this.copiedValue }
  }
}
