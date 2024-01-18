import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-active"
// Adds CSS class "active" to a nav link if it matches the current location
export default class extends Controller {
  static targets = ['link']

  connect() {
    this.element.dataset.stimulus = "connected";
    this.pickActive();
  }

  pickActive() {
    this.linkTargets.forEach((link) => {
      if ((link.pathname + link.search) ==
        (location.pathname + location.search)) {
        link.classList.add('active')
      }
    })
  }

  navigate(e) {
    const activeButton = this.element.querySelector('.active')

    if (activeButton) {
      activeButton.classList.remove('active')
    }

    e.target.classList.add('active')
  }
}
