import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="map"
export default class extends Controller {
  static targets = ["mapDiv"]

  connect() {
    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["core", "maps", "marker", "elevation"]
    })

    // https://stackoverflow.com/questions/15719951/auto-center-map-with-multiple-markers-in-google-maps-api-v3
    // bounds = new google.maps.LatLngBounds
    // map.fitBounds(bounds);
    // https://developers.google.com/maps/documentation/javascript/reference/map#Map-Methods
    this.collection = JSON.parse(this.element.dataset.collection)
    this.editable = this.element.dataset.editable
    this.location_format = this.element.dataset.locationFormat
    this.localized_text = JSON.parse(this.element.dataset.localization)

    // use center and zoom here
    const mapOptions = {
      center: {
        lat: this.collection.extents.lat,
        lng: this.collection.extents.long
      },
      zoom: 1,
    }

    // collection.extents is also a MapSet
    const mapBounds = this.boundsOfMapSet(this.collection.extents)
    // const latLngBounds = new google.maps.LatLngBoundsLiteral(mapBounds)

    loader
      .load()
      .then((google) => {
        this.map = new google.maps.Map(this.mapDivTarget, mapOptions)
        this.map.fitBounds(mapBounds)
        this.elevation = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()

        if (this.editable && this.collection.sets.length) {
          this.buildEditableMarkers()
        } else {
          this.buildMarkers()
        }
      })
      .catch((e) => {
        console.log("error loading gmaps")
      })
  }

  // Every MapSet should have these properties
  boundsOfMapSet(set) {
    const bounds = {
      north: set.north,
      south: set.south,
      east: set.east,
      west: set.west
    }
    return bounds
  }

  buildEditableMarkers() {
    // nothing yet
  }

  buildMarkers() {
    // center_zoom_init or center_zoom_on_points_init
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      if (set.is_point) {
        this.drawMarker(set)
      } else if (set.is_box) {
        this.drawRectangle(set)
      }
    }
  }

  drawMarker(set) {
    const marker = new google.maps.Marker({
      position: { lat: set.lat, lng: set.long },
      map: this.map,
      title: set.title,
    })

    const info_window = new google.maps.InfoWindow({
      content: set.caption
    })

    google.maps.event.addListener(marker, "click", () => {
      info_window.open(this.map, marker)
    })
  }

  drawRectangle(set) {
    this.drawMarker(set)
    new google.maps.Rectangle({
      strokeColor: "#00ff88",
      strokeOpacity: 1,
      strokeWeight: 3,
      map: this.map,
      bounds: this.boundsOfMapSet(set)
    })
  }
}
