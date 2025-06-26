import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="section-update"
export default class extends Controller {

  // this is a handler for page elements that get updated
  // on successful form submit, so it "cleans up"
  connect() {
    this.element.dataset.stimulus = "section-update-connected"

    // Note: this is simpler than adding a data-action attribute on every
    // section replaced by Turbo
    this.element.addEventListener("turbo:frame-render", this.updated())
  }

  updated() {
    console.log(this.element.id + " turbo:frame-render section updated")
    // Remove modal which is present for certain updates (but not all)
    // Must be in jQuery for Boostrap 3 and 4
    $("#mo_ajax_progress").modal('hide')
    document.getElementById('mo_ajax_progress_caption').innerHTML = ""
    // broadcast change
    this.dispatch("updated")
  }
}
