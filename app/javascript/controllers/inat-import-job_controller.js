import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below

// Updates the inat_import_job page with the current status of the import
// Connects to data-controller="inat-import-job"
export default class extends Controller {
  static targets = [
    "current"
  ]

  initialize() {
    this.intervalId = null
    this.endpoint_url = this.element.dataset.endpoint
  }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.inatImportJob = "connected";

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

  // Every second, send a get request to find out the status of the import.
  // `status` data attribute of `currentTarget` is updated with each request.
  start_timer_sending_requests() {
    if (this.currentTarget.dataset.status != "Done") {
      // Set the intervalId to the interval so we can clear it later
      this.intervalId = setInterval(async () => {
        console.log("sending fetch request to " + this.endpoint_url)
        const response = await get(this.endpoint_url,
          { responseKind: "turbo-stream" });
        if (response.ok) {
          // Turbo updates the element in the page already,
          // from the InatImport::JobTrackersController#show action
          this.check_if_we_are_done();
        } else {
          console.log(`got a ${response.status}`);
        }
      }, 1000);
    }
  }

  check_if_we_are_done() {
    if (this.currentTarget.dataset.status == "Done" &&
      this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }
}
