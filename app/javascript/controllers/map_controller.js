import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="map"
export default class extends Controller {
  static targets = ["mapDiv"]

  connect() {
    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["maps", "marker", "elevation"]
    })

    const mapOptions = {
      center: { lat: -7, lng: -47 },
      zoom: 1,
    }

    loader
      .load()
      .then((google) => {
        this.map = new google.maps.Map(this.mapDivTarget, mapOptions)
        this.elevation = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()
      })
      .catch((e) => {
        console.log("error loading gmaps")
      })

    this.opened = false
    this.indicatorUrl = this.mapDivTarget.dataset.indicatorUrl
  }
}
