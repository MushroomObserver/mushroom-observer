// This module provides a few useful extensions to the Element class:
//   [w,h] = Element.windowSize;        # Get size of visible window.
//   Element.ensureVisible(elem);       # Make sure DOM element is visible.
//------------------------------------------------------------------------------

// Get inner size of browser window.  This is a bit tricky.
// Apparently it can fail on Safari: if the document height
// is between the window height and window height plus scroll
// bar width, if will incorrectly choose the document height.
Element.windowSize = function() {
  var sw, sh;
  var dw = document.width;
  var dh = document.height;
  var sw1 = document.body.clientWidth;
  var sw2 = document.documentElement.clientWidth;
  var sh1 = document.body.clientHeight;
  var sh2 = document.documentElement.clientHeight;
  var sh3 = window.innerHeight;
  sw = sw1 != 0 && sw1 != dw ? sw1 : sw2 != 0 ? sw2 : dw;
  sh = sh1 != 0 && sh1 != dh ? sh1 : sh2 != 0 ? sh2 : dh;
  if (sh3 != 0 && sh3 < sh) sh = sh3;
  return [sw, sh];
};

// Try to make sure an object is completely visible.
Element.ensureVisible = function(e) {
  var pos = Element.cumulativeOffset(e);
  var win = Element.windowSize();
  var ex  = pos[0];
  var ey  = pos[1];
  var ew  = e.offsetWidth;
  var eh  = e.offsetHeight;
  var sx  = document.documentElement.scrollLeft || document.body.scrollLeft;
  var sy  = document.documentElement.scrollTop  || document.body.scrollTop;
  var sw  = win[0];
  var sh  = win[1];

  // Add 5 pixel padding.
  ex = ex < 5 ? 0 : ex - 5;
  ey = ey < 5 ? 0 : ey - 5;
  ew += 10;
  eh += 10;

  // Scroll left/right to make entire object visible.  If impossible, scroll
  // as little as possible.
  var dx = 0;
  if (ex < sx) {
    dx = ex-sx;
    if (ex+ew > sx+sw+dx) dx = ex+ew-sx-sw;
    if (dx > 0) dx = 0;
  } else if (ex+ew > sx+sw) {
    dx = ex+ew-sx-sw;
    if (ex < sx+dx) dx = ex-sx;
    if (dx < 0) dx = 0;
  }

  // Scroll up/down to make entire object visible.  Same deal.
  var dy = 0;
  if (ey < sy) {
    dy = ey-sy;
    if (ey+eh > sy+sh+dy) dy = ey+eh-sy-sh;
    if (dy > 0) dy = 0;
  } else if (ey+eh > sy+sh) {
    dy = ey+eh-sy-sh;
    if (ey < sy+dy) dy = ey-sy;
    if (dy < 0) dy = 0;
  }

  if (dx != 0 || dy != 0)
    window.scrollTo(sx+dx, sy+dy);
};

