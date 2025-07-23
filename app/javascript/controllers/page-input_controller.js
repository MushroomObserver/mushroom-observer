import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="page-input"
// Updates form action url from input page number
export default class extends Controller {
  static targets = ["input"]
  static values = ["max"]

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.pageInput = "connected"
  }

  // When the input changes, update the form element's action attribute
  updateForm() {
    const pageInput = parseInt(this.inputTarget.value)
    if (pageInput == 0) { pageInput = 1 }
    if (pageInput > this.maxValue) { pageInput = this.maxValue }
    const url = this.updateUrl(pageInput)
    this.element.action = url
  }

  updateUrl() {
    const currentUrl = new URL(this.element.action),
      currentQueryString = currentUrl.search,
      urlParams = new URLSearchParams(currentQueryString),
      currentPage = urlParams.get("page")
  }
}
