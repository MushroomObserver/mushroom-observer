import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="section-update"
export default class extends Controller {

  // this is a handler for page elements that get updated
  // on successful form submit, so it "cleans up"
  connect() {
    this.element.dataset.stimulus = "section-update-connected";

    // Note: this is simpler than adding an action on every frame. hides modal
    this.element.addEventListener("turbo:frame-render", this.updated());
    // this.element.addEventListener("turbo:before-stream-render", this.updated());
    // this.element.addEventListener("turbo:submit-end", this.updated());
  }

  updated() {
    // Remove modal which is present for certain updates (but not all)
    // Must be in jQuery for Boostrap 3 and 4
    $("#mo_ajax_progress").modal('hide');
    document.getElementById('mo_ajax_progress_caption').innerHTML = "";
    console.log("Section updated");
    // broadcast change
    this.dispatch("updated");
  }

}
