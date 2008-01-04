var north = 39.7184;
var west = -120.687;
var east = -120.487
var south = 39.5184
var startZoom = 11;
var map;

function addMarker(name, north, west, east, south) {
  var marker = new GMarker(new GLatLng((north+south)/2, (west+east)/2));
  
  GEvent.addListener(marker, 'click',
    function() {
      marker.openInfoWindowHtml(name + '<table><tr><td></td><td>' + north +
       '</td><td></td></tr><tr><td>' + west + '</td><td></td><td>' + east +
       '</td></tr><tr><td></td><td>' + south + '</td><td></td></tr></table>');
    }
  );
  
  map.addOverlay(marker);
}

function init() {
  if (GBrowserIsCompatible()) {
    map = new GMap2(document.getElementById("map"));
    map.addControl(new GLargeMapControl());
    map.addControl(new GScaleControl());
    map.addControl(new GMapTypeControl());

    var center = new GLatLng((north+south)/2, (west+east)/2);
    map.setCenter(center, startZoom);
    
    var request = GXmlHttp.create();
    request.open('GET', 'script_test', true);
    request.onreadystatechange = function() {
      if (request.readyState == 4) {
        var success=false;
        var content = 'Error contacting web service';
        try {
          // result = eval("(" + request.responseText + ")");
          // content = result.content;
          // success = result.success;
          content = request.responseText;
          success = true;
        } catch (e) {
          content = e;
          success = false;
        }
        if (!success) {
          alert(content);
        } else {
          addMarker(content, north, west, west, north);
        }
      }
    }
    request.send(null);
    addMarker('No name', north, west, east, south);
  }
}

window.onload = init;
window.onunload = GUnload;
