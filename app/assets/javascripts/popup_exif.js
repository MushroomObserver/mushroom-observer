function popup_exif(image_id) {
  var cover = jQuery("<div class='exif_cover'>")
    .append(jQuery("<table>")
      .append(jQuery("<tr>")
        .append(jQuery("<td>")
          .append(jQuery("<div class='exif_popup'>")
            .text("Loading EXIF header...")
          )
        )
      )
    );
  jQuery('body').append(cover);
  var old_keypress = document.onkeypress;
  document.onkeypress = function (e) {
    if (e.keyCode == 27 || e.keyCode == 13) {
      cover.remove();
      document.onkeypress = old_keypress;
    }
  };
  jQuery.ajax("/ajax/exif/" + image_id, {
    async: true,
    complete: function (request) {
      if (request.status != 200) {
        cover.remove();
        document.onkeypress = old_keypress;
        alert(request.responseText);
      } else {
        var w = Math.round(jQuery(window).width() * 0.90);
        var h = Math.round(jQuery(window).height() * 0.90);
        cover.find(".exif_popup").css({
          "max-width":  w.toString() + "px",
          "max-height": h.toString() + "px",
        }).html(request.responseText);
      }
    }
  });
}
