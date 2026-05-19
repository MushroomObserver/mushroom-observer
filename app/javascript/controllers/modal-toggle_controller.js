import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

// The controller goes on the button_to the modal - not the modal itself.
// MO doesn't print a pre-existing "dormant" Bootstrap modal form in the page
// because we want to let people have several modals in progress on same page.
// For example, you can start entering a collection number, close the modal,
// open a herbarium record form, close it and go back to the collection number
// and find the form form as you left it, or vice versa, until you submit.
// Connects to data-controller="modal-toggle"
//
// `alwaysFresh` (data-modal-toggle-always-fresh-value="true") drops the
// "reuse existing DOM" shortcut and re-fetches the modal every time the
// trigger is clicked. Used by the Add-Target-Location modal (#4304),
// whose radio state depends on Location rows that admins frequently
// create in a separate tab between opens.
export default class extends Controller {
  static values = { alwaysFresh: Boolean }

  connect() {
    this.element.dataset.modalToggle = "connected";
    this.modalSelector = this.element.dataset.modal
    this.destination = this.element.getAttribute("href")
  }

  // NOTE: the button must pass :prevent with the action,
  // a Stimulus shortcut that calls event.preventDefault()
  showModal() {
    if (this.alwaysFreshValue) {
      this.fetchModalAndAppendToBody()
      return
    }
    // check if modal already exists in DOM (eg if user has closed it)
    if (document.getElementById(this.modalSelector)) {
      // if so, show.
      $(document.getElementById(this.modalSelector)).modal('show')
    } else {
      // if not, fetch the content.
      this.fetchModalAndAppendToBody()
    }
  }

  // https://discuss.hotwired.dev/t/is-this-correct-a-stimulus-controller-to-use-turbo-stream-get-requests-to-avoid-updating-browser-history/4146
  // NOTE: Above example presumes a pre-existing modal, but the idea is similar.
  // We use requestjs to streamline the fetch syntax
  //
  // In `alwaysFresh` mode, a stale prior copy is "stashed" (id renamed)
  // BEFORE the fetch so the fresh response can claim the canonical id
  // without collision, and only removed once the fetch succeeds. If
  // the fetch fails (network error, 404, etc.) the stash is restored
  // so the user can still reopen the previously-loaded modal (Copilot
  // review on PR #4307).
  async fetchModalAndAppendToBody() {
    const stash = this.alwaysFreshValue
      ? document.getElementById(this.modalSelector)
      : null
    if (stash) { stash.id = `${this.modalSelector}_stale` }

    const response = await get(this.destination,
      { responseKind: "turbo-stream" })

    if (response.ok) {
      if (stash) { stash.remove() }
      // turbo-stream prints the modal in the page already, but outside body
      // so we just have to move it.
      const _modal = document.getElementById(this.modalSelector)
      document.body.appendChild(_modal)
      $(_modal).modal('show')
    } else if (stash) {
      stash.id = this.modalSelector
    }
  }
}
