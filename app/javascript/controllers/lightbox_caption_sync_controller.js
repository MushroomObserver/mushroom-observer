import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lightbox-caption-sync"
// Registers a custom Turbo Stream action to update lightbox captions
export default class extends Controller {
  connect() {
    // Register custom Turbo Stream action
    // Don't bind - let 'this' be the turbo-stream element when Turbo calls it
    Turbo.StreamActions.update_lightbox_caption = function () {
      const obsId = this.getAttribute("obs-id");
      // Use innerHTML to get actual HTML, not textContent which escapes it
      const template = this.templateElement;
      const captionHtml = template.innerHTML;

      const theaterBtn = document.querySelector(`#box_${obsId} .theater-btn`);

      if (theaterBtn) {
        theaterBtn.dataset.subHtml = captionHtml;

        // Refresh lightgallery to pick up the updated caption
        const contentElement = document.querySelector('[data-controller~="lightgallery"]');
        if (contentElement && contentElement.dataset.lightgallery === "connected") {
          // Trigger a custom event that the lightgallery controller can listen to
          contentElement.dispatchEvent(new CustomEvent('lightgallery:refresh'));
        }
      }
    };
  }

  disconnect() {
    // Clean up custom action
    delete Turbo.StreamActions.update_lightbox_caption;
  }
}
