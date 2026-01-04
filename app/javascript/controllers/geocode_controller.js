import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"
import { convert } from "geo-coordinates-parser"

// Connects to data-controller="geocode"
// Sort of the "lite" version of the map controller: no map, no markers, but it
// can geocode and get elevations. The connected element should contain a
// location autocompleter and bounding box/elevation inputs.
export default class extends Controller {
  static targets = ["southInput", "westInput", "northInput", "eastInput",
    "highInput", "lowInput", "placeInput", "locationId",
    "latInput", "lngInput", "altInput", "getElevation"]
  static outlets = ["autocompleter--location"]
  static values = { needElevations: Boolean, default: true }

  connect() {
    this.element.dataset.geocode = "connected"

    // These private vars are for keeping track of user inputs to a form
    // that should update the form after a timeout.
    this.map_type = null
    this.map = null // Only gets set in map controller

    this.old_location = null
    this.autocomplete_buffer = 0
    this.geolocate_buffer = 0
    this.ignorePlaceInput = false
    this.lastGeocodedLatLng = { lat: null, lng: null }
    this.lastGeolocatedAddress = ""

    this.libraries = ["maps", "geocoding", "marker"]
    if (this.needElevationsValue == true)
      this.libraries.push("elevation")

    const loader = new Loader({
      apiKey: "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA",
      version: "quarterly",
      libraries: this.libraries
    })

    loader
      .load()
      .then((google) => {
        this.geocoder = new google.maps.Geocoder()
        if (this.needElevationsValue == true)
          this.elevationService = new google.maps.ElevationService()
      })
      .catch((e) => {
        console.error("error loading gmaps: " + e)
      })
  }

  tryToGeocode() {
    this.verbose("geocode:tryToGeocode")
    const location = this.validateLatLngInputs(false)

    if (location &&
      JSON.stringify(location) !== JSON.stringify(this.lastGeocodedLatLng)) {
      this.geocodeLatLng(location)
    }
  }

  // Geocode a lat/lng location. If we have multiple results, we'll dispatch
  // Send the location from validateLatLngInputs(false) to avoid duplicate calls
  geocodeLatLng(location) {
    this.lastGeocodedLatLng = location
    this.verbose("geocode:geocodeLatLng")
    this.verbose(location)
    this.geocoder
      .geocode({ location: location })
      .then((result) => {
        let { results } = result // destructure, results is part of the result
        results = this.siftResults(results)
        this.ignorePlaceInput = true
        this.sendPrimer(results)
        this.respondToGeocode(results)
      })
      .catch((e) => {
        console.log("Geocode was not successful: " + e)
        // alert("Geocode was not successful for the following reason: " + e)
      });
  }

  tryToGeolocate() {
    this.verbose("geocode:tryToGeolocate")
    const address = this.placeInputTarget.value

    if (this.ignorePlaceInput === false &&
      address !== "" && address !== this.lastGeolocatedAddress) {
      this.geolocatePlaceName(address)
    }
  }

  geolocatePlaceName(address) {
    if (address == this.lastGeolocatedAddress) return false

    this.lastGeolocatedAddress = address
    this.verbose("geocode:geolocatePlaceName")
    this.verbose(address)
    if (this.location_format == "scientific") {
      address = address.split(/, */).reverse().join(", ")
    }
    this.geocoder
      .geocode({ address: address })
      .then((result) => {
        const { results } = result // destructure, results is part of the result
        this.sendPrimer(results) // will be ignored by non-autocompleters
        this.respondToGeocode(results)
      })
      .catch((e) => {
        console.log("Geocode was not successful: " + e)
        // alert("Geocode was not successful for the following reason: " + e)
      });
  }

  // Remove certain types of results from the geocoder response:
  // both too precise and too general, before sendPrimer
  siftResults(results) {
    if (results.length == 0) return results

    this.verbose("geocode:siftResults")
    this.verbose(results)
    const _skip_types = ["plus_code", "establishment", "premise",
      "subpremise", "point_of_interest", "street_address", "street_number",
      "route", "postal_code", "country"]
    let sifted = []
    results.forEach((result) => {
      if (!_skip_types.some(t => result.types.includes(t))) {
        sifted.push(result)
      }
    })
    return sifted
  }

