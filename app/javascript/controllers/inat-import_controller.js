import { Controller } from "@hotwired/stimulus"

// Client-side stopwatch for the iNat import status panel.
// Seeded from data-inat-import-elapsed-value / data-inat-import-remaining-value
// on connect so the display is immediately accurate. Ticks every second until
// the import is Done. Auto-restarts when Turbo replaces the element (the
// broadcast update carries fresh elapsed/remaining values from the server).
export default class extends Controller {
  static targets = ["elapsed", "remaining"]
  static values = {
    status: String,
    elapsed: Number,
    remaining: Number
  }

  connect() {
    this._elapsed = this.elapsedValue
    this._remaining = this.remainingValue
    this._intervalId = null
    if (this.statusValue !== "Done") this._startTimer()
  }

  disconnect() {
    this._stopTimer()
  }

  statusValueChanged(value) {
    if (value === "Done") this._stopTimer()
  }

  _startTimer() {
    this._intervalId = setInterval(() => this._tick(), 1000)
  }

  _stopTimer() {
    if (this._intervalId !== null) {
      clearInterval(this._intervalId)
      this._intervalId = null
    }
  }

  _tick() {
    this._elapsed += 1
    if (this._remaining > 0) this._remaining -= 1

    if (this.hasElapsedTarget)
      this.elapsedTarget.textContent = this._formatSeconds(this._elapsed)
    if (this.hasRemainingTarget)
      this.remainingTarget.textContent = this._formatSeconds(this._remaining)
  }

  _formatSeconds(total) {
    if (total == null || total < 0) return "00:00:00"
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = Math.floor(total % 60)
    return [h, m, s].map(n => String(n).padStart(2, "0")).join(":")
  }
}
