// Observation Form Map - Lat/Long/Alt Helper
/* globals: google */
$(document).ready(function () {
  observationFormMapper();
});

// ./observations/new
function observationFormMapper() {
  // This key is configured in Google Cloud Platform.
  // It is a public key that accepts requests only from mushroomobserver.org/*
  const GMAPS_API_SCRIPT = "https://maps.googleapis.com/maps/api/js?key=" +
    "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA";

  let opened = false;
  // NOTE: for gmap, map_div can't be a jQuery object. only use vanilla JS w/ it
  const map_div = document.getElementById('observation_form_map');

  const getScript = url => new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = url;
    script.async = true;

    script.onerror = reject;

    script.onload = script.onreadystatechange = function () {
      const loadState = this.readyState;

      if (loadState && loadState !== 'loaded' && loadState !== 'complete') return;

      script.onload = script.onreadystatechange = null;

      resolve();
    }

    document.head.appendChild(script);
  });

  const open_map = function (focus_immediately) {
    opened = true;
    let indicator_url = map_div.dataset.indicatorUrl //("indicator-url");

    map_div.classList.remove("hidden");
    map_div.style.backgroundImage = "url(" + indicator_url + ")";
    document.querySelector('.map-clear').classList.remove("hidden");
    document.querySelector('.map-open').style.display = "none";

    getScript(GMAPS_API_SCRIPT).then(() => {
      const searchInput = document.getElementById('observation_place_name'),
        latInput = document.getElementById('observation_lat'),
        lngInput = document.getElementById('observation_long'),
        elvInput = document.getElementById('observation_alt');
      let marker;

      // init map
      const map = new google.maps.Map(map_div, {
        center: { lat: -7, lng: -47 },
        zoom: 1
      });

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
      document.querySelector('.map-locate').onclick = () => {
        focusMap();
      };

      // clear map button
      document.querySelector('.map-clear').onclick = () => {
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
        var requestElevation = {
          'locations': [marker.getPosition()]
        };

        latInput.value = marker.position.lat();
        lngInput.value = marker.position.lng();

        elevation.getElevationForLocations(requestElevation,
          function (results, status) {
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
        google.maps.event.addListener(el, eventType, function (e) {
          placeMarker(e.latLng);
          updateFields();
        });
      }

      if (focus_immediately) {
        focusMap();
      }
    }).catch(() => {
      console.error('Could not load script')
    });
  };

  document.querySelector('.map-open').onclick = () => {
    if (!opened) open_map();
  };

  document.querySelector('.map-locate').onclick = () => {
    if (!opened) open_map("focus_immediately");
  };
};
