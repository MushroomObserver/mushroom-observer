
function show_votes(this_id) {
  for (id in POPUPS) {
    var div = jQuery('#' + POPUPS[id]);
    if (div) {
      if (id == this_id) {
        div.center().show();
      } else {
        div.hide();
      }
    }
  }
}

function hide_votes(this_id) {
  for (id in POPUPS) {
    var div = jQuery('#' + POPUPS[id]);
    if (div) {
      div.hide();
    }
  }
}

function change_vote(this_id) {
  if (VOTES[this_id].value == 100)
    for (id in POPUPS)
      if (id != this_id && VOTES[id].value == 100)
        VOTES[id].value = 80;
  CHANGED = 1;
}

function set_changed(flag) {
  CHANGED = flag;
}

