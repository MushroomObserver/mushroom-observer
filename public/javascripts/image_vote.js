function image_vote(id, value) {
  new Ajax.Request("/ajax/vote/image/" + id + "?value=" + value, {
    asynchronous: true,
    onComplete: function(request) {
      image_vote_success(id, request.responseText)
    }
  })
}

function image_vote_success(id, value) {
  image_vote_redraw(id, '1', value);
  image_vote_redraw(id, '2', value);
  image_vote_redraw(id, '3', value);
  image_vote_redraw(id, '4', value);
}

function image_vote_redraw(id, value1, value2) {
  var span = $("image_" + id + "_" + value1);
  var str = span.innerHTML.replace(/^(<[^<>]*>)*/,'').replace(/(<[^<>]*>)*$/,'');
  var help = span.innerHTML.replace(/^.*title="/,'').replace(/".*/,'');
  if (value1 == value2) {
    span.innerHTML = "<b><acronym title=\"" + help + "\">" +
                     str + "</acronym></b>";
  } else {
    span.innerHTML = "<a href=\"#\" onclick=\"image_vote(" + id + ", '" +
                     value1 + "'); return false;\" title=\"" + help + "\">" +
                     str + "</a>";
  }
}
