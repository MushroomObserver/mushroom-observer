import { Controller } from "@hotwired/stimulus"

// Client-side stopwatch for the iNat import status panel.
// Seeded from data-inat-import-elapsed-value / data-inat-import-remaining-value
// on connect so the display is immediately accurate. Ticks every second until
// the import is Done. Auto-restarts when Turbo replaces the element (the
// broadcast update carries fresh elapsed/remaining values from the server).
//
// Catch-up poll: Turbo Stream broadcasts can be missed entirely — e.g. a
// fast job finishes before the WebSocket subscription is confirmed, or any
// single broadcast is dropped (Action Cable/Solid Cable delivery is
// best-effort with no replay to a client that wasn't subscribed yet). Rather
// than assume at least one broadcast per status will arrive, poll the show
// URL (Accept: turbo-stream) on a recurring timer whenever not Done. Each
// response is a turbo-stream replace of this element, so once the server
// reports Done, the replacement's own connect() sees status Done and never
// restarts the poll — no explicit stop condition needed here. The 5s
// interval bounds worst-case staleness to one interval even if every
// broadcast for a given import is missed, without polling so tightly that a
// self-triggered replace → connect → poll cycle becomes a tight loop.
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
    this._syncIntervalId = null
    if (this.statusValue !== "Done") {
      this._startTimer()
      this._startSyncPolling()
    }
  }

  disconnect() {
    this._stopTimer()
    this._stopSyncPolling()
  }

  statusValueChanged(value) {
    if (value === "Done") this._stopTimer()
  }

  _startSyncPolling() {
    if (!this.hasStatusUrlValue) return
    this._syncIntervalId = setInterval(() => this._syncCurrentState(), 5000)
  }

  _stopSyncPolling() {
    if (this._syncIntervalId !== null) {
      clearInterval(this._syncIntervalId)
      this._syncIntervalId = null
    }
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
