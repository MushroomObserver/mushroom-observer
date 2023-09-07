import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  initialize() {
    console.log("Hello Modal");
  }

  connect() {
    this.element.textContent = "Hello World!"
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
