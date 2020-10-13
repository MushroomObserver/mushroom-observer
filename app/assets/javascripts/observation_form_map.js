// Observation Form Map - Lat/Long/Alt Helper
/* globals $, google */

var GMAPS_API_SCRIPT = "https://maps.googleapis.com/maps/api/js?key=AIzaSyCV0pi0Kp9SEBThW7W1g1K3_rEIqdQmPys";

// ./observer/create_observation
$(document).ready(function() {
  $('.map-open').click(function() {
    $('#observationFormMap').removeClass("hidden").text("Loading...");
    $('.map-clear').removeClass("hidden");
    $('.map-open').hide();

    $.getScript(GMAPS_API_SCRIPT, function() {
      var searchInput = $('#observation_place_name'),
          latInput    = $('#observation_lat'),
          lngInput    = $('#observation_long'),
          elvInput    = $('#observation_alt'),
          marker;

      // init map
      var map = new google.maps.Map(document.getElementById('observationFormMap'), {
          center: { lat: -7, lng: -47 },
          zoom: 1
      });

      // init elevation service
      var elevation = new google.maps.ElevationService();

      addGmapsListener(map, 'click');

      // adjust marker on field input
      $([latInput, lngInput]).each(function() {
          var location;

          $(this).keyup(function() {
              location = { lat: parseFloat($(latInput).val()), lng: parseFloat($(lngInput).val()) };
              placeMarker(location);
          });
      });

      // check if `Lat` & `Lng` fields are populated on load
      // if so, drop a pin on that location and center
      // otherwise, check if a `Where` field has been prepopulated and use that to focus map
      if ($(latInput) !== '' && $(lngInput).val() !== '') {
          var location = { lat: parseFloat($(latInput).val()), lng: parseFloat($(lngInput).val()) };

          placeMarker(location);
          map.setCenter(location);
          map.setZoom(8);
      } else if ($(searchInput).val() !== '') {
          focusMap();
      }

      // set bounds on map
      $('.map-locate').click(function() {
          focusMap();
      });

      // clear map button
      $('.map-clear').click(function(){
          clearMap();
      });

      // use the geocoder to focus on a specific region on the map
      function focusMap() {
          var geocoder = new google.maps.Geocoder();

          // even a single letter will return a result
          if ( $(searchInput).val().length <= 0 ) {
              return false;
          }

          geocoder.geocode({'address': $(searchInput).val() }, function(results, status) {
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

              // when dragged
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

          elevation.getElevationForLocations(requestElevation, function(results, status) {
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
          google.maps.event.addListener(el, eventType, function(e) {
              placeMarker(e.latLng);
              updateFields();
          });
      }
    });
  });
});
