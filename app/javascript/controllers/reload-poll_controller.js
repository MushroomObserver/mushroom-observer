import { Controller } from "@hotwired/stimulus"

// Reloads the page on an interval, for pages that are waiting on a
// background job (e.g. a field slip extraction) and re-render
// themselves into their finished state once the work lands.
// Connects to data-controller="reload-poll"
export default class extends Controller {
  static values = { interval: { type: Number, default: 4000 } }

  connect() {
    this.element.dataset.reloadPoll = "connected";
    this.timer = setInterval(() => location.reload(), this.intervalValue)
  }

  disconnect() {
    if (this.timer != null) {
      clearInterval(this.timer)
    }
  }
}
