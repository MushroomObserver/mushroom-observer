import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  // this should remove modal. it's a handler for page elements that
  // get updated on successful form submit, so it "cleans up"
  connect() {
    // console.log("Hello Modal");
    this.element.setAttribute("data-stimulus", "connected")
  }

  // Target form has action turbo:submit-end->modal-form#maybeRemove
  // that will fire the next event if response is ok.
  formTargetConnected(element) {
    // console.log("connecting target")
    // console.log(element)
    element.setAttribute("data-stimulus", "target-connected")
  }

  // We want to keep the modal around in case there were form errors
  maybeRemove(event) {
    // console.log("maybe removing modal")
    // console.log(event.detail)
    // console.log(this.element)
    if (event.detail.formSubmission.result.success) {
      // console.log("removing modal")
      $(this.element).modal('hide')
      this.element.remove()
    } else {
      console.log("not removing modal")
    }
  }

}