  // Build a primer for the autocompleter with bounding box data, but -1 id
  sendPrimer(results) {
    let north, south, east, west, name, id = -1
    // Prefer geometry.bounds, but bounds do not exist for point locations.
    // MO locations must be boxes, so use viewport if bounds null.
    // Viewport should exist on all results. The box is editable, after all.
    const primer = results.map((result) => {
      if (result.geometry?.bounds) {
        ({ north, south, east, west } = result.geometry.bounds.toJSON())
      } else {
        ({ north, south, east, west } = result.geometry.viewport.toJSON())
      }
      name = this.formatMOPlaceName(result)
      return { name, north, south, east, west, id }
    })
    this.verbose("geocode:sendPrimer")
    this.verbose(primer)

    // Call autocompleter#refreshGooglePrimer directly
    if (this.hasAutocompleterLocationOutlet) {
      this.autocompleterLocationOutlet.refreshGooglePrimer({ primer })
    }
  }

  // Format the address components for MO style.
  formatMOPlaceName(result) {
    const ignore_types = ["postal_code", "postal_code_suffix", "street_number"]

    let name_components = [], usa_location = false
    result.address_components.forEach((component) => {
      if (component.types.includes("country") && component.short_name == "US") {
        // MO uses "USA" for US
        usa_location = true
        name_components.push("USA")
      } else if (component.types.includes("administrative_area_level_2") &&
        component.long_name.includes("County")) {
        // MO uses "Co." for County
        name_components.push(component.long_name.replace("County", "Co."))
      } else if (ignore_types.some((type) => component.types.includes(type))) {
        // skip it for all. non-US countries it's an important differentiator?
      } else {
        name_components.push(component.long_name)
      }
    })
    if (this.location_format == "scientific") {
      name_components.reverse()
    }
    return name_components.join(", ")
  }

  // Called from the geocoder response, to update the map and inputs. If
  // geolocating a string, this only grabs the first result. If geocoding a
  // lat/lng, there may be several. NOTE: SETS LAT/LNG INPUTS if observation.
  // https://developers.google.com/maps/documentation/javascript/geocoding#GeocodingResponses
  respondToGeocode(results) {
    if (results.length == 0) return false

    this.verbose("geocode:respondToGeocode, map_type: " + this.map_type)

    const viewport = results[0].geometry.viewport.toJSON()
    const extents = results[0].geometry.bounds?.toJSON() // may not exist
    const center = results[0].geometry.location.toJSON()

    if (this.map) {
      // placeClosestRectangle will handle fitBounds after zoom completes
      this.placeClosestRectangle(viewport, extents)
    }
    this.updateFields(viewport, extents, center)
    // For non-autocompleted place input in the location form
    this.updatePlaceInputTarget(results[0])
    // this.showBoxBtnTarget.disabled = false
  }

  // Update the place input target with an MO-formatted version of the Google
  // result, only if we're on a form with a non-autocompleted place input.
  updatePlaceInputTarget(result) {
    if (!this.hasPlaceInputTarget) return false
    // Skip autocompleted inputs - their controller manages the value
    if (this.placeInputTarget.dataset?.autocompleter) return false

    this.verbose("geocode:updatePlaceInputTarget")
    this.placeInputTarget.value = this.formatMOPlaceName(result)
    this.placeInputTarget.classList.add("geocoded")
  }

