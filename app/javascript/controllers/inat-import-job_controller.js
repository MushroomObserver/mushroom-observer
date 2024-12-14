import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below

// Updates the inat_import_job page with the current status of the import
// Connects to data-controller="inat-import-job"
export default class extends Controller {
  static targets = ["status"]

  initialize() {
    // wherever the AJAX is going is printed on the element as a data attribute,
    // so it can be different per PDF. More importantly, it's in ruby so it can
    // be different in development, test and production
    this.intervalId = null
    this.endpoint_url = this.element.dataset.endpoint
  }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.stimulus = "inat-import-job-connected";
    this.status_id = this.element.dataset.status

    this.start_timer_sending_requests()
  }

  // Clear any intervals when the controller is disconnected
  disconnect() {
    const stimulus = this.element.dataset.stimulus.split(" ")
    if (stimulus.includes("inat-import-job-connected")) {
      const idx = stimulus.indexOf("inat-import-job-connected")
      stimulus.splice(idx, 1)
      this.element.setAttribute("data-stimulus", stimulus.join(" "))
    }
    if (this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }

  // Every second, send a get request to find out the status import_job.
  // NOTE: Can't call a class function from `setInterval` because it resets
  // the context of `this`
  start_timer_sending_requests() {
    // Done: 4
    // NOTE: Can this be written without a magic number?
    // Something like InatImport.states[:Done]
    if (this.status_id != "4") {
      // Set the intervalId to the interval so we can clear it later
      this.intervalId = setInterval(async () => {
        console.log("sending fetch request to " + this.endpoint_url)
          const response = await get(this.endpoint_url,
                                     { responseKind: "turbo-stream" });
        if (response.ok) {
          // Turbo replaces the element in the page already
        } else {
          console.log(`got a ${response.status}`);
        }
      }, 1000);
    } else {
      // If the import is done, we can remove this Stimulus controller from the
      // element and stop the timer. (NOTE: there may be other controllers.)
      console.log("inat-import-job is done")
      const controllers = this.element.dataset.controller.split(" ")
      if (controllers.includes("inat-import-job")) {
        const idx = controllers.indexOf("inat-import-job")
        controllers.splice(idx, 1)
        this.element.setAttribute("inat-import-job", controllers.join(" "))
      }
    }
  }
}
