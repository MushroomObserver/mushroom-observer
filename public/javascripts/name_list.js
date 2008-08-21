
function de(e, mode, name) {

  // Mouse moving over or off of an item.
  if (mode < 2) {
    $(e).style.background = mode ? '#FF8' : '#FFF';
  }

  // Click on genus changes list of species.
  else if (e.charAt(0) == 'g') {
    var list = [name];
    var last = false;
    if (name.charAt(name.length-1) == '*')
      name = name.substr(0,name.length-1);
    name += ' ';
    for (var i=0; i<SPECIES.length; i++) {
      var species = SPECIES[i];
      if (species.substr(0,name.length) == name ||
        species.charAt(0) == '=' && last) {
        list.push(species);
        last = true;
      } else {
        last = false;
      }
    }
    name_list_draw('species', list);
  }

  // Click on species adds name.
  else if (e.charAt(0) == 's') {
    var new_list = [];
    var last = null;
    var x = name.indexOf('=');
    if (x > 0)
      name = name.substr(x+2);
    for (var i=0; i<NAMES.length; i++) {
      var str = NAMES[i];
      if (str > name && (last == null || last < name))
        new_list.push(name);
      new_list.push(str);
      last = str;
    }
    if (last == null || last < name)
      new_list.push(name);
    NAMES = new_list;
    name_list_draw('names', NAMES);
    name_list_set_names();
  }

  // Click on name deletes it.
  else if (e.charAt(0) == 'n') {
    var new_list = [];
    for (var i=0; i<NAMES.length; i++)
      if (NAMES[i] != name)
        new_list.push(NAMES[i]);
    NAMES = new_list;
    name_list_draw('names', NAMES);
    name_list_set_names();
  }
}

var IEFIX = (navigator.appVersion.indexOf('MSIE') > 0 &&
             navigator.userAgent.indexOf('Opera') < 0);

// Draw contents of one of the three columns.  Section is 'genera', 'species'
// or 'names'; list is GENERA, SPECIES or NAMES.
function name_list_draw(section, list) {
  var s = section.charAt(0);
  var html = '';
  for (var i=0; i<list.length; i++) {
    var val = list[i];
    var name = val;
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
      val = val.substr(2) + '*';
      name = '<span style="margin-left:10px">&nbsp;</span>= <b>' +
        name.substr(2).escapeHTML() + '</b>';
    } else if (star) {
      name = '<b>' + name.escapeHTML() + '</b>';
    } else {
      name = name.escapeHTML();
    }
    val = val.replace(/'/g, "\\'").replace(/"/g, '&quot;')
    html += '<li' +
      ' id="' + s + i + '"' +
      ' onmouseout="de(\''  + s + i + '\',0,0)"' +
      ' onmouseover="de(\'' + s + i + '\',1,0)"' +
      ' onclick="de(\''     + s + i + '\',2,\'' + val + '\')"' +
      '><nobr>' + name + author + '</nobr></li>';
  }
  html = '<ul>' + html + '</ul>';
  var e = $(section);
  if (IEFIX) {
    e.innerHTML = "";
    setTimeout(function() { e.innerHTML = html }, 50);
  } else {
    e.innerHTML = html;
  }
}

// Concat names in NAMES and store in hidden 'results' field.
function name_list_set_names() {
  var val = '';
  for (var i=0; i<NAMES.length; i++)
    val += NAMES[i] + "\n";
  $('results').value = val;
}

// Reverse of above: parse hidden 'results' field, and populate NAMES.
function name_list_initialize_names() {
  var str = $('results').value || '';
  str += "\n";
  var x;
  for (var i=0; (x = str.indexOf("\n")) >= 0; ) {
    if (x > 0)
      NAMES[i++] = str.substr(0, x);
    str = str.substr(x+1);
  }
}
