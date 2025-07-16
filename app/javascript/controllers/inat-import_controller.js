import { Controller } from "@hotwired/stimulus"

// Updates the inat_import_job page with the current status of the import
// Connects to data-controller="inat-import-job"
export default class extends Controller {
  static targets = ["elapsed", "remaining"]

  initialize() {
    this.intervalId = null
  }

  connect() {
    // Just a "sanity check" convention, so you can tell "is this thing on?"
    this.element.dataset.inatImport = "connected"

    this.start_timer()
  }

  // Clear any intervals when the controller is disconnected
  disconnect() {
    if (this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }

  // Every second, send a get request to find out the status of the import.
  // `status` data attribute of `currentTarget` is updated with each request.
  start_timer() {
    if (this.element.dataset.status != "Done") {
      // Set the intervalId to the interval so we can clear it later
      this.intervalId = setInterval(
        this.tick_elapsed_up_and_estimated_down(), 1000
      )
    }
  }

  tick_elapsed_up_and_estimated_down() {
    // this.adjust_time(this.elapsedTarget, 1)
    // this.adjust_time(this.remainingTarget, -1)
  }

  adjust_time(target, amount) {
    // Parse the time string
    const timeString = "10:30:45";
    const [hours, minutes, seconds] = timeString.split(':').map(Number);
    // Create a Date object with current date, but we'll set the time
    const date = new Date();
    date.setHours(hours, minutes, seconds);
    // Add one second
    date.setSeconds(date.getSeconds() + amount)

    // Format the resulting time
    const newHours = String(date.getHours()).padStart(2, "0");
    const newMinutes = String(date.getMinutes()).padStart(2, "0");
    const newSeconds = String(date.getSeconds()).padStart(2, "0");
    const newTimeString = `${newHours}:${newMinutes}:${newSeconds}`;

    console.log(`Original time: ${timeString}`)
    console.log(`Time after adding one second: ${newTimeString}`)

    // update the target
    target.textContent = newTimeString
  }

  check_if_we_are_done() {
    if (this.element.dataset.status == "Done" && this.intervalId != null) {
      clearInterval(this.intervalId)
    }
  }
}
