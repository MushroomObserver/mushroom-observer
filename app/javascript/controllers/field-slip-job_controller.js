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
    this.endpoint_url = this.dataset.endpoint
    this.tracker_id = this.dataset.trackerId
    this.intervalId = null
  }

  connect() {
    // just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.stimulus = "connected";

    if (this.statusTarget.innerHTML == "Processing") {
      this.start_timer_sending_requests();
    } else if (this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }

  start_timer_sending_requests() {
    // every second, send an get request to find out the doneness of the PDF
    // timer should call this.send_fetch_request(this.tracker_id)
    this.intervalId = setInterval(this.send_fetch_request, 1000);
  }

  async send_fetch_request() {
    url = this.endpoint_url // or however param gets incorporated into the URL
    const response = await get(url, { responseKind: "turbo-stream" });
    if (response.ok) {
      // turbo-stream prints the row in the page already
    } else {
      console.log(`got a ${response.status}`);
    }
  }
}
