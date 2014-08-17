function image_vote(id, value) {
  jQuery.ajax("/ajax/vote/image/" + id, {
    data: { value: value, authenticity_token: CSRF_TOKEN },
    dataType: 'text',
    async: true,
    error: function (response) {
      alert(response.responseText);
    },
    success: function(text) {
      var div = jQuery("#image_votes_" + id);
      div.html(text);
    }
  });
}
