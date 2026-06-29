import { Controller } from "@hotwired/stimulus"

// External-link form: a link is identified by external_id OR url. Exactly one
// field is active (editable); the other is grayed (readonly) but keeps its
// value. Focusing a field activates it. The url field is seeded with the
// selected site's prefix and reset when the site changes. On submit only the
// active field is sent — the inactive one is blanked — so the model stores one
// or the other. Mirrors ExternalLink#normalize_external_id_and_url.
// Connects to data-controller="external-link-form"
export default class extends Controller {
  static targets = ["externalId", "url", "site"]
  static values = { active: String, prefixes: Object }

  connect() {
    const start = this.activeValue === "url"
      ? this.urlTarget
      : this.externalIdTarget
    this.setActive(start)
    this.boundBlank = () => this.blankInactive()
    this.element.addEventListener("submit", this.boundBlank)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.boundBlank)
  }

  // A field gains focus (click or tab) -> it becomes the active one.
  activate(event) {
    this.setActive(event.target)
  }

  setActive(field) {
    this.activeField = field
    this.gray(this.externalIdTarget, field !== this.externalIdTarget)
    this.gray(this.urlTarget, field !== this.urlTarget)
  }

  gray(field, inactive) {
    field.readOnly = inactive
    field.classList.toggle("bg-light", inactive)
    field.classList.toggle("text-muted", inactive)
  }

  // Changing the site reseeds the url with that site's prefix and returns to
  // the external_id default.
  siteChanged() {
    const prefix = this.prefixesValue[this.siteTarget.value]
    if (prefix !== undefined) this.urlTarget.value = prefix
    this.setActive(this.externalIdTarget)
  }

  blankInactive() {
    if (this.activeField !== this.externalIdTarget) {
      this.externalIdTarget.value = ""
    }
    if (this.activeField !== this.urlTarget) this.urlTarget.value = ""
  }
}
