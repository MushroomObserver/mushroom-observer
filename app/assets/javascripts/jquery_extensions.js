var EVENT_KEY_TAB       = 9;
var EVENT_KEY_RETURN    = 13;
var EVENT_KEY_ESC       = 27;
var EVENT_KEY_BACKSPACE = 8;
var EVENT_KEY_DELETE    = 46;
var EVENT_KEY_UP        = 38;
var EVENT_KEY_DOWN      = 40;
var EVENT_KEY_LEFT      = 37;
var EVENT_KEY_RIGHT     = 39;
var EVENT_KEY_PAGEUP    = 33;
var EVENT_KEY_PAGEDOWN  = 34;
var EVENT_KEY_HOME      = 36;
var EVENT_KEY_END       = 35;

var HTML_ENTITY_MAP = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': '&quot;',
  "'": '&#39;',
  "/": '&#x2F;'
};

String.prototype.escapeHTML = function() {
  return String(this).replace(/[&<>"'\/]/g, function (s) {
    return HTML_ENTITY_MAP[s];
  });
};

// Center an element within the viewport.
jQuery.fn.center = function() {
  var ww = jQuery(window).width();
  var wh = jQuery(window).height();
  var ow = this.outerWidth();
  var oh = this.outerHeight();
  var sx = jQuery(window).scrollLeft();
  var sy = jQuery(window).scrollTop();
  var x = Math.round(Math.max(0, (ww - ow) / 2 + sx));
  var y = Math.round(Math.max(0, (wh - oh) / 2 + sy));
  this.css({
    position: "absolute",
    left: x + "px",
    top: y + "px"
  });
  return this;
}

// Scroll browser window to make an element visible.
jQuery.fn.ensureVisible = function() {
  var ex = this.position().left;
  var ey = this.position().top;
  var ew = this.width();
  var eh = this.height();
  var sx = jQuery(window).scrollLeft();
  var sy = jQuery(window).scrollTop();
  var sw = window.innerWidth || document.documentElement.clientWidth;
  var sh = window.innerHeight || document.documentElement.clientHeight;

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

  if (nx != sx || ny != sy) {
    jQuery("html,body").animate({
      scrollLeft: nx,
      scrollTop:  ny
    }, 1000);
  }
}

// Sniff out width of scrollbar in browser-independent manner.
// (Taken from: http://www.alexandre-gomes.com/?p=115)
var scroll_bar_width = null;
jQuery.fn.getScrollBarWidth = function() {
  var inner, outer, w1, w2;

  if (scroll_bar_width != null)
    return scroll_bar_width;
  
  var inner = document.createElement('p');
  inner.style.width = "100%";
  inner.style.height = "200px";

  var outer = document.createElement('div');
  outer.style.position = "absolute";
  outer.style.top = "0px";
  outer.style.left = "0px";
  outer.style.visibility = "hidden";
  outer.style.width = "200px";
  outer.style.height = "150px";
  outer.style.overflow = "hidden";
  outer.appendChild(inner);

  document.body.appendChild(outer);
  var w1 = inner.offsetWidth;
  outer.style.overflow = 'scroll';
  var w2 = inner.offsetWidth;
  if (w1 == w2) w2 = outer.clientWidth;
  document.body.removeChild(outer);

  scroll_bar_width = w1 - w2;
  return scroll_bar_width;
}

