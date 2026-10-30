import { Controller } from "@hotwired/stimulus";

// Moves the Details panel between its desktop home (first in the
// right column) and right after the carousel in the left column
// (mobile reading order: carousel, details, namings, comments, ...).
// Every other panel keeps the same relative order in both layouts --
// Bootstrap's column stacking handles those for free -- so Details
// is the only element that needs to move.
//
// 992px matches $screen-md-min in mo/_variables.scss; keep the two
// in sync if that breakpoint ever changes.
export default class extends Controller {
  static targets = ["details", "carousel", "rightColumn"];

  connect() {
    this.mediaQuery = window.matchMedia("(min-width: 992px)");
    this.placeDetails = this.placeDetails.bind(this);
    this.mediaQuery.addEventListener("change", this.placeDetails);
    this.placeDetails();
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.placeDetails);
  }

  placeDetails() {
    if (this.mediaQuery.matches) {
      this.rightColumnTarget.prepend(this.detailsTarget);
    } else {
      this.carouselTarget.after(this.detailsTarget);
    }
  }
}
