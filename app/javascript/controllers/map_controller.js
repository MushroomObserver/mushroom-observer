import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="map"
// The connected element can be a map, or in the case of a form with a map UI,
// the whole section of the form including the inputs that should alter the map.
// Either way, the mapDivTarget should have the dataset.
export default class extends Controller {
  // it may or may not be the root element of the controller.
  static targets = ["mapDiv", "southInput", "westInput", "northInput",
    "eastInput", "highInput", "lowInput", "locationName", "findOnMap",
    "getElevation"]

  connect() {
    this.element.dataset.stimulus = "connected";

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["maps", "geocoding", "marker", "elevation"]
    })

    this.collection = JSON.parse(this.mapDivTarget.dataset.collection)
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.location_format = this.mapDivTarget.dataset.locationFormat
    this.localized_text = JSON.parse(this.mapDivTarget.dataset.localization)
    this.controls = JSON.parse(this.mapDivTarget.dataset.controls)
    this.marker = null // Only gets set if we're in edit mode
    this.rectangle = null // Only gets set if we're in edit mode

    // These are for keeping track of user inputs to a form
    // that should update the form after a timeout.
    this.old_location = null
    this.keypress_id = 0
    this.timeout_id = 0

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

    loader
      .load()
      .then((google) => {
        this.map = new google.maps.Map(this.mapDivTarget, mapOptions)
        this.map.fitBounds(mapBounds)
        this.elevation = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()

        // NOTE: any bug in the `then` block will throw the generic error
        // use the `helpDebug` method to debug
        if (this.hasLocationNameTarget && this.locationNameTarget.value) {
          this.findOnMap()
          // this.helpDebug()
        } else if (Object.keys(this.collection.sets).length) {
          this.buildOverlays()
        }
      })
      .catch((e) => {
        console.log("error loading gmaps")
      })
  }

  helpDebug() {
    debugger
  }
  // In a collection, each set represents an overlay (is_point or is_box).
  // set.center is an array [lat, lng]
  // the `key` of each set is an array [x,y,w,h]
  buildOverlays() {
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      // console.log({ set })
      // NOTE: according to the MapSet class, location sets are always is_box!!!
      if (this.isPoint(set)) {
        this.drawMarker(set)
      } else {
        this.drawRectangle(set)
      }
    }
  }

  isPoint(set) {
    return (set.north === set.south) && (set.east === set.west)
  }

  drawMarker(set) {
    const markerOptions = {
      position: { lat: set.lat, lng: set.lng },
      map: this.map,
      draggable: this.editable
    }

    if (!this.editable) {
      markerOptions.title = set.title
    }
    const marker = new google.maps.Marker(markerOptions)

    if (!this.editable && set != null) {
      this.giveMarkerInfoWindow(set, marker)
    } else {
      this.makeMarkerEditable(marker)
    }
  }

  makeMarkerEditable(marker) {
    ["position_changed", "dragend"].forEach((eventName) => {
      marker.addListener(eventName, () => {
        const newPosition = marker.getPosition()?.toJSON() // latlng object
        const bounds = this.boundsOfPoint(newPosition)
        this.updateBoundsInputs(bounds)
        this.updateElevationInputs(this.sampleElevationCenterOf(newPosition))
      })
    })
    this.marker = marker
  }

  // For point markers: make a clickable
  giveMarkerInfoWindow(set, marker) {
    const info_window = new google.maps.InfoWindow({
      content: set.caption
    })

    google.maps.event.addListener(marker, "click", () => {
      info_window.open(this.map, marker)
    })
  }

  drawOrMoveMarker(center) {
    if (!this.marker) {
      this.drawMarker(center)
    } else {
      this.marker.setPosition(center)
    }
    this.map.setCenter(center)
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

    if (this.editable) {
      this.makeRectangleEditable(rectangle)
    } else {
      this.giveRectangleInfoWindow(set, rectangle)
    }
  }

  // "dragstart", "drag",
  makeRectangleEditable(rectangle) {
    ["bounds_changed", "dragend"].forEach((eventName) => {
      rectangle.addListener(eventName, () => {
        const newBounds = rectangle.getBounds()?.toJSON() // nsew object
        // console.log({ newBounds })
        this.updateBoundsInputs(newBounds)
        this.updateElevationInputs(this.sampleElevationPointsOf(newBounds))
      })
    })
    this.rectangle = rectangle
  }

  // For rectangles: make a clickable info window
  // https://stackoverflow.com/questions/26171285/googlemaps-api-rectangle-and-infowindow-coupling-issue
  giveRectangleInfoWindow(set, rectangle) {
    const center = rectangle.getBounds().getCenter()
    const info_window = new google.maps.InfoWindow({
      content: set.caption,
      position: center
    })

    google.maps.event.addListener(rectangle, "click", () => {
      info_window.open(this.map, rectangle)
    })
  }

  drawOrMoveRectangle(extents) {
    if (!this.rectangle) {
      this.drawRectangle(extents)
    } else {
      this.rectangle.setBounds(extents)
    }
    this.map.fitBounds(extents) // overwrite viewport (may zoom in a bit?)
  }

  //
  // COORDINATES
  //

  // Every MapSet should have properties north, south, east, west (plus corners)
  // Alternatively, just send a simple object (e.g. `extents`) with `nsew` props
  boundsOf(set) {
    const bounds = {
      north: set.north,
      south: set.south,
      east: set.east,
      west: set.west
    }
    return bounds
  }

  // findOnMap may fill the extents of a rectangle or a point in the inputs.
  extentsForInput(extents, center) {
    let bounds

    if (extents) {
      bounds = this.boundsOf(extents)
    } else if (center) {
      bounds = this.boundsOfPoint(center)
    }
    return bounds
  }

  // When you need to turn a point into some "bounds", e.g. to fill inputs
  boundsOfPoint(center) {
    const bounds = {
      north: center.lat,
      south: center.lat,
      east: center.lng,
      west: center.lng
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

  sampleElevationPoints() {
    let points
    if (this.marker) {
      const position = this.marker.getPosition().toJSON()
      points = this.sampleElevationCenterOf(position)
    } else if (this.rectangle) {
      const bounds = this.rectangle.getBounds().toJSON()
      points = this.sampleElevationPointsOf(bounds)
    }
    debugger
    return points
  }

  // Computes an array of arrays of [lat, lng] from a set of bounds on the fly
  // Returns array of Google Map points {lat:, lng:} LatLngLiteral objects
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
    return [{ lat: position.lat, lng: position.lng }]
  }

  // Sorts the LocationElevationResponse.results.elevation values and
  // computes the high and low of these results using bounds and center
  highAndLowOf(results) {
    let altitudesArray = results.map((result) => {
      return result.elevation
    }).sort((a, b) => { return a - b })

    const last = altitudesArray.length - 1

    return { high: altitudesArray[last], low: altitudesArray[0] }
  }

  //
  // FORM INPUTS : Functions for altering the map from form inputs
  //

  startKeyPressTimer() {
    this.keypress_id = setTimeout(this.textToMap(), 500)
  }

  textToMap() {
    const north = parseFloat(this.northInputTarget.value)
    const south = parseFloat(this.southInputTarget.value)
    const east = parseFloat(this.eastInputTarget.value)
    const west = parseFloat(this.westInputTarget.value)

    if (!(isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west))) {
      const set = { north: north, south: south, east: east, west: west }
      if (this.rectangle) {
        this.rectangle.setBounds(this.boundsOf(set))
      }
      this.map.fitBounds(this.boundsOf(set))
    }
  }

  findOnMap() {
    this.findOnMapTarget.disabled = true
    let address = this.locationNameTarget.value
    const geocoder = new google.maps.Geocoder()

    if (this.location_format == "scientific") {
      address = address.split(/, */).reverse().join(", ")
    }
    geocoder
      .geocode({ address: address })
      .then((result) => {
        const { results } = result // destructure, results is part of the result
        const viewport = results[0].geometry.viewport.toJSON()
        const extents = results[0].geometry.bounds?.toJSON() // may not exist
        const center = results[0].geometry.location.toJSON()
        this.positionMapAndFillExtentInputs(viewport, extents, center)
        this.findOnMapTarget.disabled = false
      })
      .catch((e) => {
        alert("Geocode was not successful for the following reason: " + e)
      });
  }

  positionMapAndFillExtentInputs(viewport, extents, center) {
    if (viewport) {
      this.map.fitBounds(viewport)
    }
    if (extents) {
      this.drawOrMoveRectangle(extents)
    } else if (center) {
      this.drawOrMoveMarker(center)
    }
    if (this.hasNorthInputTarget)
      this.updateBoundsInputs(this.extentsForInput(extents, center))
    // else if (this.hasLatInputTarget)
    //   this.updateLatLngInputs(center)

    const points = extents ? this.sampleElevationPointsOf(extents) :
      this.sampleElevationCenterOf(center)

    this.getElevation(points) // updates inputs
  }

  // takes a LatLngBoundsLiteral object {south:, west:, north:, east:}
  updateBoundsInputs(bounds) {
    this.southInputTarget.value = bounds?.south
    this.westInputTarget.value = bounds?.west
    this.northInputTarget.value = bounds?.north
    this.eastInputTarget.value = bounds?.east
  }

  // For possible consolidation with obs-form-map
  // updateLatLngInputs(center) {
  //   this.latInputTarget.value = center.lat
  //   this.lngInputTarget.value = center.lng
  // }

  getElevation(points = null) {
    if (!points) {
      // action for the "Get Elevation" button on a form sends no points
      points = this.sampleElevationPoints()
    }
    const elevationService = new google.maps.ElevationService
    const locationElevationRequest = { 'locations': points }

    elevationService.getElevationForLocations(locationElevationRequest,
      (results, status) => {
        if (status === google.maps.ElevationStatus.OK) {
          if (results[0]) {
            this.updateElevationInputs(results)
          } else {
            console.log({ status })
          }
        }
      })
  }

  // takes an array of points of the form {lat:, lng:}
  updateElevationInputs(results) {
    if (this.hasLowInputTarget) {
      const hiLo = this.highAndLowOf(results)
      // console.log({ hiLo })
      this.lowInputTarget.value = parseFloat(hiLo.low)
      this.highInputTarget.value = parseFloat(hiLo.high)
    } // else if (this.hasAltInputTarget) {
    // }
    if (this.hasGetElevationTarget)
      this.getElevationTarget.disabled = true
  }
}
