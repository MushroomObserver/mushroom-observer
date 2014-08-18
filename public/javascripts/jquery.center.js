jQuery.fn.center = function() {
  var ww = jQuery(window).width();
  var wh = jQuery(window).height();
  var ow = jQuery(this).outerWidth();
  var oh = jQuery(this).outerHeight();
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
