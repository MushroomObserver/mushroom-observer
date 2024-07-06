import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"
import { convert } from "geo-coordinates-parser"
import { get } from '@rails/request.js'

// Connects to data-controller="map"
// The connected element can be a map, or in the case of a form with a map UI,
// the whole section of the form including the inputs that should alter the map.
// Either way, mapDivTarget should have the dataset, not the connected element.
// map_types: info (collection), location (rectangle), observation (marker)
export default class extends Controller {
  // it may or may not be the root element of the controller.
  static targets = ["mapDiv", "southInput", "westInput", "northInput",
    "eastInput", "highInput", "lowInput", "placeInput", "locationId",
    "getElevation", "mapClearBtn", "controlWrap",
    // "showPointBtn", "showBoxBtn",
    "latInput", "lngInput", "altInput"]

  connect() {
    this.element.dataset.stimulus = "connected"
    this.map_type = this.mapDivTarget.dataset.mapType
    this.editable = (this.mapDivTarget.dataset.editable === "true")
    this.opened = this.map_type !== "observation"
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
    this.marker_buffer = 0
    this.ac_buffer = 0
    this.geolocate_buffer = 0

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

  helpDebug() {
    debugger
  }

  // We don't draw the map for the create obs form on load, to save on API
  // If we only have one marker, don't use fitBounds - it's too zoomed in.
  // Call setCenter, setZoom with marker position and desired zoom level.
  drawMap() {
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
      draggable: this.editable,
      background: this.marker_color
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
    this.marker.setVisible(true)
  }

  // Only for single markers: listeners for dragging the marker
  makeMarkerEditable(marker) {
    ["position_changed", "dragend"].forEach((eventName) => {
      marker.addListener(eventName, () => {
        const newPosition = marker.getPosition()?.toJSON() // latlng object
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
  //             For observation mapType, the rectangle is display-only.
  //
  drawRectangle(set) {
    const bounds = this.boundsOf(set),
      editable = this.editable && this.map_type !== "observation",
      rectangleOptions = {
        strokeColor: this.marker_color,
        strokeOpacity: 1,
        strokeWeight: 3,
        map: this.map,
        bounds: bounds,
        clickable: editable,
        draggable: editable,
        editable: editable
      },
      rectangle = new google.maps.Rectangle(rectangleOptions)

    if (this.map_type === "observation") {
      // that's it. obs rectangles are not clickable
      this.rectangle = rectangle
    } else if (!this.editable) {
      // there could be many, does not set this.rectangle
      this.giveRectangleInfoWindow(set, rectangle)
    } else {
      this.makeRectangleEditable(rectangle)
      // this.map.fitBounds(bounds) // Only fit bounds if it's a location map
      this.rectangle = rectangle
    }
  }

  placeRectangle(extents) {
    // console.log("placeRectangle")
    // console.log({ extents })
    if (!this.rectangle) {
      this.drawRectangle(extents)
    } else {
      this.rectangle.setBounds(extents)
    }
    this.rectangle.setVisible(true)
    this.map.fitBounds(extents) // overwrite viewport (may zoom in a bit?)
  }

  // Add listeners to the rectangle for dragging and resizing
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
  //  FORM INPUTS : Functions for altering the map from form inputs
  //

  // Action called from the location form n_s_e_w_hi_lo inputs onChange
  // and from observation form lat_lng inputs (debounces inputs)
  bufferInputs() {
    if (this.map_type === "location") {
      this.clearMarkerDrawBuffer()
      this.marker_buffer = setTimeout(this.calculateRectangle(), 500)
    }
    else if (this.map_type === "observation") {
      // console.log("pointChanged")
      // If they just cleared the inputs, swap back to a location autocompleter
      const center = this.validateLatLngInputs(false)
      if (!center) return

      this.dispatchPointChanged(center)

      if (this.latInputTarget.value === "" ||
        this.lngInputTarget.value === "") {
        if (this.marker)
          this.marker.setVisible(false)
      } else {
        if (this.opened) {
          this.clearMarkerDrawBuffer()
          this.marker_buffer = setTimeout(this.calculateMarker(), 2000)
        }
      }
    }
  }

  clearAutocompleterSwapBuffer() {
    if (this.ac_buffer) {
      clearTimeout(this.ac_buffer)
      this.ac_buffer = 0
    }
  }

  clearMarkerDrawBuffer() {
    if (this.marker_buffer) {
      clearTimeout(this.marker_buffer)
      this.marker_buffer = 0
    }
  }

  // Action to map an MO location, or geocode a location from a place name.
  // Can be called directly from a button, so check for input values.
  // Now fired from location id, including when it's zero
  showBox() {
    // console.log("showBox")
    if (!this.opened ||
      !this.hasPlaceInputTarget || !this.placeInputTarget.value)
      return false

    // buffer inputs if they're still typing
    clearTimeout(this.marker_buffer)
    this.marker_buffer = setTimeout(this.checkForBox(), 500)
  }

  // Check what kind of input we have and call the appropriate function
  checkForBox() {
    // this.showBoxBtnTarget.disabled = true
    // console.log("checkForBox")
    let id
    if (this.hasLocationIdTarget && (id = this.locationIdTarget.value)) {
      this.mapLocationBounds()
    } else if (this.map_type == "location") {
      // clearTimeout(this.geolocate_buffer)
      // this.geolocate_buffer = setTimeout(this.geolocatePlaceName(), 500)
      this.geolocatePlaceName()
    }
    if (this.rectangle) this.rectangle.setVisible(true)
  }

  // The locationIdTarget should have the bounds in its dataset
  mapLocationBounds() {
    if (!this.hasLocationIdTarget || !this.locationIdTarget.dataset.north)
      return false

    const bounds = {
      north: parseFloat(this.locationIdTarget.dataset.north),
      south: parseFloat(this.locationIdTarget.dataset.south),
      east: parseFloat(this.locationIdTarget.dataset.east),
      west: parseFloat(this.locationIdTarget.dataset.west)
    }

    this.placeClosestRectangle(bounds, null)
  }

  geolocatePlaceName() {
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
        console.log("Geocode was not successful: " + e)
        // alert("Geocode was not successful for the following reason: " + e)
      });
  }

  // Called from the geocoder response, to update the map and inputs
  // This only grabs the first result. NOTE: SETS LAT/LNG INPUTS if observation
  // If we have multiple, a different function should show them: maybe
  // dispatch an event to autocompleter with the results reformatted?
  // https://developers.google.com/maps/documentation/javascript/geocoding#GeocodingResponses
  respondToGeocode(results) {
    if (results.length == 0) return false

    const viewport = results[0].geometry.viewport.toJSON()
    const extents = results[0].geometry.bounds?.toJSON() // may not exist
    const center = results[0].geometry.location.toJSON()

    if (viewport)
      this.map.fitBounds(viewport)
    if (this.map_type === "observation") {
      // this.placeMarker(center)
      this.placeClosestRectangle(viewport, extents)
    } else if (this.map_type === "location") {
      this.placeClosestRectangle(viewport, extents)
      this.updateFields(viewport, extents, center)
    }
    // this.showBoxBtnTarget.disabled = false
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
  getElevations(points) {
    // "Get Elevation" button on a form sends this param
    if (points.hasOwnProperty('params') && points.params?.points === "input")
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
      this.lowInputTarget.value = this.roundOff(parseFloat(hiLo.low))
      this.highInputTarget.value = this.roundOff(parseFloat(hiLo.high))
    } else if (this.hasAltInputTarget) {
      // should just need one result
      this.altInputTarget.value =
        this.roundOff(parseFloat(results[0].elevation))
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
    this.southInputTarget.value = this.roundOff(bounds?.south)
    this.westInputTarget.value = this.roundOff(bounds?.west)
    this.northInputTarget.value = this.roundOff(bounds?.north)
    this.eastInputTarget.value = this.roundOff(bounds?.east)
  }

  //
  //  OBSERVATION FORM
  //

  // Action called after bufferInputs from lat/lng inputs, to update map marker.
  // Also via toggleMap, checks if `Lat` & `Lng` fields already populated on load
  // if so, drops a pin on that location and center. otherwise, checks if place
  // input has been prepopulated and uses that to focus map and drop a marker.
  calculateMarker(event) {
    if (this.map == undefined ||
      this.latInputTarget.value === '' || this.lngInputTarget.value === ''
    ) return false

    let location
    if (event?.detail?.request_params) {
      location = event.detail.request_params
    } else {
      location = this.validateLatLngInputs(true)
    }
    if (location) {
      this.placeMarker(location)
      this.map.setCenter(location)
      this.map.setZoom(8)
    }
  }

  // Convert from human readable and do a rough check if they make sense
  validateLatLngInputs(update = false) {
    const origLat = this.latInputTarget.value,
      origLng = this.lngInputTarget.value
    let lat, lng

    try {
      let coords = convert(origLat + " " + origLng)
      lat = coords.decimalLatitude,
        lng = coords.decimalLongitude
    }
    // Toss any degree-minute-second notation and just take the first number
    catch {
      lat = parseFloat(origLat)
      lng = parseFloat(origLng)
    }

    if (!lat || !lng)
      return false
    if (lat > 90 || lat < -90 || lng > 180 || lng < -180)
      return false
    const location = { lat: lat, lng: lng }

    if (update) this.updateLatLngInputs(location)
    return location
  }

  // For reference:
  // This is the regex used on the Ruby side to convert degree-minute-second
  // geocoordinates to decimal degrees when saving raw values to db:
  // lxxxitudeRegex() {
  //   /^\s*(-?\d+(?:\.\d+)?)\s*(?:°|°|o|d|deg|,\s)?\s*(?:(?<![\d.])(\d+(?:\.\d+)?)\s*(?:'|‘|’|′|′|m|min)?\s*)?(?:(?<![\d.])(\d+(?:\.\d+)?)\s*(?:"|“|”|″|″|s|sec)?\s*)?([NSEW]?)\s*$/i
  // }

  // Update inputs with a point's location from map UI
  updateLatLngInputs(center) {
    // This is like toFixed(5), but faster and returns a number
    this.latInputTarget.value = this.roundOff(center.lat)
    this.lngInputTarget.value = this.roundOff(center.lng)
    // If we're here, we have a lat and a lng.
    this.dispatchPointChanged(center)
  }

  dispatchPointChanged({ lat, lng }) {
    // Call the swap event on the autocompleter and send the type
    // `location_containing`.
    this.clearAutocompleterSwapBuffer()

    if (lat && lng) {
      this.ac_buffer = setTimeout(() => {
        this.dispatch("pointChanged", {
          detail: {
            type: "location_containing",
            request_params: { lat, lng },
          }
        })
      }, 1000)

      // if (this.placeInputTarget.value === '') {
      //   this.geocoder.geocode({ location: center }, (results, status) => {
      //     if (status === "OK") {
      //       if (results[0]) {
      //         this.placeInputTarget.value = results[0].formatted_address
      //       }
      //     }
      //   })
      // }
    } else {
      this.ac_buffer = setTimeout(() => {
        this.dispatch("pointChanged", { detail: { type: "location" } })
      }, 1000)
    }
  }

  // Action called by the "Open Map" button only.
  // open/close handled by BS collapse
  toggleMap() {
    if (this.opened) {
      this.opened = false
      this.controlWrapTarget.classList.remove("map-open")
    } else {
      this.opened = true
      this.controlWrapTarget.classList.add("map-open")
      // this.mapDivTarget.classList.remove("d-none")
      // this.mapDivTarget.style.backgroundImage = "url(" + this.indicatorUrl + ")"
      // this.mapClearBtnTarget.classList.remove("d-none")
      // this.showPointBtnTarget.style.display = "none"
      // this.showPointBtnTarget.setAttribute("data-action", "map#showMarker")

      if (this.map == undefined) {
        this.drawMap()
        this.makeMapClickable()
      } else {
        this.map.fitBounds(this.mapBounds)
      }

      let center
      if (center = this.validateLatLngInputs(false)) {
        this.calculateMarker({ detail: { request_params: center } })
      }
      // console.log("toggleMap")
      this.checkForBox() // regardless if point
    }
  }

  showMarker() {
    this.calculateMarker()
    if (this.marker) this.marker.setVisible(true)
  }

  makeMapClickable() {
    google.maps.event.addListener(this.map, 'click', (e) => {
      // this.map.addListener('click', (e) => {
      const location = e.latLng.toJSON()
      this.placeMarker(location)
      this.marker.setVisible(true)
      this.map.setCenter(location)
      let zoom = this.map.getZoom()
      if (zoom < 15) {
        // console.log(zoom)
        this.map.setZoom(zoom + 2)
      }
      this.updateFields(null, null, location)
    });
  }

  // Action called from the "Clear Map" button
  clearMap() {
    const inputTargets = [
      this.latInputTarget, this.lngInputTarget, this.altInputTarget,
      this.placeInputTarget
    ]
    inputTargets.forEach((element) => { element.value = '' })

    if (this.marker) {
      this.marker.setMap(null)
      this.marker = null
    }
    if (this.rectangle) {
      this.rectangle.setMap(null)
      this.rectangle = null
      // this.showBoxBtnTarget.disabled = false
    }
    this.dispatch("reenableBtns")
    this.dispatchPointChanged({ lat: null, lng: null })
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

  // Round to 4 decimal places
  roundOff(number) {
    const rounded = Math.round(number * 10000) / 10000
    return rounded
  }

  // Fetches a location from the MO API and maps the bounds
  // async fetchMOLocation(id) {
  //   if (!id) return

  //   const url = this.LOCATION_API_URL + id,
  //     response = await get(url, {
  //       query: { detail: "low" },
  //       responseKind: "json"
  //     })

  //   if (response.ok) {
  //     const json = await response.json
  //     if (json) {
  //       // console.log(json)
  //       this.mapLocationBounds(json)
  //     }
  //   } else {
  //     console.log(`got a ${response.status}: ${response.text}`);
  //   }
  // }

  // Attributes are particular to the MO API response,
  // note they are different from the Location db column names.
  // mapLocationBounds(json) {
  //   if (json.results.length == 0 || !json.results[0].latitude_north)
  //     return false

  //   const location = json.results[0],
  //     bounds = {
  //       north: location.latitude_north,
  //       south: location.latitude_south,
  //       east: location.longitude_east,
  //       west: location.longitude_west
  //     }

  //   this.placeClosestRectangle(bounds, null)
  // }
}
