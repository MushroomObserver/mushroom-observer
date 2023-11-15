import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lazyload"
export default class extends Controller {
  connect() {
    if (window.lazyLoadInstance != undefined)
      window.lazyLoadInstance.update();
  }
}
