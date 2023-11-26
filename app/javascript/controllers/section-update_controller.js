import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  // this is a handler for page elements that get updated
  // on successful form submit, so it "cleans up"
  connect() {
    this.element.dataset.stimulus = "connected";

    // Note: this is simpler than adding an action on every frame.
    // add event listener turbo:frame-render, call hide modal
    this.element.addEventListener("turbo:frame-render", this.updated())
  }

  updated() {
    // broadcast change
    console.log("Section updated");
    this.dispatch("updated")
  }

}
