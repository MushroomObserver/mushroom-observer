import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="page-input"
// Sanitizes the page number / letter inputs, and keeps this
// instance's "Goto" link (a plain <a>, not inside a <form>) pointed
// at the right page/letter as the user types -- no submission
// needed. Instantiated once per page-input/letter-input widget (two
// separate elements each carry their own data-controller="page-input"),
// so `goToLink` is unambiguous within either instance's own scope.
export default class extends Controller {
  static targets = ["numberInput", "letterInput", "goToLink"]
  static values = { max: Number, letters: String }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.pageInput = "connected"
  }

  // When page number input changes, sanitize the value of the input.
  // Since this action is fired onInput, before the browser has changed the
  // value attribute, also "manually" set the value *attribute*.
  sanitizeNumber() {
    let numberInput = parseInt(this.numberInputTarget.value || 1)
    if (numberInput > this.maxValue) { numberInput = this.maxValue }
    this.numberInputTarget.value = numberInput
    this.numberInputTarget.setAttribute("value", numberInput)

    if (this.hasGoToLinkTarget) {
      this.updateGotoLink(this.goToLinkTarget, "page", numberInput, /\d+/)
    }
  }

  // When letter input changes, make it a letter or a dash.
  // If dash, clear the input value attribute.
  sanitizeLetter() {
    let letterInput = this.letterInputTarget.value.toUpperCase() || ""
    if (!this.isLetter(letterInput)) letterInput = ""

    this.letterInputTarget.value = letterInput
    this.letterInputTarget.setAttribute("value", letterInput)

    if (this.hasGoToLinkTarget) {
      this.updateGotoLink(this.goToLinkTarget, "letter", letterInput,
        /[A-Z]$/)
    }

    // emit the letterUpdated event -- the page-number widget's own
    // page-input controller instance listens for this (see
    // syncLetter below) to keep ITS goto link's `letter` param in
    // sync too. No reverse sync: jumping to a new letter always
    // resets to page 1, so the letter widget never needs to know
    // the current page.
    const event = new CustomEvent("letterUpdated", {
      detail: {
        letter: letterInput
      },
      bubbles: true, // Optional: Determines if the event bubbles up the DOM
      cancelable: true, // Optional: Determines if the event can be canceled
    })
    document.dispatchEvent(event)
  }

  isLetter(char) {
    return /^[a-zA-Z]$/.test(char)
  }

  syncLetter(event) {
    const letterInput = event?.detail?.letter
    if (this.hasGoToLinkTarget) {
      this.updateGotoLink(this.goToLinkTarget, "letter", letterInput)
    }
  }

  // Rewrite a goto link's href to point at the new param value (empty
  // string clears the param, matching how the page widget resets
  // when no letter is set). When `replacePattern` is given and there's
  // a value to substitute, also updates the icon's Bootstrap tooltip
  // text by finding-and-replacing the old number/letter directly in
  // the already-rendered (translated) tooltip string, rather than
  // needing a separate template. `data-original-title` is where
  // Bootstrap 3 stashes the tooltip text after `fixTitle()`
  // neutralizes the native `title` attribute on init, and updating it
  // live is Bootstrap's own supported way to change an
  // already-initialized tooltip's text.
  updateGotoLink(link, param, value, replacePattern) {
    const url = new URL(link.href, window.location.origin)
    if (value === "" || value === null || value === undefined) {
      url.searchParams.delete(param)
    } else {
      url.searchParams.set(param, value)
    }
    link.href = url.toString()

    if (!replacePattern || !value) return
    const icon = link.querySelector("svg")
    if (!icon) return
    const current = icon.getAttribute("data-original-title") ||
      icon.getAttribute("title")
    if (current) {
      icon.setAttribute("data-original-title",
        current.replace(replacePattern, value))
    }
  }
}
