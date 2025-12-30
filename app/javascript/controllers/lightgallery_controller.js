import { Controller } from "@hotwired/stimulus"
import lightGallery from 'lightgallery'
import lgZoom from 'lightgallery/plugins/zoom'

// Connects to data-controller="lightgallery", currently "#content"
export default class extends Controller {
  connect() {
    this.element.dataset.lightgallery = "connected";

    this.gallery = lightGallery(this.element, {
      selector: '.theater-btn',
      plugins: [lgZoom],
      licenseKey: '3B4BAB91-98EF-411A-975E-3334D00D1A8C',
      defaultCaptionHeight: 200
    });

    // Listen for refresh events
    this.boundRefresh = this.refresh.bind(this);
    this.element.addEventListener('lightgallery:refresh', this.boundRefresh);

    // Register custom Turbo Stream action for updating lightbox captions
    this.registerTurboStreamAction();
  }

  disconnect() {
    if (this.gallery) {
      this.gallery.destroy();
    }
    if (this.boundRefresh) {
      this.element.removeEventListener('lightgallery:refresh', this.boundRefresh);
    }
    delete Turbo.StreamActions.update_lightbox_caption;
  }

  // Refresh the gallery to pick up updated data-sub-html attributes
  refresh() {
    if (this.gallery) {
      this.gallery.refresh();
    }
  }

  // Register custom Turbo Stream action to update lightbox captions.
  // Standard Turbo Stream actions operate on element content, but captions
  // are stored in data-sub-html attributes, requiring a custom action.
  registerTurboStreamAction() {
    const controller = this;
    Turbo.StreamActions.update_lightbox_caption = function () {
      const obsId = this.getAttribute("obs-id");
      const captionHtml = this.templateElement.innerHTML;
      controller.updateCaption(obsId, captionHtml);
    };
  }

  // Update the caption for a specific observation's lightbox
  updateCaption(obsId, captionHtml) {
    const theaterBtn = this.element.querySelector(`#box_${obsId} .theater-btn`);

    if (theaterBtn) {
      theaterBtn.dataset.subHtml = captionHtml;
      this.refresh();
    }
  }
}
