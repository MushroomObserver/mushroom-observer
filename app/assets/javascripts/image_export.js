

function image_export(id, value) {
  jQuery.ajax("/ajax/export/image/" + id, {
    data: { value: value, authenticity_token: CSRF_TOKEN },
    dataType: "text",
    async: true,
    error: function (response) {
      alert(response.responseText);
    },
    success: function(html) {
      jQuery("#image_export_" + id).html(html);
    }
  })
}
