import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown-current"
export default class extends Controller {
  static targets = ["title", "link"]

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.dropdownCurrent = "connected"
    // On connect, update the dropdown text with either the current selection
    // or the first selection (default). Note: already translated.
    this.updateDropdownTitle()
  }

  updateDropdownTitle() {
    const currentByText = this.currentOrderingLabel()
    this.titleTarget.innerText = currentByText
  }

  currentOrderingLabel() {
    if (this.linkTargets.length == 0) return

    const queryString = window.location.search, // guaranteed to be a string
      urlParams = new URLSearchParams(queryString),
      currentBy = urlParams.get('by') || "",
      // Get the translated label of the current `by` param
      currentByItems = this.linkTargets.filter(
        item => item.dataset.by === currentBy
      ),
      defaultByText = this.linkTargets[0].innerText

    if (currentBy == "") {
      return defaultByText
    } else {
      return currentByItems[0].innerText
    }
  }
}
