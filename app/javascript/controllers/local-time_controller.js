import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="local-time"
// Converts a UTC ISO timestamp to local time display
export default class extends Controller {
  static values = { utc: String }

  connect() {
    this.formatLocalTime()
  }

  formatLocalTime() {
    if (!this.utcValue) return

    const date = new Date(this.utcValue)
    if (isNaN(date.getTime())) return

    // Format as YYYY-MM-DD HH:MM:SS in local time
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    const hours = String(date.getHours()).padStart(2, "0")
    const minutes = String(date.getMinutes()).padStart(2, "0")
    const seconds = String(date.getSeconds()).padStart(2, "0")

    this.element.textContent = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
  }
}
