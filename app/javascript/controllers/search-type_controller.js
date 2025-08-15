import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below

// Connects to data-controller="search-type"
export default class extends Controller {
  static targets = ["select", "help", "button"]

  connect() {
    this.element.dataset.searchType = "connected";
    this.endpoint_url = "/search"
  }

  async getHelp(event) {
    event.stopPropagation()

    const url = this.endpointUrl()
    console.log(`got url ${url}`);

    if (!url) {
      this.emptyHelp()
      return
    }

    const response = await get(url, { responseKind: "turbo-stream" });
    if (response.ok) {
      // Turbo updates the element in the page already
      this.buttonTarget.classList.remove("d-none")
    } else {
      console.log(`got a ${response.status}`);
    }
  }

  emptyHelp() {
    this.helpTarget.innerHTML = ""
    this.buttonTarget.classList.add("d-none")
  }

  endpointUrl() {
    const controller = this.selectTarget.value,
      havingHelp = ["names", "observations"]

    if (!controller || !havingHelp.includes(controller)) {
      return null
    }

    return "/" + controller + "/search"
  }
}
