import { Controller } from "@hotwired/stimulus"
import lightGallery from 'lightgallery'
import lgZoom from 'lightgallery/plugins/zoom'

// Connects to data-controller="lightgallery", currently "#content"
export default class extends Controller {
  connect() {
    this.element.dataset.lightgallery = "connected";

    lightGallery(this.element, {
      selector: '.theater-btn',
      plugins: [lgZoom],
      licenseKey: '3B4BAB91-98EF-411A-975E-3334D00D1A8C',
      defaultCaptionHeight: 200
    });
  }
}
