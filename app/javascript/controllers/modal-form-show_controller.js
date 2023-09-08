import { Controller } from "@hotwired/stimulus"

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
    let modalSelector = this.element.getAttribute("bs-target")
    if (modalSelector.length)
      // if so, show.
      modalSelector.modal.show
    else
      // if not, fetch the content.
      fetchModalContent
    end

    // document.querySelector('body').appendChild(targetModal);
  }

  fetchModalContent() {
    let href = this.element.getAttribute("href")

    let frame_id = "turbo-frame#" +
      this.element.getAttribute("data-turbo-frame")
    let frame = document.querySelector(frame_id)

    frame.src = href
    frame.reload()
  }
}
