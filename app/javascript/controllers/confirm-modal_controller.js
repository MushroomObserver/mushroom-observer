import { Controller } from "@hotwired/stimulus"

// Stimulus controller for custom Turbo confirmation dialogs.
// Replaces the browser's native confirm() with a Bootstrap modal.
//
// Usage: The modal is automatically used for all data-turbo-confirm attributes
// once this controller is connected.
//
// Custom titles: Add data-turbo-confirm-title to the element to override
// the default "Are you sure?" title.
export default class extends Controller {
  static targets = ["title", "confirmButton"]

  connect() {
    // Store defaults for resetting
    if (this.hasTitleTarget) {
      this.defaultTitle = this.titleTarget.textContent
    }
    if (this.hasConfirmButtonTarget) {
      this.defaultButtonText = this.confirmButtonTarget.textContent
    }

    // Register this as Turbo's confirmation method
    Turbo.config.forms.confirm = (message, element) => {
      return this.show(message, element)
    }
  }

  // Shows the modal with the given message and returns a Promise
  // that resolves to true (confirm) or false (cancel)
  show(message, element) {
    return new Promise((resolve) => {
      this.resolvePromise = resolve

      // Element is the form; find the button inside it for custom data
      const button = element?.querySelector("button[type='submit']")

      // Use custom title if provided, otherwise default
      const customTitle = button?.dataset?.turboConfirmTitle
      if (this.hasTitleTarget) {
        this.titleTarget.textContent = customTitle || this.defaultTitle
      }

      // Use button name if provided, otherwise default
      const buttonName = button?.dataset?.turboConfirmButton
      if (this.hasConfirmButtonTarget) {
        this.confirmButtonTarget.textContent = buttonName || this.defaultButtonText
      }

      // Show the modal using Bootstrap
      $(this.element).modal("show")
    })
  }

  confirm() {
    this.hide()
    if (this.resolvePromise) {
      this.resolvePromise(true)
      this.resolvePromise = null
    }
  }

  cancel() {
    this.hide()
    if (this.resolvePromise) {
      this.resolvePromise(false)
      this.resolvePromise = null
    }
  }

  hide() {
    $(this.element).modal("hide")
  }
}
