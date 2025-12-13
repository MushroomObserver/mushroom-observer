import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["flash"]
  static values = {
    maxLength: { type: Number, default: 9500 },
    searchType: String
  }

  connect() {
    // Listen for form submission
    this.element.addEventListener("submit", this.validateLength.bind(this))
  }

  validateLength(event) {
    const totalLength = this.calculateTotalLength()

    if (totalLength > this.maxLengthValue) {
      // Prevent form submission
      event.preventDefault()
      event.stopPropagation()

      // Display error message
      this.showError(totalLength)

      return false
    }

    // Clear any previous error if validation passes
    this.clearError()
    return true
  }

  calculateTotalLength() {
    const formData = new FormData(this.element)
    let totalLength = 0

    for (const [key, value] of formData.entries()) {
      if (typeof value === 'string') {
        totalLength += value.length
      }
    }

    return totalLength
  }

  showError(actualLength) {
    const errorHtml = `
      <div class="alert alert-danger">
        <a class="close" data-dismiss="alert">×</a>
        Search input is too long (${actualLength} characters).
        Maximum allowed is ${this.maxLengthValue} characters.
        Please shorten your search criteria.
      </div>
    `

    const flashDiv = document.getElementById(`search_${this.searchTypeValue}_flash`)
    if (flashDiv) {
      flashDiv.innerHTML = errorHtml
      flashDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  }

  clearError() {
    const flashDiv = document.getElementById(`search_${this.searchTypeValue}_flash`)
    if (flashDiv) {
      flashDiv.innerHTML = ''
    }
  }
}
