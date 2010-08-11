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
  west_east = calcLngMidPnt(west, east);
  center = new GLatLng((north+south)/2, west_east);
  mo_marker_ct.setLatLng(center);
  
  nw = new GLatLng(north,west);
  mo_marker_nw.setLatLng(nw);
  ne = new GLatLng(north,east);
  nwe = new GLatLng(north, west_east)
  
  mo_marker_ne.setLatLng(ne);
  se = new GLatLng(south,east);
  mo_marker_se.setLatLng(se);
  sw = new GLatLng(south,west);
  mo_marker_sw.setLatLng(sw);
  swe = new GLatLng(south, west_east)
  
  map.removeOverlay(mo_box);
  mo_box = new GPolyline([nw,nwe,ne,se,swe,sw,nw],"#00ff88",3,1.0);
  map.addOverlay(mo_box);
  $("location_north").value = north;
  $("location_south").value = south;
  $("location_east").value = east;
  $("location_west").value = west;
  clearTimeout(timeout_id);
  old_loc = null;
  reset = false;
}

function resetToLatLng(loc) {
  lat = loc.lat();
  lng = loc.lng();
  updateMapOverlay(Math.min(90, lat+1), Math.max(-90, lat-1), lngAdd(lng, 1), lngAdd(lng, -1));  
  map.centerAndZoomOnPoints([new GLatLng(Math.min(90, lat+1.5),lngAdd(lng, -1.5)),new GLatLng(Math.max(-90, lat-1.5),lngAdd(lng, 1.5))]);
}

function sendOldLoc() {
  if (old_loc != null) {
    north = parseFloat($("location_north").value);
    south = parseFloat($("location_south").value);
    east = parseFloat($("location_east").value);
    west = parseFloat($("location_west").value);
    if ((north == -south) && (east == -west)) {
      resetToLatLng(old_loc);
    }
  }
}

function dragEndLatLng(location, which) {
  north = parseFloat($("location_north").value);
  south = parseFloat($("location_south").value);
  east = parseFloat($("location_east").value);
  west = parseFloat($("location_west").value);
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
      lng_diff = calcLngMidPnt(west, east);
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
  north = parseFloat($("location_north").value);
  south = parseFloat($("location_south").value);
  east = parseFloat($("location_east").value);
  west = parseFloat($("location_west").value);
  if (!(isNaN(north) || isNaN(south) || isNaN(east) || isNaN(west))) {
    updateMapOverlay(north, south, east, west);
    map.centerAndZoomOnPoints([new GLatLng(north, west),new GLatLng(south, east)]);
  }
}

function startKeyPressTimer() {
  keypress_id = setTimeout('textToMap()', 500);
}