import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="links"
export default class extends Controller {
  connect() {
    this.element.dataset.links = "connected";
  }

  // A link inside a Bootstrap carousel indicator. The carousel's
  // click handler is delegated on the document for
  // [data-slide-to] and ends in preventDefault, so a click that
  // reaches it cancels the link. Keeping the click here lets the
  // link navigate; the slide does not change, which is right --
  // the reader asked for the observation, not the photo.
  follow(e) {
    e.stopPropagation();
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
