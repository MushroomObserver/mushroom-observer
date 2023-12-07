import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="map"
// The connected element can be a map, or in the case of a form with a map UI,
// the whole section of the form including the inputs that should alter the map.
// Either way, mapDivTarget should have the dataset, not the connected element.
export default class extends Controller {
  // it may or may not be the root element of the controller.
  static targets = ["mapDiv", "southInput", "westInput", "northInput",
    "eastInput", "highInput", "lowInput", "placeInput", "findOnMap",
    "getElevation", "mapOpen", "mapClear", "latInput", "lngInput", "altInput"]

  connect() {
    this.element.dataset.stimulus = "connected";
    // map_types: info (collection), location (rectangle), observation (marker)
    this.map_type = this.mapDivTarget.dataset.mapType
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.marker = null // Only gets set if we're in edit mode
    this.rectangle = null // Only gets set if we're in edit mode
    this.location_format = this.mapDivTarget.dataset.locationFormat

    // Optional data that needs parsing
    this.collection = this.mapDivTarget.dataset.collection
    if (this.collection)
      this.collection = JSON.parse(this.collection)
    this.localized_text = this.mapDivTarget.dataset.localization
    if (this.localized_text)
      this.localized_text = JSON.parse(this.localized_text)
    this.controls = this.mapDivTarget.dataset.controls
    if (this.controls)
      this.controls = JSON.parse(this.controls)

    // These private vars are for keeping track of user inputs to a form
    // that should update the form after a timeout.
    this.old_location = null
    this.keypress_id = 0
    this.timeout_id = 0

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["maps", "geocoding", "marker", "elevation"]
    })

    let mapCenter
    if (this.collection) {
      mapCenter = {
        lat: this.collection.extents.lat,
        lng: this.collection.extents.lng
      }
    } else {
      mapCenter = { lat: -7, lng: -47 }
    }

    // use center and zoom here
    const mapOptions = {
      center: mapCenter,
      zoom: 1,
      mapTypeId: 'terrain',
      mapTypeControl: 'true'
    }

    // collection.extents is also a MapSet
    let mapBounds
    if (this.collection) {
      mapBounds = this.boundsOf(this.collection.extents)
    }

    loader
      .load()
      .then((google) => {
        this.map = new google.maps.Map(this.mapDivTarget, mapOptions)
        if (mapBounds)
          this.map.fitBounds(mapBounds)
        this.elevationService = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()

        if (this.map_type === "observation" &&
          this.hasPlaceInputTarget && this.placeInputTarget.value) {
          this.findOnMap()
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

  //
  //  COLLECTIONS: mapType "info" - Map of collapsible collection
  //

  // In a collection, each `set` represents an overlay (is_point or is_box).
  // set.center is an array [lat, lng]
  // the `key` of each set is an array [x,y,w,h]
  buildOverlays() {
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      // console.log({ set })
      // NOTE: according to the MapSet class, location sets are always is_box.
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

  //
  //  MARKERS - used in info mapType (for certain sets)
  //            and in observation mapType (`set` can just be a latLng object)
  //

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

  placeMarker(location) {
    if (!this.marker) {
      this.drawMarker(location)
    } else {
      this.marker.setPosition(location)
      this.map.panTo(location)
    }
  }

  // Only for single markers
  makeMarkerEditable(marker) {
    ["position_changed", "dragend"].forEach((eventName) => {
      marker.addListener(eventName, () => {
        const newPosition = marker.getPosition()?.toJSON() // latlng object
        // if (this.hasNorthInputTarget) {
        //   const bounds = this.boundsOfPoint(newPosition)
        //   this.updateBoundsInputs(bounds)
        // } else
        if (this.hasLatInputTarget) {
          this.updateLatLngInputs(newPosition)
        }
        // this.sampleElevationCenterOf(newPosition)
        this.getElevations([newPosition])
        this.map.panTo(newPosition)
      })
    })
    this.marker = marker
  }

  // For point markers: make a clickable InfoWindow
  giveMarkerInfoWindow(set, marker) {
    const info_window = new google.maps.InfoWindow({
      content: set.caption
    })

    google.maps.event.addListener(marker, "click", () => {
      info_window.open(this.map, marker)
    })
  }

  //
  //  RECTANGLES For info mapType, need to pass the whole set.
  //             For location mapType, the `set` can just be bounds.
  //

  drawRectangle(set) {
    const bounds = this.boundsOf(set)
    const rectangleOptions = {
      strokeColor: "#00ff88",
      strokeOpacity: 1,
      strokeWeight: 3,
      map: this.map,
      bounds: bounds,
      editable: this.editable,
      draggable: this.editable
    }

    const rectangle = new google.maps.Rectangle(rectangleOptions)

    if (!this.editable) {
      this.giveRectangleInfoWindow(set, rectangle)
    } else {
      this.makeRectangleEditable(rectangle)
      // this.map.fitBounds(bounds) // Only fit bounds if it's a location map
    }
  }

  placeRectangle(extents) {
    if (!this.rectangle) {
      this.drawRectangle(extents)
    } else {
      this.rectangle.setBounds(extents)
    }
    this.map.fitBounds(extents) // overwrite viewport (may zoom in a bit?)
  }

  // possibly also listen to "dragstart", "drag" ? not necessary.
  makeRectangleEditable(rectangle) {
    ["bounds_changed", "dragend"].forEach((eventName) => {
      rectangle.addListener(eventName, () => {
        const newBounds = rectangle.getBounds()?.toJSON() // nsew object
        // console.log({ newBounds })
        this.updateBoundsInputs(newBounds)
        this.getElevations(this.sampleElevationPointsOf(newBounds))
        this.map.fitBounds(newBounds)
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

  //
  //  COORDINATES
  //

  // Every MapSet should have properties north, south, east, west (plus corners)
  // Alternatively, just send a simple object (e.g. `extents`) with `nsew` props
  boundsOf(set) {
    let bounds = {}
    if (set?.north) {
      bounds = {
        north: set.north, south: set.south, east: set.east, west: set.west
      }
    }
    return bounds
  }

  // findOnMap may fill the extents of a rectangle or a point in the inputs.
  // extentsForInput(extents, center) {
  //   let bounds
  //   if (extents) {
  //     bounds = this.boundsOf(extents)
  //   } else if (center) {
  //     bounds = this.boundsOfPoint(center)
  //   }
  //   return bounds
  // }

  // When you need to turn a point into some "bounds", e.g. to fill inputs
  // boundsOfPoint(center) {
  //   const bounds = {
  //     north: center.lat,
  //     south: center.lat,
  //     east: center.lng,
  //     west: center.lng
  //   }
  //   return bounds
  // }

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

  //
  //  COORDINATES - ELEVATION
  //

  sampleElevationPoints() {
    let points
    if (this.marker) {
      const position = this.marker.getPosition().toJSON()
      points = [position] // this.sampleElevationCenterOf(position)
    } else if (this.rectangle) {
      const bounds = this.rectangle.getBounds().toJSON()
      points = this.sampleElevationPointsOf(bounds)
    }
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

  // Sorts the LocationElevationResponse.results.elevation objects and
  // computes the high and low of these results using bounds and center
  highAndLowOf(results) {
    let altitudesArray = results.map((result) => {
      return result.elevation
    }).sort((a, b) => { return a - b })
    const last = altitudesArray.length - 1
    return { high: altitudesArray[last], low: altitudesArray[0] }
  }


  //
  //  FORM INPUTS : Functions for altering the map from form inputs
  //

  // Action called from the location form ns_ew_hi_lo inputs onChange
  // and from observation form lat lng inputs (debounces inputs)
  bufferInputs() {
    if (this.map_type === "location") {
      this.keypress_id = setTimeout(this.calculateRectangle(), 500)
    } else if (this.map_type === "observation") {
      this.keypress_id = setTimeout(this.calculateMarker(), 500)
    }
  }

  findOnMap() {
    this.findOnMapTarget.disabled = true
    let address = this.placeInputTarget.value

    if (this.location_format == "scientific") {
      address = address.split(/, */).reverse().join(", ")
    }
    this.geocoder
      .geocode({ address: address })
      .then((result) => {
        const { results } = result // destructure, results is part of the result
        this.respondToGeocode(results)
      })
      .catch((e) => {
        alert("Geocode was not successful for the following reason: " + e)
      });
  }

  respondToGeocode(results) {
    const viewport = results[0].geometry.viewport.toJSON()
    const extents = results[0].geometry.bounds?.toJSON() // may not exist
    const center = results[0].geometry.location.toJSON()

    if (viewport)
      this.map.fitBounds(viewport)
    if (this.map_type === "observation") {
      this.placeMarker(center)
    } else if (this.map_type === "location") {
      this.placeClosestRectangle(viewport, extents)
    }
    this.updateFields(viewport, extents, center)
    this.findOnMapTarget.disabled = false
  }

  // NOTE: Currently we're not going to allow Google API geocoded places that
  // are returned as points to be locations. We're forcing them to be rectangles
  updateFields(viewport, extents, center) {
    let points = [] // for elevation
    if (this.hasNorthInputTarget) {
      // Prefer extents for rectangle, fallback to viewport
      let bounds = extents || viewport
      if (bounds != undefined && bounds?.north) {
        this.updateBoundsInputs(bounds)
        points = this.sampleElevationPointsOf(bounds)
      }
      // else if (center) {
      //   this.updateBoundsInputs(this.boundsOfPoint(center))
      //   points = [center] // this.sampleElevationCenterOf(center)
      // }
    } else if (this.hasLatInputTarget) {
      if (center != undefined && center?.lat) {
        this.updateLatLngInputs(center)
        points = [center] // this.sampleElevationCenterOf(center)
      }
    }
    if (points)
      this.getElevations(points) // updates inputs
  }

  // Action attached to the "Get Elevation" button. (points is then the event)
  getElevations(points = []) {
    // "Get Elevation" button on a form sends this param
    if (points?.params.points === "input")
      points = this.sampleElevationPoints() // from marker or rectangle

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
      })
  }

  // requires an array of results from this.getElevations(points) above
  //   result objects have the form {elevation:, location:, resolution:}
  updateElevationInputs(results) {
    if (this.hasLowInputTarget) {
      const hiLo = this.highAndLowOf(results)
      // console.log({ hiLo })
      this.lowInputTarget.value = parseFloat(hiLo.low)
      this.highInputTarget.value = parseFloat(hiLo.high)
    } else if (this.hasAltInputTarget) {
      // should just need one result
      this.altInputTarget.value = parseFloat(results[0].elevation)
    }
    if (this.hasGetElevationTarget)
      this.getElevationTarget.disabled = true
  }

  //
  //  LOCATION FORM
  //

  // Sends user-entered NSEW to the rectangle. Buffered by the above
  calculateRectangle() {
    const north = parseFloat(this.northInputTarget.value)
    const south = parseFloat(this.southInputTarget.value)
    const east = parseFloat(this.eastInputTarget.value)
    const west = parseFloat(this.westInputTarget.value)

    if (!(isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west))) {
      const bounds = { north: north, south: south, east: east, west: west }
      if (this.rectangle) {
        this.rectangle.setBounds(bounds)
      }
      this.map.fitBounds(bounds)
    }
  }

  // Infers a rectangle from the google place, if found. (could be point/bounds)
  placeClosestRectangle(viewport, extents) {
    // Prefer extents for rectangle, fallback to viewport
    let bounds = extents || viewport
    if (bounds != undefined && bounds?.north) {
      this.placeRectangle(bounds)
    }
    // else if (center) {
    // this.placeMarker(center) // if marker is ok for this map
    // this.placeRectangle(this.boundsOfPoint(center))
    // }
  }

  // takes a LatLngBoundsLiteral object {south:, west:, north:, east:}
  updateBoundsInputs(bounds) {
    this.southInputTarget.value = bounds?.south
    this.westInputTarget.value = bounds?.west
    this.northInputTarget.value = bounds?.north
    this.eastInputTarget.value = bounds?.east
  }

  //
  //  OBSERVATION FORM
  //

  // Action called after bufferInputs from lat/lng inputs, to update map marker.
  // Also via openMap, checks if `Lat` & `Lng` fields already populated on load
  // if so, drops a pin on that location and center. otherwise, checks if place
  // input has been prepopulated and uses that to focus map and drop a marker.
  calculateMarker() {
    let location
    if (location = this.validateLatLngInputs()) {
      this.placeMarker(location)
      this.map.setCenter(location)
      this.map.setZoom(8)
    } else if (this.placeInputTarget.value !== '') {
      this.findOnMap()
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

  // For consolidation with obs-form-map
  updateLatLngInputs(center) {
    this.latInputTarget.value = center.lat
    this.lngInputTarget.value = center.lng
  }

  // Action called by the "Open Map" button only
  openMap() {
    if (this.opened) return false

    this.opened = true

    this.mapDivTarget.classList.remove("hidden")
    this.mapDivTarget.style.backgroundImage = "url(" + this.indicatorUrl + ")"

    this.mapClearTarget.classList.remove("hidden")
    this.mapOpenTarget.style.display = "none"

    this.makeMapClickable()
    this.calculateMarker()
  }

  makeMapClickable() {
    google.maps.event.addListener(this.map, 'click', (e) => {
      const location = e.latLng.toJSON()
      this.placeMarker(location)
      this.updateFields(location)
    });
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
}
