import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="advanced-search"
export default class extends Controller {
  static targets = ["searchModel", "filter"]

  connect() {
    this.disableUnusedFilters();
  }

  disableUnusedFilters() {
    const model = this.searchModelTarget.value;

    this.filterTargets.forEach((filter) => {
      const models = filter.dataset.models

      if (models.indexOf(model) >= 0) {
        filter.classList.remove('disabled')
        filter.querySelector('input').disabled = false
      } else {
        filter.classList.add('disabled')
        filter.querySelector('input').disabled = true
      }
    })
  }
}
