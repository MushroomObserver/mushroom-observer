import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="map"
export default class extends Controller {
  // need targets and actions for location form inputs
  // reconsider the scope of the controller
  // the mapDiv should be considered the source of the data.
  // it may or may not be the root element of the controller.
  static targets = ["mapDiv", "southInput", "westInput", "northInput",
    "eastInput", "highInput", "lowInput"]

  connect() {
    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "weekly",
      libraries: ["core", "maps", "marker", "elevation"]
    })

    // https://stackoverflow.com/questions/15719951/auto-center-map-with-multiple-markers-in-google-maps-api-v3
    // bounds = new google.maps.LatLngBounds
    // map.fitBounds(bounds);
    // https://developers.google.com/maps/documentation/javascript/reference/map#Map-Methods
    this.collection = JSON.parse(this.mapDivTarget.dataset.collection)
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.location_format = this.mapDivTarget.dataset.locationFormat
    this.localized_text = JSON.parse(this.mapDivTarget.dataset.localization)
    this.controls = JSON.parse(this.mapDivTarget.dataset.controls)

    // use center and zoom here
    const mapOptions = {
      center: {
        lat: this.collection.extents.lat,
        lng: this.collection.extents.long
      },
      zoom: 1,
      mapTypeId: 'terrain',
      mapTypeControl: 'true'
    }

    // collection.extents is also a MapSet
    const mapBounds = this.boundsOf(this.collection.extents)
    // const latLngBounds = new google.maps.LatLngBoundsLiteral(mapBounds)

    loader
      .load()
      .then((google) => {
        this.map = new google.maps.Map(this.mapDivTarget, mapOptions)
        this.map.fitBounds(mapBounds)
        this.elevation = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()

        if (Object.keys(this.collection.sets).length) {
          this.buildOverlays()
        }
      })
      .catch((e) => {
        console.log("error loading gmaps")
      })
  }

  // In a collection, each set represents an overlay (is_point or is_box).
  // set.center is an array [lat, lng]
  // the `key` of each set is an array [x,y,w,h]
  buildOverlays() {
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      if (set.is_point) {
        this.drawMarker(set)
      } else if (set.is_box) {
        this.drawRectangle(set)
      }
    }
  }

  drawMarker(set) {
    const markerOptions = {
      position: { lat: set.lat, lng: set.long },
      map: this.map,
      draggable: this.editable
    }

    if (!this.editable) {
      markerOptions.title = set.title
    }
    const marker = new google.maps.Marker(markerOptions)

    if (!this.editable && set != null) {
      this.drawInfoWindowForMarker(set, marker)
    } else {
      ["position_changed", "dragend"].forEach((eventName) => {
        marker.addListener(eventName, () => {
          const newPosition = marker.getPosition()?.toJSON() // latlng object
          this.updateFormInputs(newPosition)
          this.updateElevationInputs(this.sampleElevationCenterOf(newPosition))
        })
      })
    }
  }

  drawRectangle(set) {
    const rectangleOptions = {
      strokeColor: "#00ff88",
      strokeOpacity: 1,
      strokeWeight: 3,
      map: this.map,
      bounds: this.boundsOf(set),
      editable: this.editable,
      draggable: this.editable
    }

    const rectangle = new google.maps.Rectangle(rectangleOptions)

    if (this.editable) { // "dragstart", "drag",
      ["bounds_changed", "dragend"].forEach((eventName) => {
        rectangle.addListener(eventName, () => {
          const newBounds = rectangle.getBounds()?.toJSON() // nsew object
          this.updateFormInputs(newBounds)
          this.updateElevationInputs(this.sampleElevationPointsOf(newBounds))
        })
      })
    }
  }

  // takes a LatLngBoundsLiteral object {south:, west:, north:, east:}
  updateFormInputs(bounds) {
    if (this.hasNorthInputTarget) {
      this.southInputTarget.value = bounds?.south
      this.westInputTarget.value = bounds?.west
      this.northInputTarget.value = bounds?.north
      this.eastInputTarget.value = bounds?.east
    }
  }

  // takes an array of points of the form {lat:, lng:}
  updateElevationInputs(points) {
    const elevationService = new google.maps.ElevationService
    const locationElevationRequest = { 'locations': points }

    elevationService.getElevationForLocations(locationElevationRequest,
      (results, status) => {
        if (status === google.maps.ElevationStatus.OK) {
          if (results[0]) {
            // compute the high and low of these results using bounds and center
            const hiLo = this.highAndLowOf(results)
            // console.log({ hiLo, status })
            this.lowInputTarget.value = parseFloat(hiLo.low)
            this.highInputTarget.value = parseFloat(hiLo.high)
          } else {
            console.log({ status })
            // this.altInputTarget.value = ''
          }
        }
      })
  }

  // For point markers: make a clickable
  drawInfoWindowForMarker(set, marker) {
    const info_window = new google.maps.InfoWindow({
      content: set.caption
    })

    google.maps.event.addListener(marker, "click", () => {
      info_window.open(this.map, marker)
    })
  }

  // Every MapSet should have properties for bounds and corners
  boundsOf(set) {
    const bounds = {
      north: set.north,
      south: set.south,
      east: set.east,
      west: set.west
    }
    return bounds
  }

  // Each corner (e.g. north_east) is an array [lat, lng]
  cornersOf(set) {
    const corners = {
      ne: set.north_east,
      se: set.south_east,
      sw: set.south_west,
      nw: set.north_west
    }
    return corners
  }

  // Computes the center of a Google Maps Rectangle's LatLngBoundsLiteral object
  centerFromBounds(bounds) {
    let lat = (bounds?.north + bounds?.south) / 2.0
    let lng = (bounds?.east + bounds?.west) / 2.0
    if (bounds?.west > bounds?.east) { lng += 180 }

    return { lat: lat, lng: lng }
  }

  // Computes an array of arrays of [lat, lng] from a set of bounds on the fly
  // Returns array of Google Map points {lat:, lng:}
  sampleElevationPointsOf(bounds) {
    return [
      { lat: bounds?.south, lng: bounds?.west },
      { lat: bounds?.north, lng: bounds?.west },
      { lat: bounds?.north, lng: bounds?.east },
      { lat: bounds?.south, lng: bounds?.east },
      this.centerFromBounds(bounds)
    ]
  }

  // Also returns an array, from a Google Maps Marker's LatLngLiteral object
  sampleElevationCenterOf(position) {
    return [{ lat: position.lat, lng: position.long }]
  }

  // Sorts the LocationElevationResponse.results.elevation values
  highAndLowOf(results) {
    let altitudesArray = results.map((result) => {
      return result.elevation
    }).sort((a, b) => { return a - b })

    const last = altitudesArray.length - 1

    return { high: altitudesArray[last], low: altitudesArray[0] }
  }
}
