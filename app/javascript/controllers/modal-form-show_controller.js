import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {

  initialize() {
    console.log("Hello Turbo");
  }

  connect() {
    this.element.textContent = "Hello Turbo!"
  }

  // TODO: Check if the default is to follow the link, which would return the
  // turbo response, or bs-open the modal. Passing :default with the action!
  showModal() {

    // check if modal exists in DOM. bs-target has ID of modal with identifier
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

  // prob. this presumes a pre-existing modal
  // https://discuss.hotwired.dev/t/is-this-correct-a-stimulus-controller-to-use-turbo-stream-get-requests-to-avoid-updating-browser-history/4146
  async fetchModalAndAppendToBody(modalSelector, destination) {
    // console.log(destination)

    const response = await get(destination, { responseKind: "turbo-stream" })

    if (response.ok) {
      // console.log(response)
      const formHtml = await response.text
      // console.log(formHtml)
      document.querySelector('body')
        .insertAdjacentHTML('beforeend', formHtml)
      $(document.getElementById(modalSelector)).modal('show')
    }
  }
}
