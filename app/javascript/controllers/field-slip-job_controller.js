import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below

// Updates the field slip job page with the current status of the PDF
// Connects to data-controller="field-slip-job"
export default class extends Controller {
  static targets = ["link", "seconds", "pages", "status"]

  initialize() {
    // wherever the AJAX is going is printed on the element as a data attribute,
    // so it can be different per PDF. More importantly, it's in ruby so it can
    // be different in development, test and production
    this.intervalId = null
    this.endpoint_url = this.element.dataset.endpoint
  }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.fieldSlipJob = "connected";
    this.status_id = this.element.dataset.status

    this.start_timer_sending_requests()
  }

  // Clear any intervals when the controller is disconnected
  disconnect() {
    this.element.removeAttribute("data-field-slip-job")
    if (this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }

  // Every second, send a get request to find out the status of the PDF.
  // NOTE: Can't call a class function from `setInterval` because it resets
  // the context of `this`
  start_timer_sending_requests() {
    if (this.status_id != "3") {
      // Set the intervalId to the interval so we can clear it later
      this.intervalId = setInterval(async () => {
        // console.log("sending fetch request to " + this.endpoint_url)
        const response = await get(this.endpoint_url,
          { responseKind: "turbo-stream" });
        if (response.ok) {
          // Turbo replaces the row in the page already
        } else {
          console.log(`got a ${response.status}`);
        }
      }, 1000);
    } else {
      // If the PDF is done, we can remove this Stimulus controller from the
      // element and stop the timer. (NOTE: there may be other controllers.)
      // console.log("field-slip-job is done")
      const controllers = this.element.dataset.controller.split(" ")
      if (controllers.includes("field-slip-job")) {
        const idx = controllers.indexOf("field-slip-job")
        controllers.splice(idx, 1)
        this.element.setAttribute("data-controller", controllers.join(" "))
      }
    }
  }
}
