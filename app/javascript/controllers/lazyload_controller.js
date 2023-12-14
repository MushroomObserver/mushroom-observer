import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lazyload"
export default class extends Controller {
  connect() {
    this.element.dataset.stimulus = "connected";

    if (window.lazyLoadInstance != undefined)
      window.lazyLoadInstance.update();
  }
}
