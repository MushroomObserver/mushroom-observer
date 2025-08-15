import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search-model"
export default class extends Controller {
  connect() {
    this.element.dataset.searchModel = "connected";
  }
}
