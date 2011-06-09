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
  sw = sw2 == 0 ? sw1 : sw2;
  sh = sh2 == 0 ? sh1 : sh3 > 0 && sh3 < sh2 ? sh3 : sh2;
  return [sw, sh];
};

// alert("dw "+dw+"\n" + "sw1 "+sw1+"\n" + "sw2 "+sw2+"\n" + "dh "+dh+"\n" + "sh1 "+sh1+"\n" + "sh2 "+sh2+"\n" + "sh3 "+sh3+"\n");
//      X   X   X   X   X   X   X   X   X
//      i55 ie6 ie7 op9 ns8 ff1 ff3 chr saf
// dw   0   0   0   0   Y   Y   Y   x   x
// sw1  Y   x   Y   Y   Y   Y   Y   Y   Y
// sw2  0   Y   Y   Y   Y   Y   Y   Y   Y
// dh   0   0   0   0   x   x   x   x   x
// sh1  Y   x   x   Y   x   x   x   x   x
// sh2  0   Y   Y   x   Y   Y   Y   Y   Y
// sh3  0   0   0   Y   Y   x   x   x   x

// Try to make sure an object is completely visible.
Element.ensureVisible = function(e) {
  var pos = Element.cumulativeOffset(e);
  var siz = Element.getDimensions(e);
  var win = Element.windowSize();
  var ex  = pos[0];
  var ey  = pos[1];
  var ew  = siz.width
  var eh  = siz.height
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
  var nx = sx;
  if (ex < sx && ex+ew < sx+sw) {
    nx = ew<sw ? ex : ex+ew-sw;
  } else if (ex > sx && ex+ew > sx+sw) {
    nx = ew<sw ? ex+ew-sw : ex;
  }

  // Scroll up/down to make entire object visible.  Same deal.
  var ny = sy;
  if (ey < sy && ey+eh < sy+sh) {
    ny = eh<sh ? ey : ey+eh-sh;
  } else if (ey > sy && ey+eh > sy+sh) {
    ny = eh<sh ? ey+eh-sh : ey;
  }

  if (nx != sx || ny != sy)
    window.scrollTo(nx, ny);
};

// Try to center an object in the window.
Element.center = function(e) {
  var win = Element.windowSize();
  var siz = Element.getDimensions(e);
  var ew = siz.width;
  var eh = siz.height;
  var sx = document.documentElement.scrollLeft || document.body.scrollLeft;
  var sy = document.documentElement.scrollTop  || document.body.scrollTop;
  var sw = win[0];
  var sh = win[1];
  var x = Math.round((sw - ew) / 2);
  var y = Math.round((sh - eh) / 2);
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  e.style.left = (x + sx) + "px";
  e.style.top  = (y + sy) + "px";
};

