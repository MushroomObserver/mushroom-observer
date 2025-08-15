import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below

// Connects to data-controller="search-type"
export default class extends Controller {
  // targetHelp is the collapse div where help text will be rendered
  static targets = ["select", "help", "toggle"]
  // types are the
  static values = { helpTypes: Array }

  connect() {
    this.element.dataset.searchType = "connected";
    this.endpoint_url = "/search"
  }

  async getHelp(event) {
    event.stopPropagation()

    const url = this.endpointUrl()
    // console.log(`got url ${url}`);

    if (!url) {
      this.hideHelp()
      return
    }

    const response = await get(url, { responseKind: "turbo-stream" });
    if (response.ok) {
      // Turbo updates the element in the page already
      this.toggleTarget.classList.remove("d-none")
    } else {
      console.log(`got a ${response.status}`);
    }
  }

  // Both empties the collapse div and hides the toggle, to avoid confusion
  hideHelp() {
    this.helpTarget.innerHTML = ""
    this.toggleTarget.classList.add("d-none")
  }

  endpointUrl() {
    const controller = this.selectTarget.value

    if (!controller || !this.helpTypesValue.includes(controller)) {
      return null
    }

    return "/" + controller + "/search"
  }
}
