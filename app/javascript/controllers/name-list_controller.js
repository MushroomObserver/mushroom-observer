import { Controller } from "@hotwired/stimulus"
import { escapeHTML, getScrollBarWidth } from "src/mo_utilities"

// Connects to data-controller="name-list"
export default class extends Controller {
  initialize() {
    // Which column key strokes will go to.
    this.NL_FOCUS = null;
    // Kludge to tell it to ignore click event on outer div after processing
    // click event within one of the three columns.
    this.NL_IGNORE_UNFOCUS = false;
    // Keycode of key that's currently pressed if any (and if focused).
    this.NL_KEY = null;
    // Callback used to simulate key repeats.
    this.NL_REPEAT_CALLBACK = null;
    // Timing of key repeat.
    this.NL_FIRST_KEY_DELAY = 250;
    this.NL_NEXT_KEY_DELAY = 25;
    // Accumulator for typed letters, used to search in columns.
    this.NL_WORD = "";
    // Cursor position in each column.
    this.NL_CURSOR = {
      g: null,
      s: null,
      n: null
    };
    // These are the ids of the divs for each column.
    this.NL_DIVS = {
      g: 'genera',
      s: 'species',
      n: 'names'
    };
    // Current subset of SPECIES that is being dsplayed.
    this.NL_SPECIES_CUR = [];

    this.scroll_bar_width = null;

    this.EVENT_KEY_TAB = 9;
    this.EVENT_KEY_RETURN = 13;
    this.EVENT_KEY_ESC = 27;
    this.EVENT_KEY_BACKSPACE = 8;
    this.EVENT_KEY_DELETE = 46;
    this.EVENT_KEY_UP = 38;
    this.EVENT_KEY_DOWN = 40;
    this.EVENT_KEY_LEFT = 37;
    this.EVENT_KEY_RIGHT = 39;
    this.EVENT_KEY_PAGEUP = 33;
    this.EVENT_KEY_PAGEDOWN = 34;
    this.EVENT_KEY_HOME = 36;
    this.EVENT_KEY_END = 35;

    // Shared MO utilities imported
    Object.assign(this, escapeHTML)
    Object.assign(this, getScrollBarWidth)
  }

  connect() {
    this.nl_initialize_names();
    this.nl_draw("g", this.NL_GENERA);
    this.nl_draw("n", this.NL_NAMES);
    document.addEventListener("keypress", this.nl_keypress);
    document.addEventListener("keydown", this.nl_keydown);
    document.addEventListener("keyup", this.nl_keyup);
    document.addEventListener("click", this.nl_unfocus);
    this.nc("g", 0); // click on first genus
  }

  // -------------------------------  Events  ---------------------------------

  // The controller itself prints the <li> with this dataset, below.
  getDataFromEventTarget(event) {
    const s = event.target?.dataset.s
    const i = event.target?.dataset.i
    return [s, i]
  }

  // Mouse moves over an item.
  na(event) {
    const [s, i] = this.getDataFromEventTarget(event)

    if (this.NL_CURSOR[s] != i)
      document.getElementById(s + i).classList.add("hot");
  }

  // Mouse moves off of an item.
  nb(event) {
    const [s, i] = this.getDataFromEventTarget(event)

    if (this.NL_CURSOR[s] != i)
      document.getElementById(s + i).classList.remove("hot", "warm");
  }

  // Click on item.
  nc(event) {
    const [s, i] = this.getDataFromEventTarget(event)

    this.nl_clear_word();
    this.nl_focus(s);
    this.nl_move_cursor(s, i);
    if (s == 'g')
      this.nl_select_genus(this.NL_GENERA[i]);
    this.NL_IGNORE_UNFOCUS = true;
  }

  // Double-click on item.
  nd(event) {
    const [s, i] = this.getDataFromEventTarget(event)

    if (s == 's')
      this.nl_insert_name(this.NL_SPECIES_CUR[i]);
    if (s == 'n')
      this.nl_remove_name(this.NL_NAMES[i]);
  }

