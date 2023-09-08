import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"
// import { modal } from "bootstrap" // try jQuery
// import { $ } from "jquery3"

export default class extends Controller {
  static targets = ["open", "modal"]

  initialize() {
    console.log("Hello Modal");
  }

  connect() {
    this.element.textContent = "Hello Modal!"
  }

  // TODO: Check if the default is to follow the link, which would return the
  // turbo response, or bs-open the modal
  showModal(event) {
    // maybe: preventDefault
    event.preventDefault

    // check if modal exists in DOM. bs-target has ID of modal with identifier
    const modalSelector = this.element.getAttribute("data-bs-target")
    console.log(modalSelector)
    const destination = this.element.getAttribute("href")

    if (document.querySelector(modalSelector)) {
      // if so, show.
      document.querySelector(modalSelector).modal('show')
    } else {
      // if not, fetch the content.
      this.fetchModalAndAppendToBody(modalSelector, destination)
    }
  }

  // prob. this presumes a pre-existing modal
  // https://discuss.hotwired.dev/t/is-this-correct-a-stimulus-controller-to-use-turbo-stream-get-requests-to-avoid-updating-browser-history/4146
  async fetchModalAndAppendToBody(modalSelector, destination) {
    console.log(destination)

    const response = await get(destination, { responseKind: "turbo-stream" })

    if (response.ok) {
      console.log(response)
      const formHtml = await response.text
      console.log(formHtml)
      document.querySelector('body').append(formHtml)
      $(modalSelector).modal('show')
    }
  }
}
