import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="suggestions"
export default class extends Controller {
  initialize() {
    this.localized_text = {}
    this.fetch_request = false
    this.predict_url = "https://images.mushroomobserver.org/model/predict"
    this.image_ids = []
  }

  connect() {
    this.progressModal = document.getElementById("mo_ajax_progress")
    this.progressCaption = document.getElementById("mo_ajax_progress_caption")
    Object.assign(this.localized_text,
      JSON.parse(this.element.dataset.localization));
    this.results_url = this.element.dataset.resultsUrl;
    this.image_ids = JSON.parse(this.element.dataset.imageIds);
  }

  suggestTaxa() {
    this.element.setAttribute("disabled", "disabled");
    this.progressCaption.innerHTML =
      this.localized_text.processing_images + "...";
    $(this.progressModal).modal("show");
    this.results = [];
    this.any_worked = false;
    debugger

    this.predict(0)
  }

  predict(i) {
    this.progressCaption.innerHTML = this.localized_text.processing_image +
      " " + (i + 1) + " / " + this.image_ids.length + "...";

    // This is a safeguard against double fetches
    const controller = new AbortController(),
      signal = controller.signal;

    if (this.fetch_request)
      controller.abort();

    this.fetch_request = fetch(this.predict_url, {
      method: "POST",
      mode: "no-cors",
      body: "?id=" + this.image_ids[i],
      signal
    }).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.text().then((text) => {
            this.results[i] = JSON.parse(text);
            this.any_worked = true;
            if (i + 1 < this.image_ids.length) {
              predict(i + 1);
            } else if (this.any_worked) {
              this.progressCaption.innerHTML =
                this.localized_text.processing_results + "...";

              const out = JSON.stringify(this.results);
              this.results_url =
                this.results_url.replace("xxx", encodeURIComponent(out));

              this.resetModal();
              window.open(this.results_url, "_blank");
            }
          }).catch((error) => {
            console.error("no_content:", error);
            this.progressCaption.innerHTML =
              this.localized_text.suggestions_error
            window.setTimeout(() => { this.resetModal(); }, 1000);
          });
        } else {
          this.fetch_request = null;
          console.log(`got a ${response.status}`);
        }
      }
    }).catch((error) => {
      // console.error("Server Error:", error);
    });
  }

  resetModal() {
    this.progressModal.innerHTML = "";
    $(this.progressModal).modal("hide");
    this.element.setAttribute("disabled", null);
  }
}
