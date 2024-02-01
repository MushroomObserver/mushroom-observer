import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="links"
export default class extends Controller {
  connect() {
    this.element.dataset.stimulus = "connected";
  }

  disable(e) {
    e.preventDefault();
    const link = e.target.href
    e.target.removeAttribute('href');
    e.target.style.pointerEvents = "none";
    e.target.innerHTML = "<span class='spinner-right'></span>";
    window.location = link
  }
}
