function image_vote(id, value) {
  new Ajax.Request("/ajax/vote/image/" + id + "?value=" + value, {
    asynchronous: true,
    onComplete: function(request) {
      image_vote_success(id, request.responseText)
    }
  })
}

function image_vote_success(id, value) {
  image_vote_redraw(id, 'low', value);
  image_vote_redraw(id, 'medium', value);
  image_vote_redraw(id, 'high', value);
}

function image_vote_redraw(id, value1, value2) {
  var span = $("image_" + id + "_" + value1);
  var str = span.innerHTML.replace(/^<[^<>]*>/,'').replace(/<[^<>]*>$/,'');
  if (value1 == value2) {
    span.innerHTML = "<b>" + str + "</b>";
  } else {
    span.innerHTML = "<a href=\"#\" onclick=\"image_vote(" + id + ", '" +
                     value1 + "'); return false;\">" + str + "</a>";
  }
}
