// Observation Form Map - Lat/Long/Alt Helper
/* globals: google */

// ./observations/new
class MOObservationMapper {

  constructor() {
    // this.GMAPS_API_SCRIPT = "https://maps.googleapis.com/maps/api/js?key=" +
    // "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA";
    this.GMAPS_API_KEY = "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA";
    this.opened = false;
    this.map_div = null;
    this.map_open = null;
    this.map_locate = null;
    this.map_clear = null;

    this.loadGMapsAPI();
    this.addObservationMapBindings();
  }

  // https://developers.google.com/maps/documentation/javascript/load-maps-js-api
  loadGMapsAPI() {
    (g => {
      var h, a, k, p = "The Google Maps JavaScript API",
        c = "google", l = "importLibrary", q = "__ib__", m = document,
        b = window; b = b[c] || (b[c] = {});
      var d = b.maps || (b.maps = {}), r = new Set, e = new URLSearchParams,
        u = () => h || (h = new Promise(async (f, n) => {
          await (a = m.createElement("script"));
          e.set("libraries", [...r] + "");
          for (k in g) e.set(k.replace(/[A-Z]/g, t => "_" + t[0].toLowerCase()), g[k]);
          e.set("callback", c + ".maps." + q);
          a.src = `https://maps.${c}apis.com/maps/api/js?` + e;
          d[q] = f;
          a.onerror = () => h = n(Error(p + " could not load."));
          a.nonce = m.querySelector("script[nonce]")?.nonce || "";
          m.head.append(a)
        }));
      d[l] ? console.warn(p + " only loads once. Ignoring:", g) :
        d[l] = (f, ...n) => r.add(f) && u().then(() => d[l](f, ...n))
    })({
      key: this.GMAPS_API_KEY,
      v: "weekly",
      // Use the 'v' parameter to indicate the version to use (weekly, beta, alpha, etc.).
      // Add other bootstrap parameters as needed, using camel case.
    });
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

  // getScript(url) {
  //   return new Promise((resolve, reject) => {
  //     const script = document.createElement('script');
  //     script.src = url;
  //     script.async = true;

  //     script.onerror = reject;

  //     script.onload = script.onreadystatechange = function () {
  //       const loadState = this.readyState;

  //       if (loadState && loadState !== 'loaded' && loadState !== 'complete') return;

  //       script.onload = script.onreadystatechange = null;
  //       resolve();
  //     }

  //     document.head.appendChild(script);
  //   })
  // }

  openMap(focus_immediately) {
    this.opened = true;
    let indicator_url = this.map_div.dataset.indicatorUrl //("indicator-url");

    this.map_div.classList.remove("hidden");
    this.map_div.style.backgroundImage = "url(" + indicator_url + ")";

    // const map_open = document.querySelector('.map-open'),
    this.map_clear = document.querySelector('.map-clear');

    this.map_clear.classList.remove("hidden");
    this.map_open.style.display = "none";

    // const getScript = (url) => new Promise((resolve, reject) => {
    //   const script = document.createElement('script');
    //   script.src = url;
    //   script.async = true;

    //   script.onerror = reject;

    //   script.onload = script.onreadystatechange = function () {
    //     const loadState = this.readyState;

    //     if (loadState && loadState !== 'loaded' && loadState !== 'complete') return;

    //     script.onload = script.onreadystatechange = null;
    //     resolve();
    //   }

    //   document.head.appendChild(script);
    // });

    // Functions defined within this block because they depend on google.maps
    // getScript(this.GMAPS_API_SCRIPT).then(() => {
    const searchInput = document.getElementById('observation_place_name'),
      latInput = document.getElementById('observation_lat'),
      lngInput = document.getElementById('observation_long'),
      elvInput = document.getElementById('observation_alt');
    let marker;

    // init map
    // const map = new google.maps.Map(this.map_div, {
    //   center: { lat: -7, lng: -47 },
    //   zoom: 1
    // });
    let map;

    // https://developers.google.com/maps/documentation/javascript/load-maps-js-api#migrate-to-dynamic
    async function initMap() {
      const { Map } = await google.maps.importLibrary("maps");

      map = new Map(this.map_div, {
        center: { lat: -7, lng: -47 },
        zoom: 1,
      });
    }

    initMap();

    // init elevation service
    const elevation = new google.maps.ElevationService();

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
      const geocoder = new google.maps.Geocoder();

      // even a single letter will return a result
      if (searchInput.value.length <= 0) {
        return false;
      }

      geocoder.geocode({
        'address': searchInput.value
      }, function (results, status) {
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
        marker = new google.maps.Marker({
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
    // }).catch(() => {
    //   console.error('Could not load script')
    // });
  }
}
