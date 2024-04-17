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
  }

  connect() {
    // just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.stimulus = "connected";

    this.start_timer_sending_requests(); // we don't have to use camelCase, but that's fine too
  }

  start_timer_sending_requests() {
    // every second, send an get request to find out the doneness of the PDF
    // timer should call this.send_fetch_request(val)
  }

  async send_fetch_request(val) {
    url = this.endpoint_url + val // or however the param gets incorporated into the URL
    const response = await get(url);
    if (response.ok) {
      const json = await response.json
      if (json) {
        this.fetch_request = response
        this.process_fetch_response(json)
      }
    } else {
      this.fetch_request = null;
      console.log(`got a ${response.status}`);
    }
  }

  process_fetch_response(json) {
    secondsValue = json.secondsValue; // somehow parsed from the json
    pagesValue = json.pagesValue; // somehow parsed from the json
    this.updateSeconds(secondsValue);
    this.updatePages(pagesValue);
  }

  updateSeconds(secondsValue) {
    this.secondsTarget.innerHTML = secondsValue;
  }
}
