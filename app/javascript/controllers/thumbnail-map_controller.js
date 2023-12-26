import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="thumbnail-map"
export default class extends Controller {
  static targets = ["mapContainer", "map", "globe"]

  connect() {
    this.element.dataset.stimulus = "connected";

    this.map_url = this.element.dataset.mapUrl
    this.coords = JSON.parse(this.element.dataset.coordinates)
    this.zoom = 1.0
    this.max_zoom = 50.0
    this.expanded = false
    this.large_url = this.globeTarget.dataset.globeLargeUrl

    window.addEventListener("resize", this.resetMap())

    this.mapContainerTarget.addEventListener("wheel", (event) => {
      if (event.ctrlKey) {
        zoomTo(event.originalEvent.deltaY < 0 ? 1 : -1);
        return cancel(event);
      }
    })

    this.mapContainerTarget.addEventListener("click", () => {
      window.location = this.map_url
    })
  }

  resetMap() {
    this.mapContainerTarget.setAttribute("width", "")
    this.mapContainerTarget.setAttribute("height", "")
    this.mapContainerTarget.setAttribute("overflow", "")
    this.mapTarget.setAttribute("top", "")
    this.mapTarget.setAttribute("left", "")
    this.mapTarget.setAttribute("width", "")
    this.mapTarget.setAttribute("height", "")
    this.zoom = 1.0
  }

  zoomTo({ params: { dir } }) {
    if (dir > 0) this.zoom *= Math.sqrt(2);
    if (dir < 0) this.zoom /= Math.sqrt(2);
    if (this.zoom <= 1.0) {
      this.resetMap();
    } else {
      if (this.zoom > this.max_zoom) this.zoom = this.max_zoom;
      this.doZoom();
      this.loadLargerMap();
    }
  }

  doZoom() {
    var cw = this.mapContainerTarget.outerWidth;
    var ch = this.mapContainerTarget.outerHeight;
    var mw = Math.round(cw * this.zoom);
    var mh = Math.round(ch * this.zoom);
    var f = 1.0 / Math.sqrt(this.zoom);
    var x = Math.round(this.coords.x / 100 * (mw - cw * f) - cw / 2 * (1 - f));
    var y = Math.round(this.coords.y / 100 * (mh - ch * f) - ch / 2 * (1 - f));
    this.mapContainerTarget.setAttribute("width", cw + "px")
    this.mapContainerTarget.setAttribute("height", ch + "px")
    this.mapContainerTarget.setAttribute("overflow", "hidden")
    this.mapTarget.setAttribute("top", -y + "px")
    this.mapTarget.setAttribute("left", -x + "px")
    this.mapTarget.setAttribute("width", mw + "px")
    this.mapTarget.setAttribute("height", mh + "px")
  }

  loadLargerMap() {
    if (this.expanded) return
    const _large = document.createElement('img');

    _large.setAttribute("src", this.large_url)
    _large.addEventListener('load', () => {
      this.map.querySelector("img").setAttribute("src", this.large_url);
    });
    this.expanded = true;
  }

  cancel(event) {
    event.stopPropagation();
    return false;
  }
}
