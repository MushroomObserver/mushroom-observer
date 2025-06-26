import GeocodeController from "controllers/geocode_controller"
import { Loader } from "@googlemaps/js-api-loader"

// Connects to data-controller="map"
// The connected element can be a map, or in the case of a form with a map UI,
// the whole section of the form including the inputs that should alter the map.
// Either way, mapDivTarget should have the dataset, not the connected element.
// map_types: info (collection), location (rectangle), observation (marker)
export default class extends GeocodeController {
  // it may or may not be the root element of the controller.
  static targets = ["mapDiv", "southInput", "westInput", "northInput",
    "eastInput", "highInput", "lowInput", "placeInput", "locationId",
    "getElevation", "mapClearBtn", "controlWrap", "toggleMapBtn",
    "latInput", "lngInput", "altInput", "showBoxBtn", "lockBoxBtn",
    "editBoxBtn", "autocompleter"]

  connect() {
    this.element.dataset.map = "connected"
    this.map_type = this.mapDivTarget.dataset.mapType
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.opened = this.element.dataset.mapOpen === "true"
    this.marker = null // Only gets set if we're in edit mode
    this.rectangle = null // Only gets set if we're in edit mode
    this.location_format = this.mapDivTarget.dataset.locationFormat
    this.marker_color = "#D95040"
    this.LOCATION_API_URL = "/api2/locations/"

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
    this.marker_draw_buffer = 0
    this.autocomplete_buffer = 0
    this.geolocate_buffer = 0
    this.marker_edit_buffer = 0
    this.rectangle_edit_buffer = 0
    this.ignorePlaceInput = false
    this.lastGeocodedLatLng = { lat: null, lng: null }
    this.lastGeolocatedAddress = ""

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: ["maps", "geocoding", "marker", "elevation"]
    })

    if (this.collection) {
      this.mapCenter = {
        lat: this.collection.extents.lat,
        lng: this.collection.extents.lng
      }
    } else {
      this.mapCenter = { lat: -7, lng: -47 }
    }

    // use center and zoom here
    this.mapOptions = {
      center: this.mapCenter,
      zoom: 1,
      mapTypeId: 'terrain',
      mapTypeControl: 'true'
    }

    // collection.extents is also a MapSet
    this.mapBounds = false
    if (this.collection) {
      this.mapBounds = this.boundsOf(this.collection.extents)
    }

    loader
      .load()
      .then((google) => {
        this.elevationService = new google.maps.ElevationService()
        this.geocoder = new google.maps.Geocoder()
        // Everything except the obs form map: draw the map.
        if (!(this.map_type === "observation" && this.editable)) {
          this.drawMap()
          this.buildOverlays()
        }
      })
      .catch((e) => {
        console.error("error loading gmaps: " + e)
      })
  }

  // Lock rectangle so it's not editable, and show this state in the icon link
  toggleBoxLock(event) {
    if (this.rectangle && this.hasLockBoxBtnTarget &&
      this.hasEditBoxBtnTarget) {
      if (this.rectangle.getEditable() === true) {
        this.rectangle.setEditable(false)
        this.rectangle.setOptions({ clickable: false })
        this.lockBoxBtnTarget.classList.add("d-none")
        this.editBoxBtnTarget.classList.remove("d-none")
      } else {
        this.rectangle.setEditable(true)
        this.rectangle.setOptions({ clickable: true })
        this.lockBoxBtnTarget.classList.remove("d-none")
        this.editBoxBtnTarget.classList.add("d-none")
      }
    }
  }

  // We don't draw the map for the create obs form on load, to save on API
  // If we only have one marker, don't use fitBounds - it's too zoomed in.
  // Call setCenter, setZoom with marker position and desired zoom level.
  drawMap() {
    this.verbose("map:drawMap")
    this.map = new google.maps.Map(this.mapDivTarget, this.mapOptions)
    if (this.mapBounds) {
      if (Object.keys(this.collection.sets).length == 1) {
        const pt = new google.maps.LatLng(
          this.collection.extents.lat,
          this.collection.extents.lng
        )
        this.map.setCenter(pt)
        this.map.setZoom(12)
      } else {
        this.map.fitBounds(this.mapBounds)
      }
    }
  }

  //
  //  COLLECTIONS: mapType "info" - Map of collapsible collection
  //

  // In a collection, each `set` represents an overlay (is_point or is_box).
  // set.center is an array [lat, lng]
  // the `key` of each set is an array [x,y,w,h]
  buildOverlays() {
    if (!this.collection) return

    this.verbose("map:buildOverlays")
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      // this.verbose({ set })
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

  // There may not be a marker yet.
  placeMarker(location) {
    this.verbose("map:placeMarker")
    if (!this.marker) {
      this.drawMarker(location)
    } else {
      this.verbose("map:marker.setPosition")
      this.marker.setPosition(location)
      this.map.panTo(location)
    }
    this.marker.setVisible(true)
  }

  drawMarker(set) {
    this.verbose("map:drawMarker")
    const markerOptions = {
      position: { lat: set.lat, lng: set.lng },
      map: this.map,
      draggable: this.editable,
      background: this.marker_color,
      zoomOnClick: false
    }

    if (!this.editable) {
      markerOptions.title = set.title
    }
    this.marker = new google.maps.Marker(markerOptions)

    if (!this.editable && set != null) {
      this.giveMarkerInfoWindow(set)
    } else {
      this.getElevations([set], "point")
      this.makeMarkerEditable()
    }
  }

  // Only for single markers: listeners for dragging the marker
  makeMarkerEditable() {
    if (!this.marker) return

    this.verbose("map:makeMarkerEditable")
    // clearTimeout(this.marker_edit_buffer)
    // this.marker_edit_buffer = setTimeout(() => {
    const events = ["position_changed", "dragend"]
    events.forEach((eventName) => {
      this.marker.addListener(eventName, () => {
        const newPosition = this.marker.getPosition()?.toJSON() // latlng object
        // if (this.hasNorthInputTarget) {
        //   const bounds = this.boundsOfPoint(newPosition)
        //   this.updateBoundsInputs(bounds)
        // } else
        if (this.hasLatInputTarget) {
          this.updateLatLngInputs(newPosition) // dispatches pointChanged
          // Moving the marker means we're no longer on the image lat/lng
          this.dispatch("reenableBtns")
        }
        // this.sampleElevationCenterOf(newPosition)
        this.getElevations([newPosition], "point")
        this.map.panTo(newPosition)
      })
    })
    // Give the current value to the inputs
    const newPosition = this.marker.getPosition()?.toJSON()
    if (this.hasLatInputTarget && !this.latInputTarget.value) {
      this.updateLatLngInputs(newPosition)
    }

    // this.marker = marker
    // }, 1000)
  }

  // For point markers: make a clickable InfoWindow
  giveMarkerInfoWindow(set) {
    this.verbose("map:giveMarkerInfoWindow")
    const info_window = new google.maps.InfoWindow({
      content: set.caption
    })

    google.maps.event.addListener(this.marker, "click", () => {
      info_window.open(this.map, this.marker)
    })
  }

  //
  //  RECTANGLES For info mapType, need to pass the whole set.
  //             For location mapType, the `set` can just be bounds.
  //             For observation mapType, the rectangle is display-only.
  //

  placeRectangle(extents) {
    this.verbose("map:placeRectangle()")
    this.verbose(extents)
    if (!this.rectangle) {
      this.drawRectangle(extents)
    } else {
      this.rectangle.setBounds(extents)
    }
    const _types = ["location", "hybrid"]
    if (_types.includes(this.map_type)) { this.rectangle.setEditable(true) }
    this.rectangle.setVisible(true)
    this.map.fitBounds(extents) // overwrite viewport (may zoom in a bit?)
  }

  drawRectangle(set) {
    this.verbose("map:drawRectangle()")
    this.verbose(set)
    const bounds = this.boundsOf(set),
      clickable = this.map_type === "info",
      editable = this.editable && this.map_type !== "observation",
      rectangleOptions = {
        strokeColor: this.marker_color,
        strokeOpacity: 1,
        strokeWeight: 3,
        map: this.map,
        bounds: bounds,
        clickable: clickable,
        draggable: false,
        editable: editable
      },
      rectangle = new google.maps.Rectangle(rectangleOptions)

    if (this.map_type === "observation") {
      // that's it. obs rectangles for MO locations are not clickable
      this.rectangle = rectangle
    } else if (!this.editable) {
      // there could be many, does not set this.rectangle
      this.giveRectangleInfoWindow(rectangle, set)
    } else {
      this.rectangle = rectangle
      // this.map.fitBounds(bounds) // Only fit bounds if it's a location map
      this.makeRectangleEditable()
    }
  }

  // Add listeners to the rectangle for dragging and resizing (possibly also
  // listen to "dragstart", "drag" ? not necessary). If we're just switching to
  // location mode, we need a buffer or it's too fast
  makeRectangleEditable() {
    this.verbose("map:makeRectangleEditable")
    // clearTimeout(this.rectangle_buffer)
    // this.rectangle_buffer = setTimeout(() => {
    const events = ["bounds_changed", "dragend"]
    events.forEach((eventName) => {
      this.rectangle.addListener(eventName, () => {
        const newBounds = this.rectangle.getBounds()?.toJSON() // nsew object
        // this.verbose({ newBounds })
        this.updateBoundsInputs(newBounds)
        this.getElevations(this.sampleElevationPointsOf(newBounds), "rectangle")
        this.map.fitBounds(newBounds)
      })
    })
    // }, 1000)
  }

  // For rectangles (there could be many on page): make a clickable info window
  // https://stackoverflow.com/questions/26171285/googlemaps-api-rectangle-and-infowindow-coupling-issue
  giveRectangleInfoWindow(rectangle, set) {
    this.verbose("map:giveRectangleInfoWindow")
    this.verbose(rectangle)

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
  //  FORM INPUTS : Functions for altering the map from form inputs
  //

  // Action called from the location form n_s_e_w_hi_lo inputs onChange
  // and from observation form lat_lng inputs (debounces inputs)
  bufferInputs() {
    if (["location"].includes(this.map_type)) {
      if (this.opened) {
        this.clearMarkerDrawBuffer()
        // this.marker_draw_buffer = setTimeout(this.calculateMarker(), 1000)
        this.marker_draw_buffer = setTimeout(this.calculateRectangle(), 1000)
      }
    }
    if (["observation", "hybrid"].includes(this.map_type)) {
      // this.verbose("map:pointChanged")
      // If they just cleared the inputs, swap back to a location autocompleter
      const center = this.validateLatLngInputs(false)
      if (!center) return

      this.sendPointChanged(center)

      if (this.latInputTarget.value === "" ||
        this.lngInputTarget.value === "" && this.marker) {
        this.marker.setVisible(false) // delete the marker immediately
      } else {
        if (this.opened) {
          this.clearMarkerDrawBuffer()
          this.marker_draw_buffer = setTimeout(this.calculateMarker(), 1000)
        }
      }
    }
  }

  clearMarkerDrawBuffer() {
    if (this.marker_draw_buffer) {
      clearTimeout(this.marker_draw_buffer)
      this.marker_draw_buffer = 0
    }
  }

  // Action to map an MO location, or geocode a location from a place name.
  // Can be called directly from a button, so check for input values.
  // Now fired when locationIdTarget changes, including when it's zero
  showBox() {
    if (!(this.opened && this.hasPlaceInputTarget &&
      this.placeInputTarget.value))
      return false

    // Forms where location is optional: stay mum unless we're in create mode
    if (this.hasAutocompleterTarget &&
      !this.autocompleterTarget.classList.contains("create"))
      return false

    this.verbose("map:showBox")
    // buffer inputs if they're still typing
    clearTimeout(this.marker_draw_buffer)
    this.marker_draw_buffer = setTimeout(this.checkForBox(), 1000)
  }

  // Check what kind of input we have and call the appropriate function
  checkForBox() {
    // this.showBoxBtnTarget.disabled = true
    this.verbose("map:checkForBox")
    let id
    if (this.hasLocationIdTarget && (id = this.locationIdTarget.value)) {
      this.mapLocationIdData()
    } else if (["location", "hybrid"].includes(this.map_type)) {
      // Only geocode lat/lng if we have no location_id and not ignoring place
      // ...and only geolocate placeName if we have no lat/lng
      // Note: is this the right logic ?????????????
      if (this.ignorePlaceInput !== false) {
        this.tryToGeocode() // multiple possible results
      } else {
        this.tryToGeolocate()
      }
    }
    if (this.rectangle) this.rectangle.setVisible(true)
  }

  // The locationIdTarget should have the bounds in its dataset
  mapLocationIdData() {
    if (!this.hasLocationIdTarget || !this.locationIdTarget.dataset.north)
      return false

    this.verbose("map:mapLocationIdData")
    const bounds = {
      north: parseFloat(this.locationIdTarget.dataset.north),
      south: parseFloat(this.locationIdTarget.dataset.south),
      east: parseFloat(this.locationIdTarget.dataset.east),
      west: parseFloat(this.locationIdTarget.dataset.west)
    }

    this.placeClosestRectangle(bounds, null)
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

    if (isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west)) return false

    this.verbose("map:calculateRectangle")
    const bounds = { north: north, south: south, east: east, west: west }
    if (this.rectangle) {
      this.rectangle.setBounds(bounds)
    }
    this.map.fitBounds(bounds)
  }

  // Infers a rectangle from the google place, if found. (could be point/bounds)
  placeClosestRectangle(viewport, extents) {
    this.verbose("map:placeClosestRectangle")
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

  //
  //  OBSERVATION FORM
  //

  // called by toggleMap
  checkForMarker() {
    this.verbose("map:checkForMarker")
    let center
    if (center = this.validateLatLngInputs(false)) {
      this.calculateMarker({ detail: { request_params: center } })
    }
  }

  // Action called via toggleMap, after bufferInputs from lat/lng inputs, to
  // update map marker, and directly by form-exif controller emitting the
  // pointChanged event. Checks if lat & lng fields already populated on load if
  // so, drops a pin on that location and center. Otherwise, checks if place
  // input has been prepopulated and uses that to focus map and drop a marker.
  calculateMarker(event) {
    if (this.map == undefined || !this.hasLatInputTarget ||
      this.latInputTarget.value === '' || this.lngInputTarget.value === '')
      return false

    this.verbose("map:calculateMarker")
    let location
    if (event?.detail?.request_params) {
      location = event.detail.request_params
    } else {
      location = this.validateLatLngInputs(true)
    }
    if (location) {
      this.placeMarker(location)
      this.map.setCenter(location)
      this.map.setZoom(9)
    }
  }

  // Action called by the "Open Map" button only.
  // open/close handled by BS collapse
  toggleMap() {
    this.verbose("map:toggleMap")
    if (this.opened) {
      this.closeMap()
    } else {
      this.openMap()
    }
  }

  closeMap() {
    this.verbose("map:closeMap")
    this.opened = false
    this.controlWrapTarget.classList.remove("map-open")
  }

  openMap() {
    this.verbose("map:openMap")
    this.opened = true
    this.controlWrapTarget.classList.add("map-open")

    if (this.map == undefined) {
      this.drawMap()
      this.makeMapClickable()
    } else if (this.mapBounds) {
      this.map.fitBounds(this.mapBounds)
    }

    setTimeout(() => {
      this.checkForMarker()
      this.checkForBox() // regardless if point
    }, 500) // wait for map to open
  }

  makeMapClickable() {
    this.verbose("map:makeMapClickable")
    google.maps.event.addListener(this.map, 'click', (e) => {
      // this.map.addListener('click', (e) => {
      const location = e.latLng.toJSON()
      this.placeMarker(location)
      this.marker.setVisible(true)
      this.map.panTo(location)
      // if (zoom < 15) { this.map.setZoom(zoom + 2) } // for incremental zoom
      this.updateFields(null, null, location)
    });
  }

  // Action called from the "Clear Map" button
  clearMap() {
    this.verbose("map:clearMap")
    const inputTargets = [
      this.placeInputTarget, this.northInputTarget, this.southInputTarget,
      this.eastInputTarget, this.westInputTarget, this.highInputTarget,
      this.lowInputTarget
    ]
    if (this.hasLatInputTarget) { inputTargets.push(this.latInputTarget) }
    if (this.hasLngInputTarget) { inputTargets.push(this.lngInputTarget) }
    if (this.hasAltInputTarget) { inputTargets.push(this.altInputTarget) }

    inputTargets.forEach((element) => { element.value = '' })
    this.ignorePlaceInput = false // turn string geolocation back on

    this.clearMarker()
    this.clearRectangle()
    this.dispatch("reenableBtns")
    this.sendPointChanged({ lat: null, lng: null })
  }

  clearMarker() {
    if (!this.marker) return false

    this.verbose("map:clearMarker")
    this.marker.setMap(null)
    this.marker = null
  }

  clearRectangle() {
    if (!this.rectangle) return false

    this.verbose("map:clearRectangle")
    this.rectangle.setVisible(false)
    this.rectangle.setMap(null)
    this.rectangle = null
    return true
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

  // mapBounds may fill the extents of a rectangle or a point in the inputs.
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

  // ------------------------------- DEBUGGING ------------------------------

  // helpDebug() {
  //   debugger
  // }

  verbose(str) {
    // console.log(str);
    // document.getElementById("log").
    //   insertAdjacentText("beforeend", str + "<br/>");
  }
}
