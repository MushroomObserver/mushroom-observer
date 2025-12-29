import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["flash"]
  static values = {
    maxLength: { type: Number, default: 8000 },
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

    // Fields to exclude from length calculation
    const excludedFields = [
      'authenticity_token',
      'commit',
      'utf8',
      '_method',
      'button'
    ]

    // Default values to exclude from length calculation
    const defaultValues = ['true', 'false', '0.0', '', 'no', 'yes']

    for (const [key, value] of formData.entries()) {
      if (typeof value === 'string') {
        const fieldExcluded = excludedFields.includes(key)
        const defaultExcluded = defaultValues.includes(value)
        // Exclude rank fields (Names search only)
        const isRankField = key.includes('[rank]') || key.includes('[rank_range]')
        // Exclude bounding box coordinates (in_box fields)
        const isCoordinateField = key.includes('[in_box]')
        const excluded = fieldExcluded || defaultExcluded || isRankField || isCoordinateField
        if (!excluded) {
          totalLength += value.length
        }
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

    const searchType = this.searchTypeValue.replace(/-/g, '_')
    const flashDiv = document.getElementById(`search_${searchType}_flash`)
    if (flashDiv) {
      flashDiv.innerHTML = errorHtml
      flashDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  }

  clearError() {
    const searchType = this.searchTypeValue.replace(/-/g, '_')
    const flashDiv = document.getElementById(`search_${searchType}_flash`)
    if (flashDiv) {
      flashDiv.innerHTML = ''
    }
  }
}
