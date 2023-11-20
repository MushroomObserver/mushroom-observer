import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="name-panels"
// TODO: eliminate this controller if moving to Bootstrap 4,
// which uses CSS flex to make them equal automatically
export default class extends Controller {
  static targets = ['classification', 'lifeform']

  connect() {
    this.element.dataset.stimulus = "connected";
    this.equalizePanelHeights()
  }

  equalizePanelHeights() {
    if (this.hasClassificationTarget && this.hasLifeformTarget) {
      let h1 = this.classificationTarget.offsetHeight;
      let h2 = this.lifeformTarget.offsetHeight;
      if (h1 > h2) this.lifeformTarget.style.height = h1 + "px";
      if (h1 < h2) this.classificationTarget.style.height = h2 + "px";
    } else {
      alert("Missing target panels")
    }
  }
}
