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
    // just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.stimulus = "connected";
    this.status_id = this.element.dataset.status

    this.start_timer_sending_requests()
  }

  start_timer_sending_requests() {
    // every second, send an get request to find out the doneness of the PDF
    // timer should call this.send_fetch_request(this.tracker_id)
    // note the lack of parentheses, we're passing the function itself,
    // not the result of calling it
    if (this.status_id != "3") {
      this.intervalId = setInterval(this.initiate_fetch_request, 1000);
    } else if (this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }

  initiate_fetch_request() {
    this.send_fetch_request(this.endpoint_url)
  }

  // For some reason an async function doesn't have access to the same `this`
  async send_fetch_request(url) {
    console.log("sending fetch request to " + url)
    const response = await get(url, { responseKind: "turbo-stream" });
    if (response.ok) {
      // turbo-stream prints the row in the page already
    } else {
      console.log(`got a ${response.status}`);
    }
  }
}
