// app/javascript/controllers/project_search_controller.js
import { Controller } from "@hotwired/stimulus"

// Nathan: I think these methods could be generalized to the point that this
// can be combined with status-light into a "search-match-status" controller
// initialized with an array of strings, but you'll be the better judge of that.
// In that case, we wouldn't have to dispatch an event from here and catch it
// in the status-light Stimulus controller.
export default class extends Controller {
  static values = { names: Array }
  static targets = ["input"]

  connect() {
    this.element.dataset.projectSearch = "connected";
    // console.log("Project search controller connected")
    // console.log("Names data:", this.namesValue)
  }

  checkMatch(event) {
    const inputValue = event.target.value.toLowerCase().trim()
    // console.log("Checking match for:", inputValue)

    // If no input, show the "off" message
    if (!inputValue) {
      // console.log("checkMatch: Empty input, setting to off")
      this.dispatch("hasMatch", { detail: { status: "off" } })
      return
    }

    // Check if input matches the start of any name in the project
    const hasMatch = this.namesValue.some(nameObj =>
      nameObj.text_name.toLowerCase().startsWith(inputValue)
    )

    const status = hasMatch ? "green" : "red"
    this.dispatch("hasMatch", { detail: { status: status } })
  }
}