  // NOTE: Second branch of conditional is for map controller
  updateFields(viewport, extents, center) {
    this.verbose("geocode:updateFields")
    let points = [], type = "" // for elevation
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
      type = "rectangle"
    } else if (this.hasLatInputTarget) {
      if (center != undefined && center?.lat) {
        this.updateLatLngInputs(center)
        points = [center] // this.sampleElevationCenterOf(center)
      }
      type = "point"
    }
    if (points && type)
      this.getElevations(points, type) // updates inputs
  }

  // Action can be attached to the "Get Elevation" button.
  // `points` is then the event
  getElevations(points, type = "") {
    // Return if controller property needElevations is false
    if (!this.needElevationsValue) return false

    this.verbose("geocode:getElevations")
    // "Get Elevation" button on a form sends this param
    if (this.hasGetElevationTarget &&
      points.hasOwnProperty('params') && points.params?.points === "input") {
      points = this.sampleElevationPoints() // from marker or rectangle
      type = points.params?.type
    }

    const locationElevationRequest = { locations: points }

    this.elevationService.getElevationForLocations(locationElevationRequest,
      (results, status) => {
        if (status === google.maps.ElevationStatus.OK) {
          if (results[0]) {
            this.updateElevationInputs(results, type)
          } else {
            console.log({ status })
          }
        }
      })
  }

  // defined in the map controller
  sampleElevationPoints() {
  }

  // defined in the map controller
  placeClosestRectangle(viewport, extents) {
  }

  // Computes an array of arrays of [lat, lng] from a set of bounds on the fly
  // Returns array of Google Map points {lat:, lng:} LatLngLiteral objects
  // Does not actually get elevations from the API.
  // Only lat/lng points that can be sent for elevations.
  sampleElevationPointsOf(bounds) {
    return [
      { lat: bounds?.south, lng: bounds?.west },
      { lat: bounds?.north, lng: bounds?.west },
      { lat: bounds?.north, lng: bounds?.east },
      { lat: bounds?.south, lng: bounds?.east },
      this.centerFromBounds(bounds)
    ]
  }

  // Computes the center of a Google Maps Rectangle's LatLngBoundsLiteral object
  centerFromBounds(bounds) {
    let lat = (bounds?.north + bounds?.south) / 2.0
    let lng = (bounds?.east + bounds?.west) / 2.0
    if (bounds?.west > bounds?.east) { lng += 180 }
    return { lat: lat, lng: lng }
  }

  // takes a LatLngBoundsLiteral object {south:, west:, north:, east:}
  updateBoundsInputs(bounds) {
    if (!this.hasSouthInputTarget) return false

    this.verbose("geocode:updateBoundsInputs")
    this.southInputTarget.value = this.roundOff(bounds?.south)
    this.westInputTarget.value = this.roundOff(bounds?.west)
    this.northInputTarget.value = this.roundOff(bounds?.north)
    this.eastInputTarget.value = this.roundOff(bounds?.east)
  }

  // requires an array of results from this.getElevations(points, type) above
  //   result objects have the form {elevation:, location:, resolution:}
  updateElevationInputs(results, type) {
    this.verbose("geocode:updateElevationInputs")
    if (this.hasLowInputTarget && type === "rectangle") {
      const hiLo = this.highAndLowOf(results)
      // this.verbose({ hiLo })
      this.lowInputTarget.value = this.roundOff(parseFloat(hiLo.low))
      this.highInputTarget.value = this.roundOff(parseFloat(hiLo.high))
    }
    if (this.hasAltInputTarget && type === "point") {
      // should just need one result
      this.altInputTarget.value =
        this.roundOff(parseFloat(results[0].elevation))
    }
    if (this.hasGetElevationTarget)
      this.getElevationTarget.disabled = true
  }

  // Using a regular expression
  isValidDecimal(str) {
    return /^-?\d*\.?\d+$/.test(str);
  }

  // Convert from human readable and do a rough check if they make sense
  validateLatLngInputs(update = false) {
    this.verbose("geocode:validateLatLngInputs")
    if (!this.hasLatInputTarget || !this.hasLngInputTarget ||
      !this.latInputTarget.value || !this.lngInputTarget.value)
      return false

    const origLat = this.latInputTarget.value,
      origLng = this.lngInputTarget.value
    let lat, lng

    if (this.isValidDecimal(origLat) && this.isValidDecimal(origLng)) {
      lat = parseFloat(origLat)
      lng = parseFloat(origLng)
    } else {
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
    if (this.ignorePlaceInput !== false)
      this.sendPointChanged(center)
  }

  // Call the swap event on the autocompleter and send the type we need
  sendPointChanged({ lat, lng }) {
    this.clearAutocompleterSwapBuffer()

    if (lat && lng) {
      this.autocomplete_buffer = setTimeout(() => {
        if (this.hasAutocompleterLocationOutlet) {
          this.autocompleterLocationOutlet.swap({
            detail:
              { type: "location_containing", request_params: { lat, lng } }
          })
        }
        // this.verbose("geocode:sendPointChanged")
      }, 1000)
    } else {
      this.autocomplete_buffer = setTimeout(() => {
        if (this.hasAutocompleterLocationOutlet) {
          this.autocompleterLocationOutlet.swap({ detail: { type: "location" } })
        }
      }, 1000)
    }
  }

  clearAutocompleterSwapBuffer() {
    if (this.autocomplete_buffer) {
      clearTimeout(this.autocomplete_buffer)
      this.autocomplete_buffer = 0
    }
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
  //       // this.verbose(json)
  //       this.mapLocationBounds(json)
  //     }
  //   } else {
  //     this.verbose(`got a ${response.status}: ${response.text}`);
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
