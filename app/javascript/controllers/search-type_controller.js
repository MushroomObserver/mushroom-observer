import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js" // allows us to call `get` below
import { delegate, abnegate } from 'jquery-events-to-dom-events'

// https://github.com/leastbad/jquery-events-to-dom-events
// We use a Stimulus action that listens to `$shown.bs.collapse` on the div
// (note the `$`). This depends on using `delegate` from the imported library
// jquery-events-to-dom-events. `delegate` listens for `shown.bs.collapse`, a
// jQuery event (not a native JS event), and dispatches a native event (with $).
//
// If moving to BS 5, can remove.

// Connects to data-controller="search-type"
export default class extends Controller {
  // targetHelp is the collapse div where help text or form will be rendered
  static targets = ["select", "bar", "barToggle", "help", "helpToggle",
    "form", "formToggle"]
  // helpTypes are PatternSearch classes, formTypes are existing faceted forms.
  static values = { helpTypes: Array, formTypes: Array }

  connect() {
    this.element.dataset.searchType = "connected"
    this.delegate = delegate('shown.bs.collapse')
    this.getHelp()
    this.getForm()
  }

  disconnect() {
    abnegate('shown.bs.collapse', this.delegate)
  }

  async getHelp(event) {
    // event.stopPropagation()

    const url = this.helpUrl()
    // console.log(`got url ${url}`);

    if (!url) {
      this.hideHelp()
      return
    }

    const response = await get(url, { responseKind: "turbo-stream" });
    if (response.ok) {
      // Turbo updates the element in the page already
      this.helpToggleTarget.classList.remove("d-none")
    } else {
      console.log(`got a ${response.status}`);
    }
  }

  // Fires when search-type select is changed
  // Both empties the collapse div and hides the toggle, to avoid confusion
  hideHelp() {
    this.helpTarget.innerHTML = ""
    this.helpToggleTarget.classList.add("d-none")
  }

  // The path to the :show action of the relevant #{Model}::SearchController
  helpUrl() {
    const controller = this.selectTarget.value
    if (!controller || !this.helpTypesValue.includes(controller)) {
      return null
    }

    return "/" + controller + "/search"
  }

  async getForm(event) {
    // event.stopPropagation()

    const url = this.formUrl()
    // console.log(`got url ${url}`);

    if (!url) {
      this.hideForm()
      return
    }

    const response = await get(url, { responseKind: "turbo-stream" });
    if (response.ok) {
      // Turbo updates the element in the page already
      this.formToggleTarget.classList.remove("d-none")
    } else {
      console.log(`got a ${response.status}`);
    }
  }

  // Fires when search-type select is changed
  // Both empties the collapse div and hides the toggle, to avoid confusion
  hideForm() {
    this.formTarget.innerHTML = ""
    this.formToggleTarget.classList.add("d-none")
  }

  // The path to the :new action of the relevant #{Model}::SearchController
  formUrl() {
    const controller = this.selectTarget.value
    if (!controller || !this.formTypesValue.includes(controller)) {
      return null
    }

    return "/" + controller + "/search/new"
  }

  // Bootstrap 3 accordions require css panels,
  // so we have to make our own accordion functionality.
  closeBar(event) {
    // console.log("closeBar")
    if (this.hasBarTarget) {
      $(this.barTarget).collapse("hide")
    }
    if (this.hasHelpTarget) {
      $(this.helpTarget).collapse("hide")
    }
  }

  closeForm(event) {
    // console.log("closeForm")
    if (this.hasFormTarget) {
      $(this.formTarget).collapse("hide")
    }
  }
}
