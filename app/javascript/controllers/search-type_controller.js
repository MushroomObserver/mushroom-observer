import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below

// Connects to data-controller="search-type"
export default class extends Controller {
  // targetHelp is the collapse div where help text or form will be rendered
  static targets = ["select", "help", "toggle", "form"]
  // helpTypes are PatternSearch classes, formTypes are existing faceted forms.
  static values = { helpTypes: Array, formTypes: Array }

  connect() {
    this.element.dataset.searchType = "connected";
  }

  async getHelp(event) {
    event.stopPropagation()

    const url = this.helpUrl()
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

  // The path to the :show action of the relevant #{Model}::SearchController
  helpUrl() {
    const controller = this.selectTarget.value
    if (!controller || !this.helpTypesValue.includes(controller)) {
      return null
    }

    return "/" + controller + "/search"
  }

  // The path to the :new action of the relevant #{Model}::SearchController
  formUrl() {
    const controller = this.selectTarget.value
    if (!controller || !this.formTypesValue.includes(controller)) {
      return null
    }

    return "/" + controller + "/search/new"
  }
}
