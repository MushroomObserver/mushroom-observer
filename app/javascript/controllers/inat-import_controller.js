import { Controller } from "@hotwired/stimulus"

// Guard: one sync per (element-id + status) combination so a Turbo Stream
// replacement that carries the same status doesn't re-trigger an infinite
// fetch loop. The module persists across Turbo Drive visits (Turbo does not
// reload JS), so clear it on `turbo:before-visit`: leaving and returning to
// an in-progress import then re-runs the one-shot catch-up fetch. A Turbo
// Stream replace is not a visit, so the loop guard stays intact within a page.
const synced = new Set()
document.addEventListener("turbo:before-visit", () => synced.clear())

// Client-side stopwatch for the iNat import status panel.
// Seeded from data-inat-import-elapsed-value / data-inat-import-remaining-value
// on connect so the display is immediately accurate. Ticks every second until
// the import is Done. Auto-restarts when Turbo replaces the element (the
// broadcast update carries fresh elapsed/remaining values from the server).
//
// Catch-up fetch: if the job finishes before the Turbo Stream WebSocket
// connects, broadcasts are missed. On connect (when not Done), we schedule a
// one-shot fetch of the show URL with Accept: turbo-stream after 2 seconds.
// The response is a turbo-stream replace that brings the panel up to date.
// The `synced` Set ensures each (element + status) pair is fetched at most
// once, preventing a replace → connect → fetch → replace loop.
export default class extends Controller {
  static targets = ["elapsed", "remaining"]
  static values = {
    status: String,
    elapsed: Number,
    remaining: Number,
    statusUrl: String
  }

  connect() {
    this._elapsed = this.elapsedValue
    this._remaining = this.hasRemainingValue ? this.remainingValue : null
    this._intervalId = null
    this._syncTimerId = null
    if (this.statusValue !== "Done") {
      this._startTimer()
      this._scheduleSyncIfNeeded()
    }
  }

  disconnect() {
    this._stopTimer()
    if (this._syncTimerId !== null) clearTimeout(this._syncTimerId)
  }

  statusValueChanged(value) {
    if (value === "Done") this._stopTimer()
  }

  _scheduleSyncIfNeeded() {
    if (!this.hasStatusUrlValue) return
    const key = `${this.element.id}:${this.statusValue}`
    if (synced.has(key)) return
    synced.add(key)
    this._syncTimerId = setTimeout(() => this._syncCurrentState(), 2000)
  }

  _syncCurrentState() {
    fetch(this.statusUrlValue, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
      .then((r) => (r.ok ? r.text() : null))
      .then((html) => {
        if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
      })
      .catch(() => {})
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
    if (this._remaining !== null && this._remaining > 0) this._remaining -= 1

    if (this.hasElapsedTarget)
      this.elapsedTarget.textContent = this._formatSeconds(this._elapsed)
    if (this.hasRemainingTarget && this._remaining !== null)
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
