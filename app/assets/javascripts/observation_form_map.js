// Observation Form Map - Lat/Long/Alt Helper
/* globals $, google */
// TODO: Fix close map toggle, maybe make this a Bootstrap collapse div?

// This key is configured in Google Cloud Platform.
// It is a public key that accepts requests only from mushroomobserver.org/*
var GMAPS_API_SCRIPT = "https://maps.googleapis.com/maps/api/js?key=" +
  "AIzaSyCxT5WScc3b99_2h2Qfy5SX6sTnE1CX3FA";

// ./observations/new
$(document).ready(function () {
  var opened = false;
  // NOTE: for gmap, map_div can't be a jQuery object. only use vanilla JS w/ it
  var map_div = document.getElementById('observation_form_map');

  var open_map = function (focus_immediately) {
    opened = true;
    var indicator_url = map_div.dataset.indicatorUrl //("indicator-url");

    map_div.classList.remove("d-none");
    map_div.style.backgroundImage = "url(" + indicator_url + ")";
    $('.map-clear').removeClass("d-none");
    $('.map-open').hide();

    $.getScript(GMAPS_API_SCRIPT, function () {
      var searchInput = $('#observation_place_name'),
        latInput = $('#observation_lat'),
        lngInput = $('#observation_long'),
        elvInput = $('#observation_alt'),
        marker;

      // init map
      var map = new google.maps.Map(map_div, {
        center: { lat: -7, lng: -47 },
        zoom: 1
      });

      // init elevation service
      var elevation = new google.maps.ElevationService();

      addGmapsListener(map, 'click');

      // adjust marker on field input
      $([latInput, lngInput]).each(function () {
        var location;
        $(this).keyup(function () {
          location = {
            lat: parseFloat($(latInput).val()),
            lng: parseFloat($(lngInput).val())
          };
          placeMarker(location);
        });
      });

      // check if `Lat` & `Lng` fields are populated on load if so, drop a
      // pin on that location and center otherwise, check if a `Where` field
      // has been prepopulated and use that to focus map
      if ($(latInput) !== '' && $(lngInput).val() !== '') {
        var location = {
          lat: parseFloat($(latInput).val()),
          lng: parseFloat($(lngInput).val())
        };
        placeMarker(location);
        map.setCenter(location);
        map.setZoom(8);
      } else if ($(searchInput).val() !== '') {
        focusMap();
      }

      // set bounds on map
      $('.map-locate').on('click', function () {
        focusMap();
      });

      // clear map button
      $('.map-clear').on('click', function () {
        clearMap();
      });

      // use the geocoder to focus on a specific region on the map
      function focusMap() {
        var geocoder = new google.maps.Geocoder();

        // even a single letter will return a result
        if ($(searchInput).val().length <= 0) {
          return false;
        }

        geocoder.geocode({
          'address': $(searchInput).val()
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

        $(latInput).val(marker.position.lat());
        $(lngInput).val(marker.position.lng());

        elevation.getElevationForLocations(requestElevation,
          function (results, status) {
            if (status === google.maps.ElevationStatus.OK) {
              if (results[0]) {
                $(elvInput).val(parseFloat(results[0].elevation));
              } else {
                $(elvInput).val('');
              }
            }
          });
      }

      function clearMap() {
        $(latInput).val('');
        $(lngInput).val('');
        $(elvInput).val('');
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
    });
  };

  $('.map-open').on('click', function () {
    if (!opened) open_map();
  });

  $('.map-locate').on('click', function () {
    if (!opened) open_map("focus_immediately");
  });
});
