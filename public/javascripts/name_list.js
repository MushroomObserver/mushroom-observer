// Which column key strokes will go to.
var NL_FOCUS = null;

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

// Prototype is missing a few useful keycodes.
Object.extend(Event, {
  KEY_PGUP:  33,
  KEY_PGDN:  34,
  KEY_END:   35,
  KEY_HOME:  36
});

// --------------------------------  Events  -----------------------------------

// Mouse moves over an item.
function na(s, i) {
  if (NL_CURSOR[s] != i)
    $(s + i).style.background = '#FF8';
}

// Mouse moves off of an item.
function nb(s, i) {
  if (NL_CURSOR[s] != i)
    $(s + i).style.background = '#FFF';
}

// Click on item.
function nc(s, i) {
  nl_focus(s);
  nl_move_cursor(s, i);
  if (s == 'g')
    nl_select_genus(NL_GENERA[i]);
}

// Double-click on item.
function nd(s, i) {
  if (s == 's')
    nl_insert_name(NL_SPECIES_CUR[i]);
  if (s == 'n')
    nl_remove_name(NL_NAMES[i]);
}

// Called when user presses a key.  We keep track of where user is typing by
// updating NL_FOCUS (value is 'g', 's' or 'n').
function nl_key(event) {
  if (!NL_FOCUS) return;

  var i = NL_CURSOR[NL_FOCUS];
  switch(event.keyCode) {

    // Move cursor up and down.
    case Event.KEY_UP:
      if (i != null) nl_move_cursor(NL_FOCUS, i - (event.ctrlKey ? 10 : 1));
      break;
    case Event.KEY_DOWN:
      nl_move_cursor(NL_FOCUS, i == null ? 0 : i + (event.ctrlKey ? 10 : 1));
      break;
    case Event.KEY_PGUP:
      if (i != null) nl_move_cursor(NL_FOCUS, i - 20);
      break;
    case Event.KEY_PGDN:
      nl_move_cursor(NL_FOCUS, i == null ? 20 : i + 20);
      break;
    case Event.KEY_HOME:
      if (i != null) nl_move_cursor(NL_FOCUS, 0);
      break;
    case Event.KEY_END:
      nl_move_cursor(NL_FOCUS, 10000000);
      break;

    // Switch columns.
    case Event.KEY_LEFT:
      NL_FOCUS = (NL_FOCUS == 'g') ? 'n' :
                 (NL_FOCUS == 's') ? 'g' : 's';
      nl_draw_cursors();
      break;
    case Event.KEY_RIGHT:
    case Event.KEY_TAB:
      NL_FOCUS = (NL_FOCUS == 'g') ? 's' :
                 (NL_FOCUS == 's') ? 'n' : 'g';
      nl_draw_cursors();
      break;

    // Select an item.
    case Event.KEY_RETURN:
      if (NL_FOCUS == 'g' && i != null) {
        nl_select_genus(NL_GENERA[i]);
        NL_FOCUS = 's';
        nl_draw_cursors();
      } else if (NL_FOCUS == 's' && i != null) {
        nl_insert_name(NL_SPECIES_CUR[i]);
      }
      break;

    // Delete item under cursor.
    case Event.KEY_BACKSPACE:
    case Event.KEY_DELETE:
      if (NL_FOCUS == 'n' && i != null)
        nl_remove_name(NL_NAMES[i]);
      break;

    // Break keyboard focus.
    case Event.KEY_ESC:
      nl_focus(null);
      break;

    // Let the rest pass through.
    default:
      return;
  }
  Event.stop(event);
}

// ---------------------------------  HTML  ------------------------------------

// Change focus from one column to another.
function nl_focus(s) {
  NL_FOCUS = s;
  nl_draw_cursors();
}

// Move cursor.
function nl_move_cursor(s, new_pos) {
  var old_pos = NL_CURSOR[s];
  NL_CURSOR[s] = new_pos;
  if (old_pos != null)
    $(s + old_pos).style.background = '#FFF';
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
    if (i < 0)            NL_CURSOR[s] = i = 0;
    if (i >= list.length) NL_CURSOR[s] = i = list.length - 1;
    $(s + i).style.background = (NL_FOCUS == s) ? '#F88' : '#FF8';
  } else {
    NL_CURSOR[s] = null;
  }
}

