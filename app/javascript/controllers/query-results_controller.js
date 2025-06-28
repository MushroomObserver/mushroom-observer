import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="query-results"
//
// Because MO caches matrix-boxes as HTML, the cached HTML (possibly rendered
// for some other user) will contain links with a `q` param from the original
// user's query. Clicking any of these links can put users in the middle of the
// original user's query results for the rest of their session, and this will
// lead to very unexpected results if either query was filtered by the user.
//
// However, the cache really speeds up page load. So this Stimulus controller
// overwrites the cached links' `q` param with the current user's correct query
// string. We print that `q` string on the outer `#results` div wrapping all
// ".matrix-box" elements, and this is not cached, so the string is guaranteed
// to be correct for the current user.
//
export default class extends Controller {
  static targets = ['link']

  connect() {
    this.element.dataset.queryResults = "connected";
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
