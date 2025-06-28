import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    this.element.dataset.imageLoader = "connected"
    this.dots = ""
    this.isPolling = false
    this.originalText = null
    this.loadingText = this.element.dataset.loadingText
    this.maxedOutText = this.element.dataset.maxedOutText
    this.errorText = this.element.dataset.errorText
  }

  async load(event) {
    event.preventDefault()

    if (this.isPolling) return
    this.isPolling = true

    const url = this.linkTarget.href
    this.originalText ||= this.linkTarget.textContent

    this.startLoadingAnimation()
    this.pollForImage(url)
  }

  async pollForImage(url) {
    try {
      const response = await fetch(`${url}.json`)
      const data = await response.json()

      if (data.status === "ready") {
        window.open(data.url, "_blank")
        this.linkTarget.textContent = this.originalText
        this.disconnect()
      } else if (data.status === "maxed_out") {
        alert(this.maxedOutText)
        this.linkTarget.textContent = this.originalText
        this.disconnect()
      } else {
        setTimeout(() => this.pollForImage(url), 1000)
      }
    } catch (error) {
      console.error("Error polling for image:", error)
      this.linkTarget.textContent = this.errorText
      this.disconnect()
    }
  }

  startLoadingAnimation() {
    this.linkTarget.style.minWidth = `${this.loadingText.length + 3}ch`
    this.linkTarget.style.display = 'inline-block'
    this.linkTarget.style.textAlign = 'left'
    this.animationInterval = setInterval(() => {
      this.dots = this.dots.length >= 3 ? "" : this.dots + "."
      this.linkTarget.textContent = `${this.loadingText}${this.dots}`
    }, 500)
  }

  disconnect() {
    if (this.animationInterval) clearInterval(this.animationInterval)
    this.isPolling = false
  }
}
