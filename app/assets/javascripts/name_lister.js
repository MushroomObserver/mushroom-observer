// Which column key strokes will go to.
var NL_FOCUS = null;

// Kludge to tell it to ignore click event on outer div after processing click
// event within one of the three columns.
var NL_IGNORE_UNFOCUS = false;

// Keycode of key that's currently pressed if any (and if focused).
var NL_KEY = null;

// Callback used to simulate key repeats.
var NL_REPEAT_CALLBACK = null;

// Timing of key repeat.
var NL_FIRST_KEY_DELAY = 250;
var NL_NEXT_KEY_DELAY = 25;

// Accumulator for typed letters, used to search in columns.
var NL_WORD = "";

// Cursor position in each column.
var NL_CURSOR = {
  g: null,
  s: null,
  n: null
};

// These are the ids of the divs for each column.
var NL_DIVS = {
  g: 'genera',
  s: 'species',
  n: 'names'
};

// Current subset of SPECIES that is being dsplayed.
var NL_SPECIES_CUR = [];

// --------------------------------  Events  -----------------------------------

// Mouse moves over an item.
function na(s, i) {
  if (NL_CURSOR[s] != i)
    jQuery("#" + s + i).addClass("hot");
}

// Mouse moves off of an item.
function nb(s, i) {
  if (NL_CURSOR[s] != i)
    jQuery("#" + s + i).removeClass("hot warm");
}

// Click on item.
function nc(s, i) {
  nl_clear_word();
  nl_focus(s);
  nl_move_cursor(s, i);
  if (s == 'g')
    nl_select_genus(NL_GENERA[i]);
  NL_IGNORE_UNFOCUS = true;
}

// Double-click on item.
function nd(s, i) {
  if (s == 's')
    nl_insert_name(NL_SPECIES_CUR[i]);
  if (s == 'n')
    nl_remove_name(NL_NAMES[i]);
}

// Are we watching this key event?
function nl_watching(event) {
  var c = String.fromCharCode(event.keyCode || event.which).toLowerCase();
  if (c.match(/[a-zA-Z \-]/) && !event.ctrlKey)
    return true;
  switch (event.keyCode) {
    case EVENT_KEY_BACKSPACE:
    case EVENT_KEY_DELETE:
    case EVENT_KEY_RETURN:
    case EVENT_KEY_TAB:
    case EVENT_KEY_UP:
    case EVENT_KEY_DOWN:
    case EVENT_KEY_RIGHT:
    case EVENT_KEY_LEFT:
    case EVENT_KEY_HOME:
    case EVENT_KEY_END:
    case EVENT_KEY_PAGEUP:
    case EVENT_KEY_PAGEDOWN:
      return true;
  }
  return false;
}

// Also called when user presses a key.  Disable this if focused.
function nl_keypress(event) {
  if (NL_FOCUS && nl_watching(event)) {
    event.stopPropagation();
    return false;
  } else {
    return true;
  }
}

// Called when user un-presses a key.  Need to know so we can stop repeat.
function nl_keyup(event) {
  NL_KEY = null;
  if (NL_REPEAT_CALLBACK) {
    clearTimeout(NL_REPEAT_CALLBACK);
    NL_REPEAT_CALLBACK = null;
  }
}

// Called when user presses a key.  We keep track of where user is typing by
// updating NL_FOCUS (value is 'g', 's' or 'n').
function nl_keydown(event) {

  // Cursors, etc. must be explicitly focused to work.  (Otherwise you can't
  // use them to navigate through the page as a whole.)
  if (!NL_FOCUS || !nl_watching(event)) return true;

  NL_KEY = event;
  nl_process_key(event);

  // Schedule first repeat event.
  NL_REPEAT_CALLBACK =
    window.setTimeout(function () { nl_keyrepeat(NL_KEY) }, NL_FIRST_KEY_DELAY);

  // Stop browser from doing anything with key presses when focused.
  event.stopPropagation();
  return false;
}

