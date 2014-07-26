function image_export(id, value) {
  new Ajax.Request("/ajax/export/image/" + id, {
    parameters: { value: value, authenticity_token: CSRF_TOKEN },
    asynchronous: true,
    onFailure: function (response) {
      alert(response.responseText);
    },
    onSuccess: function(response) {
      var div = $("image_export_" + id);
      div.innerHTML = response.responseText;
    }
  })
}
