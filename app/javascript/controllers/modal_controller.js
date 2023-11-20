import { Controller } from "@hotwired/stimulus"

// Controller just removes modal. it's a handler for page elements that
// get updated on successful form submit, so it "cleans up"
export default class extends Controller {
  // static targets = ["form"] // unused rn

  connect() {
    // console.log("Hello Modal " + this.element.id);
    this.element.dataset.stimulus = "connected";
  }

  // Form is only removed in the event that the page section updates.
  // That event is broadcast from the section-update controller.
  // We can't fire on form submit response, because unless something's wrong
  // turbo-stream will send a 200 response.
  remove() {
    console.log("Removing modal")
    $(this.element).modal('hide')
    this.element.remove()
  }
}
