import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav", goes on "#main_container" div
export default class extends Controller {
  static targets = ['toggle', 'search', 'container', 'offcanvas', 'topNav']

  connect() {
    this.element.dataset.nav = "connected";
  }

  // HAMBURGER HELPER action to toggle offcanvas left nav
  toggleOffcanvas() {
    document.scrollTop = 0;
    this.offcanvasTarget.classList.toggle('active');
    this.containerTarget.classList.toggle('hidden-overflow-x');
  }
}