  // Are we watching this key event?
  nl_watching(event) {
    const c = String.fromCharCode(event.keyCode || event.which).toLowerCase();
    if (c.match(/[a-zA-Z \-]/) && !event.ctrlKey)
      return true;
    switch (event.keyCode) {
      case this.EVENT_KEY_BACKSPACE:
      case this.EVENT_KEY_DELETE:
      case this.EVENT_KEY_RETURN:
      case this.EVENT_KEY_TAB:
      case this.EVENT_KEY_UP:
      case this.EVENT_KEY_DOWN:
      case this.EVENT_KEY_RIGHT:
      case this.EVENT_KEY_LEFT:
      case this.EVENT_KEY_HOME:
      case this.EVENT_KEY_END:
      case this.EVENT_KEY_PAGEUP:
      case this.EVENT_KEY_PAGEDOWN:
        return true;
    }
    return false;
  }

  // Also called when user presses a key.  Disable this if focused.
  nl_keypress(event) {
    if (this.NL_FOCUS && this.nl_watching(event)) {
      event.stopPropagation();
      return false;
    } else {
      return true;
    }
  }

  // Called when user un-presses a key.  Need to know so we can stop repeat.
  nl_keyup(event) {
    this.NL_KEY = null;
    if (this.NL_REPEAT_CALLBACK) {
      clearTimeout(this.NL_REPEAT_CALLBACK);
      this.NL_REPEAT_CALLBACK = null;
    }
  }

  // Called when user presses a key.  We keep track of where user is typing by
  // updating NL_FOCUS (value is 'g', 's' or 'n').
  nl_keydown(event) {

    // Cursors, etc. must be explicitly focused to work.  (Otherwise you can't
    // use them to navigate through the page as a whole.)
    if (!this.NL_FOCUS || !this.nl_watching(event)) return true;

    this.NL_KEY = event;
    this.nl_process_key(event);

    // Schedule first repeat event.
    this.NL_REPEAT_CALLBACK =
      window.setTimeout(
        () => { this.nl_keyrepeat(NL_KEY) }, this.NL_FIRST_KEY_DELAY
      );

    // Stop browser from doing anything with key presses when focused.
    event.stopPropagation();
    return false;
  }

  // Called when a key repeats.
  nl_keyrepeat(event) {
    if (this.NL_FOCUS && this.NL_KEY) {
      this.nl_process_key(this.NL_KEY);
      this.NL_REPEAT_CALLBACK =
        window.setTimeout(
          () => { this.nl_keyrepeat(NL_KEY) }, this.NL_NEXT_KEY_DELAY
        );
    } else {
      this.NL_KEY = null;
    }
  }

