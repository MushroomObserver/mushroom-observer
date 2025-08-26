import { Controller } from "@hotwired/stimulus"
import * as qs from "qs-esm"

// Connects to data-controller="query-results"
//
// Because MO caches matrix-boxes as HTML, the cached HTML (possibly rendered
// for some other user) will contain links with a `q` param from the original
// user's query. Clicking any of these links can put the current users in the
// middle of the original user's query results for the rest of their session,
// and this will lead to very unexpected results if either query was filtered
// by the user.
//
// However, the cache really speeds up page load. So this Stimulus controller
// overwrites the cached links' `q` param with the current user's correct `q`
// param. We print that encoded `q` param on the outer `#results` div wrapping
// all ".matrix-box" elements, and this is not cached, so the string is
// guaranteed to be correct for the current user.
//
export default class extends Controller {
  static targets = ['link']

  connect() {
    this.element.dataset.queryResults = "connected";
    // Here, `this.queryString` is the current user's encoded `q` object,
    // stored on the `#results` div.
    this.queryString = this.element.closest("#results").dataset.q;
    this.syncQueryStringToLinks();
  }

  // Because `q` is now an object of query params encoded by Rails, it doesn't
  // have the structure "?q=" that JS `searchParams` expects. We could do a
  // crude url split, but we might miss other possible params.
  //
  // We use `qs` to parse the whole query string and substitute in
  // the user's correct `q`, leaving other possible params intact, and
  // re-stringifying the whole qs back to the link href attribute.
  syncQueryStringToLinks() {
    if (this.queryString && this.hasLinkTarget) {
      this.linkTargets.forEach((link) => {
        const url = new URL(link.href),
          cached_encoded_qs = url.search.split("?")[1],
          decoded_cached_qs = decodeURIComponent(cached_encoded_qs),
          parsed_qs = qs.parse(decoded_cached_qs),
          decoded_current_q = decodeURIComponent(this.queryString),
          parsed_current_q = qs.parse(decoded_current_q)

        parsed_qs["q"] = parsed_current_q
        const encoded_current_qs = qs.stringify(parsed_qs)

        link.href = url.pathname + "?" + encoded_current_qs
        link.classList.add("query-synced")
      })
    }
  }
}
