import { Controller } from "@hotwired/stimulus"

// Stops a click from bubbling to document, so Bootstrap's dropdown
// doesn't close on a checkbox-label click (its own "stay open"
// exemption only matches a bare <input>/<textarea> target).
// Connects to data-controller="stop-propagation"
export default class extends Controller {
  stop(event) {
    event.stopPropagation()
  }
}
