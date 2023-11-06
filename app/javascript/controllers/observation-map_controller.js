import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="observation-map"
export default class extends Controller {
  connect() {
    this.opened = false;
    // this.map_div = null;
    // this.map_open = null;
    // this.map_locate = null;
    // this.map_clear = null;

    this.addMapOpenerBindings();
  }

  addMapOpenerBindings() {
    // console.log("mapbindings bruh")
    this.map_div = document.getElementById('observation_form_map');
    this.map_open = document.querySelector('.map-open');
    this.map_locate = document.querySelector('.map-locate');

    this.map_open.onclick = () => {
      if (!this.opened) this.openMap();
    };

    this.map_locate.onclick = () => {
      if (!this.opened) this.openMap("focus_immediately");
    };
  }

  initializeMap() {
    this.map()
  }

  map() {
    // https://developers.google.com/maps/documentation/javascript/load-maps-js-api#migrate-to-dynamic
    // const { Map } = await google.maps.importLibrary("maps");

    if (this._map == undefined) {
      this._map = new google.maps.Map(this.map_div, {
        center: { lat: -7, lng: -47 },
        zoom: 1,
      });
    }
    return this._map
  }

  geocoder() {
    // const { Geocoder } = await google.maps.importLibrary("geocoding");

    if (this._geocoder == undefined) {
      this._geocoder = new google.maps.Geocoder();
    }
    return this._geocoder
  }

  // marker(location) {
  //   // const { Marker } = await google.maps.importLibrary("marker");
  //   // debugger
  //   if (this._marker == undefined) {
  //     this._marker = new google.maps.Marker({
  //       draggable: true,
  //       map: this.map(),
  //       position: location,
  //       visible: true
  //     });
  //   } else {
  //     this._marker.setPosition(location);
  //     this._marker.setVisible(true);
  //   }
  //   // this.addGmapsListener(this.marker(), 'drag');
  //   return this._marker
  // }

  elevation() {
    // const { ElevationService } = await google.maps.importLibrary("elevation");

    if (this._elevation == undefined) {
      this._elevation = new google.maps.ElevationService();
    }

    return this._elevation
  }

  openMap(focus_immediately) {
    // debugger;

    this.opened = true;
    let indicator_url = this.map_div.dataset.indicatorUrl; //("indicator-url");

    this.map_div.classList.remove("hidden");
    this.map_div.style.backgroundImage = "url(" + indicator_url + ")";

    // const map_open = document.querySelector('.map-open'),
    this.map_clear = document.querySelector('.map-clear');

    this.map_clear.classList.remove("hidden");
    this.map_open.style.display = "none";

    // Functions defined within this block because they depend on map being open
    this.searchInput = document.getElementById('observation_place_name')
    this.latInput = document.getElementById('observation_lat')
    this.lngInput = document.getElementById('observation_long')
    this.elvInput = document.getElementById('observation_alt')

    this.initializeMap();
    this.addGmapsListener(this.map(), 'click');
    this.addLatLngInputBindings();
    this.centerIfLatLngPresent();
    this.addMapButtonBindings();

    if (focus_immediately) {
      this.initializeMap();
      this.focusMap();
    }
  }

  // adjust marker on direct lat/lng field input keyup
  addLatLngInputBindings() {
    [this.latInput, this.lngInput].forEach((element) => {
      let location;
      element.onkeyup = () => {
        location = {
          lat: parseFloat(this.latInput.value),
          lng: parseFloat(this.lngInput.value)
        };
        this.placeMarker(location);
      };
    });
  }

  // check if `Lat` & `Lng` fields already populated on load if so, drop a
  // pin on that location and center. otherwise, check if a `Where` field
  // has been prepopulated and use that to focus map
  centerIfLatLngPresent() {
    if (this.latInput.value !== '' && this.lngInput.value !== '') {
      const location = {
        lat: parseFloat(this.latInput.value),
        lng: parseFloat(this.lngInput.value)
      };
      this.placeMarker(location);
      this.map().setCenter(location);
      this.map().setZoom(8);
    } else if (this.searchInput.value !== '') {
      this.focusMap();
    }
  }

  addMapButtonBindings() {
    // set bounds on map
    this.map_locate.onclick = () => {
      // console.log("locate on map clicked")
      this.focusMap();
    };

    // clear map button
    this.map_clear.onclick = () => {
      this.clearMap();
    };
  }

  focusMap() {
    // even a single letter will return a result
    if (this.searchInput.value.length <= 0) {
      return false;
    }

    this.geocoder().geocode({
      'address': this.searchInput.value
    }, (results, status) => {
      if (status === google.maps.GeocoderStatus.OK && results.length > 0) {
        if (results[0].geometry.viewport) {
          this.map().fitBounds(results[0].geometry.viewport);
        }
      }
    });
  }

  placeMarker(location) {
    if (this.marker != undefined) {
      this.marker.setPosition(location);
      this.marker.setVisible(true);
    } else {
      this.marker = new google.maps.Marker({
        draggable: true,
        map: this.map(),
        position: location,
        visible: true
      });
    }

    this.addGmapsListener(this.marker, 'drag');
  }

  updateFields() {
    const requestElevation = {
      'locations': [this.marker.getPosition()]
    };

    this.latInput.value = this.marker.position.lat();
    this.lngInput.value = this.marker.position.lng();

    this.elevation().getElevationForLocations(requestElevation,
      (results, status) => {
        if (status === google.maps.ElevationStatus.OK) {
          if (results[0]) {
            this.elvInput.value = parseFloat(results[0].elevation);
          } else {
            this.elvInput.value = '';
          }
        }
      });
  }

  clearMap() {
    this.latInput.value = '';
    this.lngInput.value = '';
    this.elvInput.value = '';
    this.marker.setVisible(false);
  }

  addGmapsListener(el, eventType) {
    google.maps.event.addListener(el, eventType, (e) => {
      this.placeMarker(e.latLng);
      this.updateFields();
    });
  }
}
