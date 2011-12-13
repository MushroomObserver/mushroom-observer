function image_export(id, value) {
  new Ajax.Request("/ajax/export/image/" + id + "?value=" + value, {
    asynchronous: true,
    onComplete: function(request) {
      var div = $("image_export_" + id);
      div.innerHTML = request.responseText;
    }
  })
}
