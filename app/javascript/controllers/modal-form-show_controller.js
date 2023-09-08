import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request"

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
  showModal() {
    // maybe: preventDefault

    // check if modal exists in DOM. bs-target has ID of modal with identifier
    let modalSelector = this.element.getAttribute("data-bs-target")
    console.log(modalSelector)
    let destination = this.element.getAttribute("href")
    console.log(destination)

    if (document.querySelector(modalSelector)) {
      // if so, show.
      document.querySelector(modalSelector).modal('show')
    } else {
      // if not, fetch the content.
      this.fetchModalAndAppendToBody(destination)
    }
  }

  // prob. this presumes a pre-existing modal
  fetchModalAndAppendToBody(destination) {
    get(destination)
      .then(response => response.text())
      .then(html => document.querySelector('body').appendChild(html))
  }
}
