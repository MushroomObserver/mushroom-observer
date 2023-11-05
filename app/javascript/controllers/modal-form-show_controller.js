import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

// MO doesn't print a pre-existing "dormant" Bootstrap modal form in the page
// because we want to let people have several modals in progress on same page.
// For example, you can start entering a collection number, close the modal,
// open a herbarium record form, close it and go back to the collection number
// and find the form form as you left it, or vice versa, until you submit.
export default class extends Controller {

  connect() {
    this.element.setAttribute("data-stimulus", "connected")
  }

  // NOTE: the button must pass :prevent with the action,
  // a Stimulus shortcut that calls event.preventDefault()
  showModal() {
    // check if modal exists in DOM. by ID of modal with identifier
    const modalSelector = this.element.getAttribute("data-turbo-frame")
    // console.log(modalSelector)
    const destination = this.element.getAttribute("href")

    if (document.getElementById(modalSelector)) {
      // if so, show.
      $(document.getElementById(modalSelector)).modal('show')
    } else {
      // if not, fetch the content.
      this.fetchModalAndAppendToBody(modalSelector, destination)
    }
  }

  // https://discuss.hotwired.dev/t/is-this-correct-a-stimulus-controller-to-use-turbo-stream-get-requests-to-avoid-updating-browser-history/4146
  // NOTE: Above example presumes a pre-existing modal.
  async fetchModalAndAppendToBody(modalSelector, destination) {
    // console.log(destination)

    const response = await get(destination, { responseKind: "turbo-stream" })

    if (response.ok) {
      // console.log(response)
      // turbo-stream prints the modal in the page already,
      // so we just have to move it.
      const _modal = document.getElementById(modalSelector)
      document.body.appendChild(_modal)
      $(_modal).modal('show')
    }
  }
}