  // Process a key stroke.  This happens when the user first presses a key, and
  // periodically after if they keep the key down.
  nl_process_key(event) {

    // Normal letters.
    const c = String.fromCharCode(event.keyCode || event.which).toLowerCase();
    if (c.match(/[a-zA-Z \-]/) && !event.ctrlKey ||
      event.keyCode == this.EVENT_KEY_BACKSPACE) {

      // Update word with new letter or backspace.
      if (event.keyCode != this.EVENT_KEY_BACKSPACE) {
        this.NL_WORD += c;
        // If start typing with no focus, assume they mean genus.
        if (!this.NL_FOCUS) this.NL_FOCUS = 'g';
      } else if (this.NL_WORD != '') {
        this.NL_WORD = this.NL_WORD.substr(0, this.NL_WORD.length - 1);
      }

      // Search for partial word.
      const list = this.NL_FOCUS == 'g' ? this.NL_GENERA :
        this.NL_FOCUS == 's' ? this.NL_SPECIES_CUR : this.NL_NAMES;
      let word = this.NL_WORD;
      if (this.NL_FOCUS == 's')
        word =
          this.NL_SPECIES_CUR[0].replace(/\*$|\|.*/, '') + ' ' + this.NL_WORD;
      this.nl_search(list, word);
      this.nl_update_word(word);
      return;
    }

    // Clear word if user does *anything* else.
    // const old_word = this.NL_WORD;
    this.nl_clear_word();

    // Other strokes.
    let i = this.NL_CURSOR[NL_FOCUS];
    switch (event.keyCode) {

      // Move cursor up and down.
      case this.EVENT_KEY_UP:
        if (i != null) this.nl_move_cursor(
          this.NL_FOCUS, i - (event.ctrlKey ? 10 : 1)
        );
        break;
      case this.EVENT_KEY_DOWN:
        this.nl_move_cursor(
          this.NL_FOCUS, i == null ? 0 : i + (event.ctrlKey ? 10 : 1)
        );
        break;
      case this.EVENT_KEY_PAGEUP:
        if (i != null) this.nl_move_cursor(this.NL_FOCUS, i - 20);
        break;
      case this.EVENT_KEY_PAGEDOWN:
        this.nl_move_cursor(this.NL_FOCUS, i == null ? 20 : i + 20);
        break;
      case this.EVENT_KEY_HOME:
        if (i != null) this.nl_move_cursor(this.NL_FOCUS, 0);
        break;
      case this.EVENT_KEY_END:
        this.nl_move_cursor(this.NL_FOCUS, 10000000);
        break;

      // Switch columns.
      case this.EVENT_KEY_LEFT:
        this.NL_FOCUS = (this.NL_FOCUS == 'g') ? 'n'
          : (this.NL_FOCUS == 's') ? 'g' : 's';
        this.nl_draw_cursors();
        break;
      case this.EVENT_KEY_RIGHT:
        this.NL_FOCUS = (this.NL_FOCUS == 'g') ? 's'
          : (this.NL_FOCUS == 's') ? 'n' : 'g';
        this.nl_draw_cursors();
        break;
      case this.EVENT_KEY_TAB:
        if (event.shiftKey) {
          this.NL_FOCUS = (this.NL_FOCUS == 'g') ? 'n'
            : (this.NL_FOCUS == 's') ? 'g' : 's';
        } else if (this.NL_FOCUS == 'g') {
          // Select current genus AND move to species column
          // if press tab in genus column.
          this.nl_select_genus(this.NL_GENERA[i]);
          this.NL_FOCUS = 's';
        } else {
          this.NL_FOCUS = (this.NL_FOCUS == 's') ? 'n' : 'g';
        }
        this.nl_draw_cursors();
        break;

      // Select an item.
      case this.EVENT_KEY_RETURN:
        if (this.NL_FOCUS == 'g' && i != null) {
          this.nl_select_genus(this.NL_GENERA[i]);
          this.NL_FOCUS = 's';
          this.nl_draw_cursors();
        } else if (this.NL_FOCUS == 's' && i != null) {
          this.nl_insert_name(this.NL_SPECIES_CUR[i]);
        }
        break;

      // Delete item under cursor.
      case this.EVENT_KEY_DELETE:
        if (this.NL_FOCUS == 'n' && i != null)
          this.nl_remove_name(this.NL_NAMES[i]);
        break;
    }
  }

  // --------------------------------  HTML  ----------------------------------

  // Change focus from one column to another.
  nl_focus(event) {
    const s = event.target.id[0]
    this.NL_FOCUS = s;
    this.nl_draw_cursors();
  }

  // Unfocus to let user scroll the page with keyboard.
  nl_unfocus() {
    if (!this.NL_IGNORE_UNFOCUS) {
      this.NL_FOCUS = null;
      this.nl_draw_cursors();
    } else {
      this.NL_IGNORE_UNFOCUS = false;
    }
  }

  // Update partial word accumulated from typing normal letters.
  nl_update_word(val) {
    document.getElementById("word").innerHTML = (val == '' ? '&nbsp;' : val);
  }

  // Clear partial word (after mving cursor, clicking on something, etc.)
  nl_clear_word() {
    if (this.NL_WORD != '')
      this.nl_update_word(this.NL_WORD = '');
  }

