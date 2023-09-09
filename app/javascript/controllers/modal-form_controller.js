import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  // this should remove modal. it's a handler for page elements that
  // get updated on successful form submit, so it "cleans up"
  connect() {
    // console.log("Hello Modal");
    this.element.setAttribute("data-stimulus", "connected")
  }

  formTargetConnected(element) {
    console.log("connecting target")

    this.element.setAttribute("data-stimulus", "target-connected")
  }

  maybeRemove(event) {
    console.log("Remove Modal")
    console.log(event.detail)
    //   $(document.getElementById(modalSelector)).modal('hide')
    //   document.getElementById(modalSelector).remove()
  }

}
