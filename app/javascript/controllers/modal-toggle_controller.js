import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

// The controller for the link to the modal - not the modal itself.
// MO doesn't print a pre-existing "dormant" Bootstrap modal form in the page
// because we want to let people have several modals in progress on same page.
// For example, you can start entering a collection number, close the modal,
// open a herbarium record form, close it and go back to the collection number
// and find the form form as you left it, or vice versa, until you submit.
export default class extends Controller {

  connect() {
    this.element.dataset.stimulus = "connected";
    this.modalSelector = this.element.dataset.modal
    this.destination = this.element.getAttribute("href")
  }

  // NOTE: the button must pass :prevent with the action,
  // a Stimulus shortcut that calls event.preventDefault()
  showModal() {
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
  // NOTE: Above example presumes a pre-existing modal.
  async fetchModalAndAppendToBody() {
    // console.log(destination)

    const response = await get(this.destination,
      { responseKind: "turbo-stream" })

    if (response.ok) {
      // console.log(response)
      // turbo-stream prints the modal in the page already, but outside body
      // so we just have to move it.
      const _modal = document.getElementById(this.modalSelector)
      document.body.appendChild(_modal)
      $(_modal).modal('show')
    }
  }
}
