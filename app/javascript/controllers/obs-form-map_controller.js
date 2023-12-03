import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="observation-map"
export default class extends Controller {
  static targets = ["mapDiv", "mapOpen", "mapClear", "mapLocate",
    "placeInput", "latInput", "lngInput", "altInput"]

  connect() {
    this.element.dataset.stimulus = "connected";

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["maps", "geocoding", "marker", "elevation"]
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

  openMap() {
    // debugger;
    if (this.opened) return false

    this.opened = true

    this.mapDivTarget.classList.remove("hidden")
    this.mapDivTarget.style.backgroundImage = "url(" + this.indicatorUrl + ")"

    this.mapClearTarget.classList.remove("hidden")
    this.mapOpenTarget.style.display = "none"

    this.addGmapsListener(this.map, 'click')
    this.centerIfLatLngPresent();
  }

  // check if `Lat` & `Lng` fields already populated on load if so, drop a
  // pin on that location and center. otherwise, check if a `Where` field
  // has been prepopulated and use that to focus map
  centerIfLatLngPresent() {
    if (this.latInputTarget.value !== '' && this.lngInputTarget.value !== '') {
      this.calculateMarker()
      this.map.setCenter(location)
      this.map.setZoom(8)
    } else if (this.placeInputTarget.value !== '') {
      this.focusMap()
    }
  }

  // This focuses the map on a place name via "Geocoder"
  focusMap() {
    // even a single letter will return a result
    if (this.placeInputTarget.value.length <= 0) {
      return false;
    }

    this.geocoder.geocode({
      'address': this.placeInputTarget.value
    }, (results, status) => {
      if (status === google.maps.GeocoderStatus.OK && results.length > 0) {
        if (results[0].geometry.viewport) {
          this.map.fitBounds(results[0].geometry.viewport)
        }
      }
    });
  }

  // type in lat/lng, map marker should update
  calculateMarker() {
    let location
    if (location = this.validateLocation()) {
      this.placeMarker(location)
    }
  }

  validateLocation() {
    let lat = parseFloat(this.latInputTarget.value),
      lng = parseFloat(this.lngInputTarget.value)

    if (!lat || !lng)
      return false

    if (lat > 90 || lat < -90 || lng > 180 || lng < -180)
      return false

    const location = { lat: lat, lng: lng }

    return location
  }

  placeMarker(location) {
    if (location == undefined) {
      console.log("location undefined")
      return false
    }

    // relocate the one marker if it exists
    if (this.marker != undefined) {
      this.marker.setPosition(location)
      this.marker.setVisible(true)
    } else {
      this.marker = new google.maps.Marker({
        draggable: true,
        map: this.map,
        position: location,
        visible: true
      })
    }

    this.addGmapsListener(this.marker, 'drag')
  }

  updateFields() {
    const requestElevation = {
      'locations': [this.marker.getPosition()]
    };

    this.latInputTarget.value = this.marker.position.lat()
    this.lngInputTarget.value = this.marker.position.lng()

    this.elevation.getElevationForLocations(requestElevation,
      (results, status) => {
        if (status === google.maps.ElevationStatus.OK) {
          if (results[0]) {
            this.altInputTarget.value = parseFloat(results[0].elevation)
          } else {
            this.altInputTarget.value = ''
          }
        }
      });
  }

  clearMap() {
    this.latInputTarget.value = ''
    this.lngInputTarget.value = ''
    this.altInputTarget.value = ''
    this.marker.setVisible(false)
  }

  addGmapsListener(el, eventType) {
    google.maps.event.addListener(el, eventType, (e) => {
      this.placeMarker(e.latLng)
      this.updateFields()
    });
  }
}
