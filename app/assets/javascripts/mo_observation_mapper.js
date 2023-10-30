// Observation Form Map - Lat/Long/Alt Helper
/* globals: google */

// ./observations/new
class MOObservationMapper {

  constructor() {
    // this.GMAPS_API_SCRIPT = "https://maps.googleapis.com/maps/api/js?key=" +
    // "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA";
    // this.GMAPS_API_KEY = "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA";
    this.opened = false;
    this.map_div = null;
    this.map_open = null;
    this.map_locate = null;
    this.map_clear = null;

    // this.loadGMapsAPI();
    this.addObservationMapBindings();
    if (typeof (google) != "undefined") {
      this.initializeMap()
    }
  }

  addObservationMapBindings() {
    document.addEventListener("DOMContentLoaded", () => {
      this.map_div = document.getElementById('observation_form_map'),
        this.map_open = document.querySelector('.map-open'),
        this.map_locate = document.querySelector('.map-locate');

      this.map_open.onclick = () => {
        if (!this.opened) this.openMap();
      };

      this.map_locate.onclick = () => {
        if (!this.opened) this.openMap("focus_immediately");
      };
    });
  }

  async initializeMap() {
    // https://developers.google.com/maps/documentation/javascript/load-maps-js-api#migrate-to-dynamic
    const { Map } = await google.maps.importLibrary("maps");

    if (this.map == undefined) {
      this.map = new Map(this.map_div, {
        center: { lat: -7, lng: -47 },
        zoom: 1,
      });
    }
    return this.map
  }

  async initializeGeocoder() {
    const { Geocoder } = await google.maps.importLibrary("geocoding");

    if (this.geocoder == undefined) {
      this.geocoder = new Geocoder();
    }
    return this.geocoder
  }

  async initializeMarker(map) {
    const { Marker } = await google.maps.importLibrary("marker");

    if (this.marker == undefined) {
      this.marker = new Marker(map);
    }
    return this.marker
  }

  async initializeElevationService() {
    const { ElevationService } = await google.maps.importLibrary("elevation");

    if (this.elevation == undefined) {
      this.elevation = new ElevationService();
    }

    return this.elevation
  }

  openMap(focus_immediately) {
    debugger;

    this.opened = true;
    let indicator_url = this.map_div.dataset.indicatorUrl; //("indicator-url");

    this.map_div.classList.remove("hidden");
    this.map_div.style.backgroundImage = "url(" + indicator_url + ")";

    // const map_open = document.querySelector('.map-open'),
    this.map_clear = document.querySelector('.map-clear');

    this.map_clear.classList.remove("hidden");
    this.map_open.style.display = "none";

    // Functions defined within this block because they depend on google.maps
    // getScript(this.GMAPS_API_SCRIPT).then(() => {
    const searchInput = document.getElementById('observation_place_name'),
      latInput = document.getElementById('observation_lat'),
      lngInput = document.getElementById('observation_long'),
      elvInput = document.getElementById('observation_alt');
    let marker;

    const map = this.initializeMap();

    // init elevation service
    const elevation = this.initializeElevationService();

    addGmapsListener(map, 'click');

    // adjust marker on field input
    [latInput, lngInput].forEach((element) => {
      let location;
      element.onkeyup = () => {
        location = {
          lat: parseFloat(latInput.value),
          lng: parseFloat(lngInput.value)
        };
        placeMarker(location);
      };
    });

    // check if `Lat` & `Lng` fields are populated on load if so, drop a
    // pin on that location and center otherwise, check if a `Where` field
    // has been prepopulated and use that to focus map
    if (latInput.value !== '' && lngInput.value !== '') {
      const location = {
        lat: parseFloat(latInput.value),
        lng: parseFloat(lngInput.value)
      };
      placeMarker(location);
      map.setCenter(location);
      map.setZoom(8);
    } else if (searchInput.value !== '') {
      focusMap();
    }

    // set bounds on map
    this.map_locate.onclick = () => {
      focusMap();
    };

    // clear map button
    this.map_clear.onclick = () => {
      clearMap();
    };

    // use the geocoder to focus on a specific region on the map
    function focusMap() {
      // const geocoder = new google.maps.Geocoder();
      // const { Geocoder } = await google.maps.importLibrary("geocoding");

      // even a single letter will return a result
      if (searchInput.value.length <= 0) {
        return false;
      }

      const geocoder = this.initializeGeocoder();

      geocoder.geocode({
        'address': searchInput.value
      }, (results, status) => {
        if (status === google.maps.GeocoderStatus.OK && results.length > 0) {
          if (results[0].geometry.viewport) {
            map.fitBounds(results[0].geometry.viewport);
          }
        }
      });
    }

    // updates or creates a marker at a specific location
    function placeMarker(location) {
      if (marker) {
        marker.setPosition(location);
        marker.setVisible(true);
      } else {
        marker = this.initializeMarker({
          draggable: true,
          map: map,
          position: location,
          visible: true
        });
        addGmapsListener(marker, 'drag');
      }
    }

    // updates lat & lng + elevaton fields
    function updateFields() {
      const requestElevation = {
        'locations': [marker.getPosition()]
      };

      latInput.value = marker.position.lat();
      lngInput.value = marker.position.lng();

      elevation.getElevationForLocations(requestElevation,
        (results, status) => {
          if (status === google.maps.ElevationStatus.OK) {
            if (results[0]) {
              elvInput.value = parseFloat(results[0].elevation);
            } else {
              elvInput.value = '';
            }
          }
        });
    }

    function clearMap() {
      latInput.value = '';
      lngInput.value = '';
      elvInput.value = '';
      marker.setVisible(false);
    }

    function addGmapsListener(el, eventType) {
      google.maps.event.addListener(el, eventType, (e) => {
        placeMarker(e.latLng);
        updateFields();
      });
    }

    if (focus_immediately) {
      focusMap();
    }
  }
}