// Called when a key repeats.
function nl_keyrepeat(event) {
  if (NL_FOCUS && NL_KEY) {
    nl_process_key(NL_KEY);
    NL_REPEAT_CALLBACK =
      window.setTimeout(function () { nl_keyrepeat(NL_KEY) }, NL_NEXT_KEY_DELAY);
  } else {
    NL_KEY = null;
  }
}

// Process a key stroke.  This happens when the user first presses a key, and
// periodically after if they keep the key down.
function nl_process_key(event) {

  // Normal letters.
  var c = String.fromCharCode(event.keyCode || event.which).toLowerCase();
  if (c.match(/[a-zA-Z \-]/) && !event.ctrlKey ||
    event.keyCode == EVENT_KEY_BACKSPACE) {

    // Update word with new letter or backspace.
    if (event.keyCode != EVENT_KEY_BACKSPACE) {
      NL_WORD += c;
      // If start typing with no focus, assume they mean genus.
      if (!NL_FOCUS) NL_FOCUS = 'g';
    } else if (NL_WORD != '') {
      NL_WORD = NL_WORD.substr(0, NL_WORD.length - 1);
    }

    // Search for partial word.
    var list = NL_FOCUS == 'g' ? NL_GENERA :
      NL_FOCUS == 's' ? NL_SPECIES_CUR : NL_NAMES;
    var word = NL_WORD;
    if (NL_FOCUS == 's')
      word = NL_SPECIES_CUR[0].replace(/\*$|\|.*/, '') + ' ' + NL_WORD;
    nl_search(list, word);
    nl_update_word(word);
    return;
  }

  // Clear word if user does *anything* else.
  var old_word = NL_WORD;
  nl_clear_word();

  // Other strokes.
  var i = NL_CURSOR[NL_FOCUS];
  switch (event.keyCode) {

    // Move cursor up and down.
    case EVENT_KEY_UP:
      if (i != null) nl_move_cursor(NL_FOCUS, i - (event.ctrlKey ? 10 : 1));
      break;
    case EVENT_KEY_DOWN:
      nl_move_cursor(NL_FOCUS, i == null ? 0 : i + (event.ctrlKey ? 10 : 1));
      break;
    case EVENT_KEY_PAGEUP:
      if (i != null) nl_move_cursor(NL_FOCUS, i - 20);
      break;
    case EVENT_KEY_PAGEDOWN:
      nl_move_cursor(NL_FOCUS, i == null ? 20 : i + 20);
      break;
    case EVENT_KEY_HOME:
      if (i != null) nl_move_cursor(NL_FOCUS, 0);
      break;
    case EVENT_KEY_END:
      nl_move_cursor(NL_FOCUS, 10000000);
      break;

    // Switch columns.
    case EVENT_KEY_LEFT:
      NL_FOCUS = (NL_FOCUS == 'g') ? 'n' : (NL_FOCUS == 's') ? 'g' : 's';
      nl_draw_cursors();
      break;
    case EVENT_KEY_RIGHT:
      NL_FOCUS = (NL_FOCUS == 'g') ? 's' : (NL_FOCUS == 's') ? 'n' : 'g';
      nl_draw_cursors();
      break;
    case EVENT_KEY_TAB:
      if (event.shiftKey) {
        NL_FOCUS = (NL_FOCUS == 'g') ? 'n' : (NL_FOCUS == 's') ? 'g' : 's';
      } else if (NL_FOCUS == 'g') {
        // Select current genus AND move to species column if press tab in genus column.
        nl_select_genus(NL_GENERA[i]);
        NL_FOCUS = 's';
      } else {
        NL_FOCUS = (NL_FOCUS == 's') ? 'n' : 'g';
      }
      nl_draw_cursors();
      break;

    // Select an item.
    case EVENT_KEY_RETURN:
      if (NL_FOCUS == 'g' && i != null) {
        nl_select_genus(NL_GENERA[i]);
        NL_FOCUS = 's';
        nl_draw_cursors();
      } else if (NL_FOCUS == 's' && i != null) {
        nl_insert_name(NL_SPECIES_CUR[i]);
      }
      break;

    // Delete item under cursor.
    case EVENT_KEY_DELETE:
      if (NL_FOCUS == 'n' && i != null)
        nl_remove_name(NL_NAMES[i]);
      break;
  }
}

