// Observation Form Map - Lat/Long/Alt Helper

// ./observer/create_observation
if ( $('#observationFormMap').length ) {

    (function() {
        var searchInput = $('#observation_place_name'),
            latInput = $('#observation_lat'),
            lngInput = $('#observation_long');

        // init map object
        var map = new google.maps.Map(document.getElementById('observationFormMap'), {
            zoom: 1,
            center: { lat: 8.38321792370903, lng: -66.56186083652352 }
        });

        // init marker
        var marker = new google.maps.Marker({
            title: 'Location',
            map: map,
            draggable: true,
            visible: false
        });

        // disable user from submitting on this element
        $(searchInput).keypress(function(e) {
            if (e.keyCode == 13) { e.preventDefault(); }
        });

        // dragged marker event
        google.maps.event.addListener(marker, 'drag', function(e) {
            latLngInputs.update(e.latLng.lat(), e.latLng.lng());
        });

        // clear the text inputs
        $('.map-clear').click(function(e) {
            e.preventDefault();

            latLngInputs.empty();
        });

        // updates map on text input change
        $([latInput, lngInput]).each(function(index, value) {
            $(this).keyup(function() {
                var latLng = new google.maps.LatLng($(latInput).val(), $(lngInput).val());

                marker.setPosition(latLng);
            });
        });

        // find on map
        $('.map-locate').click(function(e) {
            var address =  $(searchInput).val(),
                geocoder = new google.maps.Geocoder();

            // we need a value, even a single letter will suffice
            if ( $(searchInput).val().length <= 0 )
                return false;

            latLngInputs.empty();

            geocoder.geocode({'address': address }, function(results, status) {
                if (status === google.maps.GeocoderStatus.OK && results.length > 0) {
                    var location = results[0].geometry.location;

                    marker.setPosition(location);
                    marker.setVisible(true);

                    if (results[0].geometry.viewport) {
                        map.fitBounds(results[0].geometry.viewport);
                    } else {
                        map.setZoom(1);
                    }

                    latLngInputs.update(location.lat(), location.lng());
                } else {
                    console.log('Invalid address');
                }
            });
        });

        var latLngInputs = {
            update: function(lat,lng) {
                $(latInput).val(lat);
                $(lngInput).val(lng);
            },
            empty: function() {
                $(latInput).val('');
                $(lngInput).val('');

                // hide the marker
                marker.setVisible(false);
            }
        };
    })();
}
