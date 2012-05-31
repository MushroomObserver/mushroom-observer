function image_vote(id, value) {
  new Ajax.Request("/ajax/vote/image/" + id + "?value=" + value, {
    asynchronous: true,
    onFailure: function (response) {
      alert(response.responseText);
    },
    onSuccess: function(response) {
      var div = $("image_votes_" + id);
      div.innerHTML = response.responseText;
    }
  })
}