// ---------------------------------  HTML  ------------------------------------

// Change focus from one column to another.
function nl_focus(s) {
  NL_FOCUS = s;
  nl_draw_cursors();
}

// Unfocus to let user scroll the page with keyboard.
function nl_unfocus() {
  if (!NL_IGNORE_UNFOCUS) {
    NL_FOCUS = null;
    nl_draw_cursors();
  } else {
    NL_IGNORE_UNFOCUS = false;
  }
}

// Update partial word accumulated from typing normal letters.
function nl_update_word(val) {
  jQuery("#word").html(val == '' ? '&nbsp;' : val);
}

// Clear partial word (after mving cursor, clicking on something, etc.)
function nl_clear_word() {
  if (NL_WORD != '')
    nl_update_word(NL_WORD = '');
}

// Move cursor.
function nl_move_cursor(s, new_pos) {
  var old_pos = NL_CURSOR[s];
  NL_CURSOR[s] = new_pos;
  if (old_pos != null)
    jQuery("#" + s + old_pos).removeClass("hot warm");
  nl_draw_cursors();
  nl_warp(s);
}

// Redraw all the cursors.
function nl_draw_cursors() {
  // Make sure there *is* a cursor in the focused section.
  if (NL_FOCUS && NL_CURSOR[NL_FOCUS] == null)
    NL_CURSOR[NL_FOCUS] = 0;
  nl_draw_cursor('g', NL_GENERA);
  nl_draw_cursor('s', NL_SPECIES_CUR);
  nl_draw_cursor('n', NL_NAMES);
}

// Draw a single cursor, making sure div is scrolled so we can see it.
function nl_draw_cursor(s, list) {
  var i = NL_CURSOR[s];
  if (list.length > 0 && i != null) {
    if (i < 0) NL_CURSOR[s] = i = 0;
    if (i >= list.length) NL_CURSOR[s] = i = list.length - 1;
    jQuery("#" + s + i).removeClass("hot warm").addClass(NL_FOCUS == s ? "warm" : "hot");
  } else {
    NL_CURSOR[s] = null;
  }
}

var scroll_bar_width = null;

// Make sure cursor is visible in a given column.
function nl_warp(s) {
  var i = NL_CURSOR[s] || 0;
  var e = jQuery("#" + s + i);
  if (!scroll_bar_width)
    scroll_bar_width = e.getScrollBarWidth();
  if (e && e.offset()) {
    var section = jQuery("#" + NL_DIVS[s]);
    var ey = e.offset().top - e.parent().offset().top;
    var eh = e.outerHeight();
    var sy = section.scrollTop();
    var sh = 450 - scroll_bar_width;
    var ny = ey + eh > sy + sh ? ey + eh - sh : sy;
    ny = ey < ny ? ey : ny;
    if (sy != ny)
      section.scrollTop(ny);
  }
}

var IEFIX = (navigator.appVersion.indexOf('MSIE') > 0 &&
  navigator.userAgent.indexOf('Opera') < 0);

