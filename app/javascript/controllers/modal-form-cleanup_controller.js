import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  // this should remove modal. it's a handler for page elements that
  // get updated on successful form submit, so it "cleans up"
  connect() {
    // console.log("Hello Modal");
    this.element.setAttribute("data-thing", "this")
  }

  removeModal() {
    console.log(this.modalTarget.html())
    const modalSelector = this.element.getAttribute("data-updated-by")
    console.log(modalSelector)
    $(document.getElementById(modalSelector)).modal('hide')
    document.getElementById(modalSelector).remove()
  }

}