// Make sure cursor is visible in a given column.
function nl_warp(s) {
  var i = NL_CURSOR[s] || 0;
  var e = $(s + i);
  if (e) {
    var section = $(NL_DIVS[s]);
    var ey = e.y || e.offsetTop;
    var eh = e.offsetHeight;
    var sy = section.scrollTop;
    var sh = 450 - 17; // 17 is for scrollbar
    var ny = ey+eh > sy+sh ? ey+eh - sh : sy;
    ny = ey < ny ? ey : ny;
    if (sy != ny)
      section.scrollTop = ny;
  }
}

var IEFIX = (navigator.appVersion.indexOf('MSIE') > 0 &&
             navigator.userAgent.indexOf('Opera') < 0);

// Draw contents of one of the three columns.  Section is 'genera', 'species'
// or 'names'; list is GENERA, SPECIES or NAMES.
function nl_draw(s, list) {
  var section = NL_DIVS[s];
  var html = '';
  for (var i=0; i<list.length; i++) {
    var name = list[i];
    var author = '';
    var star = false;
    if (name.charAt(name.length-1) == '*') {
      name = name.substr(0,name.length-1);
      star = true;
    }
    var x = name.indexOf('|');
    if (x > 0) {
      author = ' <span class="normal">' + name.substr(x+1).escapeHTML() + '</span>';
      name = name.substr(0,x);
    }
    if (name.charAt(0) == '=') {
      name = '<span style="margin-left:10px">&nbsp;</span>= <b>' +
        name.substr(2).escapeHTML() + '</b>';
    } else if (star) {
      name = '<b>' + name.escapeHTML() + '</b>';
    } else {
      name = name.escapeHTML();
    }
    html += '<li' +
      ' id="' + s + i + '"' +
      ' onmouseover="na(\''+s+'\','+i+')"' +
      ' onmouseout="nb(\''+ s+'\','+i+')"' +
      ' onclick="nc(\''+    s+'\','+i+')"' +
      ' ondblclick="nd(\''+ s+'\','+i+')"' +
      '><nobr>' + name + author + '</nobr></li>';
  }
  html = '<ul>' + html + '</ul>';
  var e = $(section);
  if (IEFIX) {
    e.outerHTML = "<div id=\"" + section + "\" class=\"scroller\"" +
      " onclick=\"nl_focus('" + s + "')\">" + html +"</div>";
    // e.innerHTML = "";
    // setTimeout(function() { e.innerHTML = html }, 50);
  } else {
    e.innerHTML = html;
  }
}

// -------------------------------  Actions  -----------------------------------

// Select a genus.
function nl_select_genus(name) {
  var list = [name];
  var last = false;
  nl_move_cursor('s', null);
  if (name.charAt(name.length-1) == '*')
    name = name.substr(0,name.length-1);
  name += ' ';
  for (var i=0; i<NL_SPECIES.length; i++) {
    var species = NL_SPECIES[i];
    if (species.substr(0,name.length) == name ||
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

// Insert a name.
function nl_insert_name(name) {
  var new_list = [];
  if (name.charAt(0) == '=')
    name = name.substr(2) + '*';
  var name2 = name.replace('*', '');
  var done = false;
  for (var i=0; i<NL_NAMES.length; i++) {
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
  for (var i=0; i<NL_NAMES.length; i++)
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
  for (var i=0; i<NL_NAMES.length; i++)
    val += NL_NAMES[i] + "\n";
  $('results').value = val;
}

// Reverse of above: parse hidden 'results' field, and populate NL_NAMES.
function nl_initialize_names() {
  var str = $('results').value || '';
  str += "\n";
  var x;
  NL_NAMES = [];
  while ((x = str.indexOf("\n")) >= 0) {
    if (x > 0)
      NL_NAMES.push(str.substr(0, x));
    str = str.substr(x+1);
  }
}
