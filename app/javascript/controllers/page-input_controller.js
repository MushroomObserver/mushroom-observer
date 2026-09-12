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

    // Cache the server-rendered tooltip so it can be restored (rather
    // than left stale, pointing at a value no longer being typed) if
    // the field gets cleared back to empty -- see updateGotoLink.
    // aria-label (set unconditionally by Components::Icon whenever a
    // title: is given) is the stable source: unlike title, it's never
    // moved/removed by Bootstrap's tooltip init, so it reads the same
    // whether that init has run yet or not.
    if (this.hasGoToLinkTarget) {
      const icon = this.goToLinkTarget.querySelector("svg")
      this.originalTooltip = icon?.getAttribute("aria-label") || null
    }
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
  // a value to substitute, also updates the icon's tooltip text (both
  // the Bootstrap tooltip and its aria-label accessible name) by
  // finding-and-replacing the old number/letter directly in the
  // already-rendered (translated) text, rather than needing a
  // separate template. When the value is cleared (empty), restores
  // the cached server-rendered tooltip (see connect) instead of
  // leaving stale text naming the last-typed value the href no longer
  // points at.
  updateGotoLink(link, param, value, replacePattern) {
    const url = new URL(link.href, window.location.origin)
    if (value === "" || value === null || value === undefined) {
      url.searchParams.delete(param)
    } else {
      url.searchParams.set(param, value)
    }
    link.href = url.toString()

    if (!replacePattern) return
    const icon = link.querySelector("svg")
    if (!icon) return

    if (!value) {
      if (this.originalTooltip) this.setTooltipText(icon, this.originalTooltip)
      return
    }

    const current = icon.getAttribute("aria-label")
    if (current) this.setTooltipText(icon, current.replace(replacePattern, value))
  }

  // Keeps the Bootstrap tooltip text and the icon's own accessible
  // name in sync. aria-label is always present (see connect) and
  // never touched by Bootstrap's tooltip init, so it's updated
  // unconditionally; whichever of `data-original-title` (Bootstrap's
  // post-init stash, per fixTitle()) or `title` (pre-init) is
  // currently present carries the Bootstrap tooltip text and is
  // updated too -- updating a `title` that's already been moved to
  // `data-original-title` would silently do nothing, since Bootstrap
  // reads the tooltip text from the latter once initialized.
  setTooltipText(icon, text) {
    icon.setAttribute("aria-label", text)
    if (icon.hasAttribute("data-original-title")) {
      icon.setAttribute("data-original-title", text)
    } else if (icon.hasAttribute("title")) {
      icon.setAttribute("title", text)
    }
  }
}
