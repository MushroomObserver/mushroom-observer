import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="observation-map"
export default class extends Controller {
  static targets = ["mapDiv", "mapOpen", "mapClear", "findOnMap",
    "placeInput", "latInput", "lngInput", "altInput"]

  connect() {
    this.element.dataset.stimulus = "connected";

    this.map_type = this.mapDivTarget.dataset.mapType
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.location_format = this.mapDivTarget.dataset.locationFormat
    this.opened = false
    this.indicatorUrl = this.mapDivTarget.dataset.indicatorUrl

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["maps", "geocoding", "marker", "elevation"]
    })

    const mapOptions = {
      center: { lat: -7, lng: -47 },
      zoom: 1,
      mapTypeId: 'terrain',
      mapTypeControl: 'true'
    }

    loader
      .load()
      .then((google) => {
        this.map = new google.maps.Map(this.mapDivTarget, mapOptions)
        this.elevationService = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()
      })
      .catch((e) => {
        console.log("error loading gmaps")
      })
  }

  openMap() {
    if (this.opened) return false

    this.opened = true

    this.mapDivTarget.classList.remove("hidden")
    this.mapDivTarget.style.backgroundImage = "url(" + this.indicatorUrl + ")"

    this.mapClearTarget.classList.remove("hidden")
    this.mapOpenTarget.style.display = "none"

    this.placeMarkerListener(this.map, 'click')
    this.mapPointInputs();
  }

  // check if `Lat` & `Lng` fields already populated on load if so, drop a
  // pin on that location and center. otherwise, check if a `Where` field
  // has been prepopulated and use that to focus map and drop a marker.
  mapPointInputs() {
    if (this.latInputTarget.value !== '' && this.lngInputTarget.value !== '') {
      this.calculateMarker()
      this.map.setCenter(location)
      this.map.setZoom(8)
    } else if (this.placeInputTarget.value !== '') {
      this.findOnMap()
    }
  }

  // type in lat/lng, map marker should update
  calculateMarker() {
    let location
    if (location = this.validateLatLngInputs()) {
      this.placeMarker(location)
    }
  }

  validateLatLngInputs() {
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
    if (!this.marker) {
      this.drawMarker(location)
    } else {
      this.marker.setPosition(location)
      this.marker.setVisible(true)
    }
    this.map.panTo(location)

    this.placeMarkerListener(this.marker, 'drag')
  }

  drawMarker(location) {
    this.marker = new google.maps.Marker({
      draggable: true,
      map: this.map,
      position: location,
      visible: true
    })
  }

  // This focuses the map on a place name via "Geocoder"
  findOnMap() {
    // even a single letter will return a result
    if (this.placeInputTarget.value.length <= 0) {
      return false;
    }
    let address = this.placeInputTarget.value
    if (this.location_format == "scientific") {
      address = address.split(/, */).reverse().join(", ")
    }

    this.geocoder
      .geocode({ address: address })
      .then((result) => {
        const { results } = result // destructure, results is part of the result
        const viewport = results[0].geometry.viewport.toJSON()
        // const extents = results[0].geometry.bounds?.toJSON() // may not exist
        const center = results[0].geometry.location.toJSON()
        this.positionMap(viewport)
        this.placeMarker(center)
        this.updateFields(center)
        // this.findOnMapTarget.disabled = false
      })
      .catch((e) => {
        alert("Geocode was not successful for the following reason: " + e)
      });
  }

  positionMap(viewport) {
    if (viewport)
      this.map.fitBounds(viewport)
  }

  updateFields(center) {
    if (this.hasLatInputTarget)
      this.updateLatLngInputs(center)

    this.getElevations([center])  // updates inputs
  }

  updateLatLngInputs(center) {
    this.latInputTarget.value = center.lat
    this.lngInputTarget.value = center.lng
  }

  getElevations(points = null) {
    // action for the "Get Elevation" button on a form sends no points
    if (!points)
      points = [this.marker.getPosition()] // a one point array

    // const elevationService = new google.maps.ElevationService
    const locationElevationRequest = { locations: points }

    this.elevationService.getElevationForLocations(locationElevationRequest,
      (results, status) => {
        if (status === google.maps.ElevationStatus.OK) {
          if (results[0]) {
            this.updateElevationInputs(results)
          } else {
            console.log({ status })
          }
        }
      });
  }

  // requires an array of results from this.getElevations(points) above
  //   result objects have the form {elevation:, location:, resolution:}
  updateElevationInputs(results) {
    if (this.hasAltInputTarget) {
      this.altInputTarget.value = parseFloat(results[0].elevation)
    }
    // if (this.hasGetElevationTarget)
    //   this.getElevationTarget.disabled = true
  }

  clearMap() {
    const inputTargets = [
      this.latInputTarget, this.lngInputTarget, this.altInputTarget
    ]
    inputTargets.forEach((element) => {
      element.value = ''
    })
    this.marker.setVisible(false)
  }

  placeMarkerListener(el, eventType) {
    google.maps.event.addListener(el, eventType, (e) => {
      const location = e.latLng.toJSON()
      this.placeMarker(location)
      this.updateFields(location)
    });
  }
}
