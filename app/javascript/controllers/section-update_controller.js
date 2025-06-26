import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="section-update"
export default class extends Controller {

  // this is a handler for page elements that get updated
  // on successful form submit, so it "cleans up"
  connect() {
    this.element.dataset.sectionUpdate = "connected"

    // Simpler than adding a data-action attribute on every section
    // replaced by Turbo?
    this.element.addEventListener("turbo:frame-render", this.updated())
  }

  updated() {
    // console.log(this.element.id + " turbo:frame-render section updated")
    // broadcast change
    this.dispatch("updated")
  }
}