  // Move cursor.
  nl_move_cursor(s, new_pos) {
    const old_pos = this.NL_CURSOR[s];
    this.NL_CURSOR[s] = new_pos;
    if (old_pos != null)
      document.getElementById(s + old_pos).classList.remove("hot", "warm");
    this.nl_draw_cursors();
    this.nl_warp(s);
  }

  // Redraw all the cursors.
  nl_draw_cursors() {
    // Make sure there *is* a cursor in the focused section.
    if (this.NL_FOCUS && this.NL_CURSOR[this.NL_FOCUS] == null)
      this.NL_CURSOR[this.NL_FOCUS] = 0;
    this.nl_draw_cursor('g', this.NL_GENERA);
    this.nl_draw_cursor('s', this.NL_SPECIES_CUR);
    this.nl_draw_cursor('n', this.NL_NAMES);
  }

  // Draw a single cursor, making sure div is scrolled so we can see it.
  nl_draw_cursor(s, list = []) {
    let i = this.NL_CURSOR[s];
    if (list.length > 0 && i != null) {
      if (i < 0) this.NL_CURSOR[s] = i = 0;
      if (i >= list.length) this.NL_CURSOR[s] = i = list.length - 1;
      document.getElementById(s + i)
        .classList.remove("hot", "warm")
        .add(this.NL_FOCUS == s ? "warm" : "hot");
    } else {
      this.NL_CURSOR[s] = null;
    }
  }

  // Make sure cursor is visible in a given column.
  nl_warp(s) {
    if (s == undefined)
      return
    let i = this.NL_CURSOR[s] || 0;
    let e = document.getElementById(s + i);
    if (!this.scroll_bar_width)
      this.scroll_bar_width = e.getScrollBarWidth();
    if (e && e.offsetTop) {
      const section = document.getElementById(this.NL_DIVS[s]);
      const ey = e.offsetTop - e.parentElement.offsetTop;
      const eh = e.offsetHeight;
      const sy = section.scrollTop;
      const sh = 450 - scroll_bar_width;
      const ny = ey + eh > sy + sh ? ey + eh - sh : sy;
      ny = ey < ny ? ey : ny;
      if (sy != ny)
        section.scrollTop = ny;
    }
  }

