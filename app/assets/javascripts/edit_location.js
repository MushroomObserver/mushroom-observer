var old_loc = null;
var timeout_id = 0;
var keypress_id = 0;

function lngAdd(v1, v2) {
  result = v1 + v2;
  if (result > 180) result = result - 360;
  if (result < -180) result = result + 360;
  return result
}

function calcLngMidPnt(west, east) {
  result = (east + west)/2;
  if (west > east) {
    result = result + 180;
  }
  return result;
}

function lngDiff(new_lng, old_lng) {
  diff = Math.abs(new_lng - old_lng)
  if (diff > 180) {
    diff = 360 - diff
  }
  return diff
}

function updateMapOverlay(north, south, east, west) {
  var north_south = (north+south)/2;
  var west_east = calcLngMidPnt(west, east);

  var ct = L(north_south, west_east);
  var nw = L(north,west);
  var nwe = L(north, west_east)
  var ne = L(north,east);
  var sw = L(south,west);
  var swe = L(south, west_east)
  var se = L(south,east);

  mo_marker_ct.setPosition(ct);
  mo_marker_nw.setPosition(nw);
  mo_marker_ne.setPosition(ne);
  mo_marker_sw.setPosition(sw);
  mo_marker_se.setPosition(se);

  mo_box.setPath([nw,nwe,ne,se,swe,sw,nw]);

  if (parseFloat(jQuery("#location_north").val()) != north)
    jQuery("#location_north").val(north);
  if (parseFloat(jQuery("#location_south").val()) != south)
    jQuery("#location_south").val(south);
  if (parseFloat(jQuery("#location_east").val()) != east)
    jQuery("#location_east").val(east);
  if (parseFloat(jQuery("#location_west").val()) != west)
    jQuery("#location_west").val(west);

  clearTimeout(timeout_id);
  old_loc = null;
  reset = false;
}

function resetToLatLng(loc) {
  var north, south, east, west;
  lat = loc.lat();
  lng = loc.lng();
  north = Math.min(90, lat+1);
  south = Math.max(-90, lat-1);
  east  = lngAdd(lng, 1);
  west  = lngAdd(lng, -1);
  updateMapOverlay(north, south, east, west);
  north = Math.min(90, lat+1.5);
  south = Math.max(-90, lat-1.5);
  east  = lngAdd(lng, 1.5);
  west  = lngAdd(lng, -1.5);
  map.fitBounds(new G.LatLngBounds(L(south,west), L(north,east)));
}

function findOnMap() {
  var address = jQuery("#location_display_name").val();
  var geocoder = new google.maps.Geocoder();
  if (LOCATION_FORMAT == "scientific")
    address = address.split(/, */).reverse().join(", ");
  geocoder.geocode(
    { address: address },
    function (results, status) {
      var bounds = results[0].geometry.viewport;
      if (bounds) {
        var ne = bounds.getNorthEast();
        var sw = bounds.getSouthWest();
        var north = ne.lat();
        var south = sw.lat();
        var east  = ne.lng();
        var west  = sw.lng();
        if (!(isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west))) {
          updateMapOverlay(north, south, east, west);
          map_div.fitBounds(bounds);
          return;
        }
      }
      alert("Something went wrong!");
    }
  );
}

function sendOldLoc() {
  if (old_loc != null) {
    north = parseFloat(jQuery("#location_north").val());
    south = parseFloat(jQuery("#location_south").val());
    east = parseFloat(jQuery("#location_east").val());
    west = parseFloat(jQuery("#location_west").val());
    if ((north == -south) && (east == -west)) {
      resetToLatLng(old_loc);
    }
  }
}

function dragEndLatLng(location, which) {
  north = parseFloat(jQuery("#location_north").val());
  south = parseFloat(jQuery("#location_south").val());
  east = parseFloat(jQuery("#location_east").val());
  west = parseFloat(jQuery("#location_west").val());
  if ((north == -south) && (east == -west)) {
    resetToLatLng(location);
  } else {
    lat = location.lat();
    lng = location.lng();
    if (which == 'nw') {north = lat; west = lng;}
    if (which == 'ne') {north = lat; east = lng;}
    if (which == 'sw') {south = lat; west = lng;}
    if (which == 'se') {south = lat; east = lng;}
    if (which == 'ct') {
      lat_diff = Math.min(Math.abs(north - south)/2, Math.min(90 - lat, lat + 90));
      north = lat + lat_diff;
      south = lat - lat_diff;
      lng_diff = lngDiff(west, east)/2;
      east = lngAdd(lng, lng_diff);
      west = lngAdd(lng, -lng_diff);
    }
    updateMapOverlay(north, south, east, west);
  }
}

function clickLatLng(location) {
  if (location != null) {
    if ((old_loc == null) || (location.lat() != old_loc.lat()) || (location.lng() != old_loc.lng())) {
      sendOldLoc();
      old_loc = location;
      timeout_id = setTimeout('sendOldLoc()', 500);
    }
  }
}

function dblClickLatLng(location) {
  old_loc = null;
}

function textToMap() {
  north = parseFloat(jQuery("#location_north").val());
  south = parseFloat(jQuery("#location_south").val());
  east = parseFloat(jQuery("#location_east").val());
  west = parseFloat(jQuery("#location_west").val());
  if (!(isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west))) {
    updateMapOverlay(north, south, east, west);
    // Yuck! 'map_div' is a global variable set to the last map div.
    map_div.fitBounds(new G.LatLngBounds(L(south,west), L(north,east)));
  }
}

function startKeyPressTimer() {
  keypress_id = setTimeout('textToMap()', 500);
}
