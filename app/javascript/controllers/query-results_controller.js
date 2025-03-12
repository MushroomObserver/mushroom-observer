import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="query-results"
export default class extends Controller {
  static targets = ['link']

  connect() {
    this.element.dataset.stimulus = "query-results-connected";
    this.queryString = this.element.closest("#results").dataset.q;
    this.syncQueryStringToLinks();
  }

  syncQueryStringToLinks() {
    if (this.queryString && this.hasLinkTarget) {
      this.linkTargets.forEach((link) => {
        const url = new URL(link.href);
        url.searchParams.set("q", this.queryString);
        // We want relative URLs, so we're not calling url.toString()
        link.href = url.pathname + url.search;
        link.classList.add("query-synced");
      })
    }
  }
}