  // Draw contents of one of the three columns.  Section is 'genera', 'species'
  // or 'names'; list is GENERA, SPECIES or NAMES.
  nl_draw(s, list = []) {
    const section = this.NL_DIVS[s];
    let html = '';
    for (let i = 0; i < list.length; i++) {
      let name = list[i];
      let author = '';
      let star = false;
      if (name.charAt(name.length - 1) == '*') {
        name = name.substr(0, name.length - 1);
        star = true;
      }
      const x = name.indexOf('|');
      if (x > 0) {
        author = ' <span class="normal">'
          + name.substr(x + 1).escapeHTML()
          + '</span>';
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
        ' data-s="' + s + '"' +
        ' data-i="' + i + '"' +
        ' data-action="' +
        ' mouseover->name-list#na' +
        ' mouseout->name-list#nb' +
        ' click->name-list#nc' +
        ' dblclick->name-list#nd"' +
        '><nobr>' + name + author + '</nobr></li>';
    }
    html = '<ul>' + html + '</ul>';

    document.getElementById(section).innerHTML = html;
  }

  // ------------------------------  Actions  ---------------------------------

  // Select a genus.
  nl_select_genus(name) {
    let list = [name];
    let last = false;
    this.nl_move_cursor('s', null);
    if (name.charAt(name.length - 1) == '*')
      name = name.substr(0, name.length - 1);
    name += ' ';
    for (let i = 0; i < NL_SPECIES.length; i++) {
      const species = NL_SPECIES[i];
      if (species.substr(0, name.length) == name ||
        species.charAt(0) == '=' && last) {
        list.push(species);
        last = true;
      } else {
        last = false;
      }
    }
    this.NL_CURSOR['s'] = null;
    this.NL_SPECIES_CUR = list;
    this.nl_draw('s', list);
    this.nl_warp('s');
  }

  // Search in list for word and move cursor there.
  nl_search(list = [], word) {
    const word_len = word.length;
    word = word.toLowerCase();
    for (let i = 0; i < list.length; i++) {
      if (list[i].substr(0, word_len).toLowerCase() == word) {
        this.nl_move_cursor(NL_FOCUS, i);
        break;
      }
    }
  }

  // Insert a name.
  nl_insert_name(name) {
    let new_list = [];
    let last;
    if (name.charAt(0) == '=')
      name = name.substr(2) + '*';
    const name2 = name.replace('*', '');
    let done = false;
    for (let i = 0; i < NL_NAMES.length; i++) {
      const str = NL_NAMES[i];
      if (!done && str.replace('*', '') >= name2) {
        if (str != name)
          new_list.push(name);
        this.NL_CURSOR['n'] = i;
        done = true;
      }
      new_list.push(str);
      last = str;
    }
    if (!done) {
      new_list.push(name);
      this.NL_CURSOR['n'] = new_list.length - 1;
    }
    this.NL_NAMES = new_list;
    this.nl_draw('n', this.NL_NAMES);
    this.nl_draw_cursors();
    this.nl_warp('n');
    this.nl_set_results();
  }

  // Remove a name.
  nl_remove_name(name) {
    let new_list = [];
    for (let i = 0; i < this.NL_NAMES.length; i++)
      if (this.NL_NAMES[i] == name)
        this.NL_CURSOR['n'] = i;
      else
        new_list.push(this.NL_NAMES[i]);
    this.NL_NAMES = new_list;
    this.nl_draw('n', this.NL_NAMES);
    this.nl_draw_cursors();
    this.nl_warp('n');
    this.nl_set_results();
  }

  // Concat names in NL_NAMES and store in hidden 'results' field.
  nl_set_results() {
    let val = '';
    for (let i = 0; i < this.NL_NAMES.length; i++)
      val += this.NL_NAMES[i] + "\n";
    document.getElementById("results").value = val;
  }

  // Reverse of above: parse hidden 'results' field, and populate NL_NAMES.
  nl_initialize_names() {
    let str = document.getElementById("results").value || '';
    str += "\n";
    let x;
    this.NL_NAMES = [];
    while ((x = str.indexOf("\n")) >= 0) {
      if (x > 0)
        this.NL_NAMES.push(str.substr(0, x));
      str = str.substr(x + 1);
    }
  }

  // ------------------------------- UTILITIES ------------------------------

  // These methods are also used in autocompleter_controller
  // Stimulus: May want to make a shared module
  // escapeHTML(str) {
  //   const HTML_ENTITY_MAP = {
  //     "&": "&amp;",
  //     "<": "&lt;",
  //     ">": "&gt;",
  //     '"': '&quot;',
  //     "'": '&#39;',
  //     "/": '&#x2F;'
  //   };

  //   return str.replace(/[&<>"'\/]/g, function (s) {
  //     return HTML_ENTITY_MAP[s];
  //   });
  // }

  // getScrollBarWidth() {
  //   let inner, outer, w1, w2;
  //   const body = document.body || document.getElementsByTagName("body")[0];

  //   if (this.scrollbar_width != null)
  //     return this.scrollbar_width;

  //   inner = document.createElement('p');
  //   inner.style.width = "100%";
  //   inner.style.height = "200px";

  //   outer = document.createElement('div');
  //   outer.style.position = "absolute";
  //   outer.style.top = "0px";
  //   outer.style.left = "0px";
  //   outer.style.visibility = "hidden";
  //   outer.style.width = "200px";
  //   outer.style.height = "150px";
  //   outer.style.overflow = "hidden";
  //   outer.appendChild(inner);

  //   body.appendChild(outer);
  //   w1 = inner.offsetWidth;
  //   outer.style.overflow = 'scroll';
  //   w2 = inner.offsetWidth;
  //   if (w1 == w2) w2 = outer.clientWidth;
  //   body.removeChild(outer);

  //   this.scrollbar_width = w1 - w2;
  //   // return scroll_bar_width;
  // }
}
