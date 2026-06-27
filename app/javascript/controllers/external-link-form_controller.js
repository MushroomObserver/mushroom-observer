import { Controller } from "@hotwired/stimulus"

// External-link edit form: a link is identified by external_id OR url, never
// both (mirrors ExternalLink#normalize_external_id_and_url server-side). When
// the external_id field holds a value, the url field is disabled and not
// required; clearing external_id re-enables it. Disabled inputs are not
// submitted, and the model drops any stored url when external_id is present.
// Connects to data-controller="external-link-form"
export default class extends Controller {
  static targets = ["externalId", "url"]

  connect() {
    this.toggleUrl()
  }

  toggleUrl() {
    const hasExternalId = this.externalIdTarget.value.trim() !== ""
    this.urlTarget.disabled = hasExternalId
    this.urlTarget.required = !hasExternalId
  }
}
