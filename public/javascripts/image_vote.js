function image_vote(id, value) {
  new Ajax.Request("/ajax/vote/image/" + id + "?value=" + value, {
    asynchronous: true,
    onComplete: function(request) {
      var div = $("image_votes_" + id);
      div.innerHTML = request.responseText;
    }
  })
}
