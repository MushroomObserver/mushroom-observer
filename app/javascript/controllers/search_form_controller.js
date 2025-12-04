import { Controller } from "@hotwired/stimulus"

// Validates search form URL length before submission to prevent Puma errors
export default class extends Controller {
  validateLength(event) {
    const form = event.target
    const formData = new FormData(form)
    const params = new URLSearchParams()

    // Build query string from form data
    for (const [key, value] of formData.entries()) {
      if (value) {  // Only include non-empty values
        params.append(key, value)
      }
    }

    const queryString = params.toString()
    const maxLength = parseInt(form.dataset.maxQueryLength)

    if (queryString.length > maxLength) {
      event.preventDefault()

      const currentLength = queryString.length
      const overage = currentLength - maxLength

      alert(
        `Your search parameters are too long (${currentLength} characters, ` +
        `maximum ${maxLength}).\n\n` +
        `Please reduce by approximately ${overage} characters. Try:\n` +
        `• Shortening text in search fields\n` +
        `• Removing some search criteria\n` +
        `• Using fewer terms`
      )

      return false
    }

    return true
  }
}