// Draw contents of one of the three columns.  Section is 'genera', 'species'
// or 'names'; list is GENERA, SPECIES or NAMES.
function nl_draw(s, list) {
  var section = NL_DIVS[s];
  var html = '';
  for (var i = 0; i < list.length; i++) {
    var name = list[i];
    var author = '';
    var star = false;
    if (name.charAt(name.length - 1) == '*') {
      name = name.substr(0, name.length - 1);
      star = true;
    }
    var x = name.indexOf('|');
    if (x > 0) {
      author = ' <span class="normal">' + name.substr(x + 1).escapeHTML() + '</span>';
      name = name.substr(0, x);
    }
    if (name.charAt(0) == '=') {
      name = '<span class="ml-2">&nbsp;</span>= <b>' +
        name.substr(2).escapeHTML() + '</b>';
    } else if (star) {
      name = '<b>' + name.escapeHTML() + '</b>';
    } else {
      name = name.escapeHTML();
    }
    html += '<li' +
      ' id="' + s + i + '"' +
      ' onmouseover="na(\'' + s + '\',' + i + ')"' +
      ' onmouseout="nb(\'' + s + '\',' + i + ')"' +
      ' onclick="nc(\'' + s + '\',' + i + ')"' +
      ' ondblclick="nd(\'' + s + '\',' + i + ')"' +
      '><nobr>' + name + author + '</nobr></li>';
  }
  html = '<ul>' + html + '</ul>';
  if (IEFIX) {
    document.getElementById(section).outerHTML =
      "<div id=\"" + section + "\" class=\"scroller\"" +
      " onclick=\"nl_focus('" + s + "')\">" + html + "</div>";
  } else {
    jQuery("#" + section).html(html);
  }
}

// -------------------------------  Actions  -----------------------------------

// Select a genus.
function nl_select_genus(name) {
  var list = [name];
  var last = false;
  nl_move_cursor('s', null);
  if (name.charAt(name.length - 1) == '*')
    name = name.substr(0, name.length - 1);
  name += ' ';
  for (var i = 0; i < NL_SPECIES.length; i++) {
    var species = NL_SPECIES[i];
    if (species.substr(0, name.length) == name ||
      species.charAt(0) == '=' && last) {
      list.push(species);
      last = true;
    } else {
      last = false;
    }
  }
  NL_CURSOR['s'] = null;
  NL_SPECIES_CUR = list;
  nl_draw('s', list);
  nl_warp('s');
}

// Search in list for word and move cursor there.
function nl_search(list, word) {
  var word_len = word.length;
  word = word.toLowerCase();
  for (var i = 0; i < list.length; i++) {
    if (list[i].substr(0, word_len).toLowerCase() == word) {
      nl_move_cursor(NL_FOCUS, i);
      break;
    }
  }
}

// Insert a name.
function nl_insert_name(name) {
  var new_list = [];
  if (name.charAt(0) == '=')
    name = name.substr(2) + '*';
  var name2 = name.replace('*', '');
  var done = false;
  for (var i = 0; i < NL_NAMES.length; i++) {
    var str = NL_NAMES[i];
    if (!done && str.replace('*', '') >= name2) {
      if (str != name)
        new_list.push(name);
      NL_CURSOR['n'] = i;
      done = true;
    }
    new_list.push(str);
    last = str;
  }
  if (!done) {
    new_list.push(name);
    NL_CURSOR['n'] = new_list.length - 1;
  }
  NL_NAMES = new_list;
  nl_draw('n', NL_NAMES);
  nl_draw_cursors();
  nl_warp('n');
  nl_set_results();
}

// Remove a name.
function nl_remove_name(name) {
  var new_list = [];
  for (var i = 0; i < NL_NAMES.length; i++)
    if (NL_NAMES[i] == name)
      NL_CURSOR['n'] = i;
    else
      new_list.push(NL_NAMES[i]);
  NL_NAMES = new_list;
  nl_draw('n', NL_NAMES);
  nl_draw_cursors();
  nl_warp('n');
  nl_set_results();
}

// Concat names in NL_NAMES and store in hidden 'results' field.
function nl_set_results() {
  var val = '';
  for (var i = 0; i < NL_NAMES.length; i++)
    val += NL_NAMES[i] + "\n";
  jQuery("#results").val(val);
}

// Reverse of above: parse hidden 'results' field, and populate NL_NAMES.
function nl_initialize_names() {
  var str = jQuery("#results").val() || '';
  str += "\n";
  var x;
  NL_NAMES = [];
  while ((x = str.indexOf("\n")) >= 0) {
    if (x > 0)
      NL_NAMES.push(str.substr(0, x));
    str = str.substr(x + 1);
  }
}
