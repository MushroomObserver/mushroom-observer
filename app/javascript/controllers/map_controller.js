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

    this.collection = JSON.parse(this.element.dataset.collection)
    this.editable = this.element.dataset.editable
    this.location_format = this.element.dataset.locationFormat
    this.localized_text = JSON.parse(this.element.dataset.localization)

    // use center and zoom here
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

    if (this.editable && this.collection.sets.length) {
      this.buildEditableMarkers()
    } else {
      this.buildMarkers()
    }
  }

  buildEditableMarkers() {

  }

  buildMarkers() {
    // center_zoom_init or center_zoom_on_points_init
  }
}
