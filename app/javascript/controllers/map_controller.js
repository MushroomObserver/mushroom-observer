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
    this.editable = (this.element.dataset.editable === "true")
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
          this.buildMarkers()
        }
      })
      .catch((e) => {
        console.log("error loading gmaps")
      })
  }

  // In a collection, each set represents a Marker (is_point or is_box).
  // set.center is an array [lat, lng]
  // the `key` of each set is an array [x,y,w,h]
  buildMarkers() {
    for (const [_xywh, set] of Object.entries(this.collection.sets)) {
      this.drawMarker(set)
      // if (set.is_point) {
      // this.drawMarker(set.center)
      // } else
      if (set.is_box) {
        // this.drawMarker(set.center)
        this.drawRectangle(set)
      }
    }
  }

  drawMarker(set) { // , type = 'ct'
    const markerOptions = {
      position: { lat: set.lat, lng: set.long },
      map: this.map,
      draggable: this.editable
    }

    // debugger
    // Only put a title on a center marker, in the case of boxes
    if (!this.editable) { //  && type == 'ct'
      markerOptions.title = set.title
    }
    const marker = new google.maps.Marker(markerOptions)

    if (!this.editable && set != null) {
      //   this.makeMarkerDraggable(marker, type)
      // } else {
      this.drawAndBindInfoWindow(set, marker)
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

    new google.maps.Rectangle(rectangleOptions)

    // if (this.editable) {
    //   this.makeCornersDraggable(set)
    // } else {
    // this.drawAndBindInfoWindow(set)
    // }
  }

  // makeMarkerDraggable(marker, type) {
  //   google.maps.event.addListener(marker, "dragend", (e) => {
  //     dragEndLatLng(e.latLng, type)
  //   })
  // }

  // makeCornersDraggable(set) {
  //   const corners = this.cornersOf(set)
  //   for (const [type, coords] of Object.entries(corners)) {
  //     drawMarker(coords, type)
  //   }
  // }

  drawAndBindInfoWindow(set, marker) {
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
}
