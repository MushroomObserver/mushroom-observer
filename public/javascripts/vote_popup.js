
// Popup little votes box.
function show_votes(this_id) {
  for (id in POPUPS) {
    var div = POPUPS[id]
    if (div) {
      if (id == this_id) {
        Element.center(div);
        Element.show(div);
      } else {
        Element.hide(div);
      }
    }
  }
}

// Close vote box.
function hide_votes(this_id) {
  for (id in POPUPS) {
    var div = POPUPS[id]
    if (div)
      Element.hide(div);
  }
}

// Called when vote is changed.
function change_vote(this_id) {
  if (VOTES[this_id].value == 100)
    for (id in POPUPS)
      if (id != this_id && VOTES[id].value == 100)
        VOTES[id].value = 80;
  CHANGED = 1;
}

// Called when submit button clicked (to prevent confirmation).
function set_changed(flag) {
  CHANGED = flag;
}

