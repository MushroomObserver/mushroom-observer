var AUTOCOMPLETERS = {};

// MO's autocomplete is different.
//
// Most autocompletes make a server request whenever the input changes, and the
// server returns a small amount of data matching the string typed thus far.
// MOAutocompleter makes a request at the very first letter, and our server
// returns *the first 1000 entries* corresponding to that letter.
// MOAutocompleter stores that as an array in JS, and consults **it**, rather
// than the server, to refine the results presented.
//
// How to Use:
//   <input type="text_field" id="field"/>
//   <script>new MOAutocompleter({ input_id: "field", ... })</script>
//
// Overview:
//   1) First it creates the pulldown menu (hidden):
//        <div>                 (this is used to scroll the inner content)
//         <div>                (this is used to clip the inner content)
//          <table><tr><td>     (this is needed to allow Firefox to read off the width of the content)
//           <ul>               (this is the actual content)
//            <li>              (a fixed number of these are created and "scrolling" is simulated
//            <li>               by changing the text on these, and hiding/showing as necessary)
//            ...
//           </ul>
//          </td></tr></table>
//         </div>
//        </div>
//   2) It watches keyup/down/press and focus/blur events (on the text field):
//      * Handles cursor movement and selection on keydown.
//      * Stops propogation of tab/ret/arrows/etc. on keydown.
//      * Checks for change in text field whenever a key is released.
//      * Hides the menu when it loses focus, but it does it on a timer to allow
//       for temporary loss of focus when messing around with the pulldown menu.
//   3) Several things cause the menu to be redrawn:
//       cursor movement, any time the matches are recalculated
//      Several things cause the list of matches to be recalculated:
//       change in text field, selection of item, receipt of AJAX response
//      Two things can potentially result in AJAX request:
//       change in text field, selection of item
//   4) Summary of important events:
//       focus on text field -- switch_inputs()
//       leave text field    -- schedule_hide() -> hide_pulldown()
//       arrow keys   -- move_cursor() -> draw_pulldown()
//       click/return -- select_row() -> hide_pulldown()
//       change text  -- our_change() -> schedule_refresh()...
//       AJAX reply   -- process_ajax_response() -> schedule_refresh()...
//         ...schedule_refresh() -> refresh_options(), update_matches(), draw_pulldown()
const MOAutocompleter = function (opts) {
  // console.log(JSON.stringify(opts));
  // These are potentially useful parameters the user might want to tweak.

  const defaultOpts = {
    input_id: null,            // id of text field (after initialization becomes a unique identifier)
    input_elem: null,            // jQuery element of text field
    type: null,                  // what type of autocompleter, subclass of AutoComplete
    pulldown_class: 'auto_complete', // class of pulldown div
    hot_class: 'selected',      // class of <li> when highlighted
    unordered: false,           // ignore order of words when matching
    // (collapse must be 0 if this is true!)
    collapse: 0,               // 0 = normal mode
    // 1 = autocomplete first word, then the rest
    // 2 = autocomplete first word, then second word, then the rest
    // N = etc.
    token: null,            // separator between options
    primer: null,            // initial list of options (one string per line)
    update_primer_on_blur: false,          // add each entered value into primer (useful if auto-completing a column of fields)
    ajax_url: null,            // where to request options from
    refresh_delay: 0.10,            // how long to wait before sending AJAX request (seconds)
    hide_delay: 0.25,            // how long to wait before hiding pulldown (seconds)
    key_delay1: 0.50,            // initial key repeat delay (seconds)
    key_delay2: 0.03,            // subsequent key repeat delay (seconds)
    pulldown_size: 10,              // maximum number of options shown at a time
    page_size: 10,              // amount to move cursor on page up and down
    max_request_length: 50,              // max length of string to send via AJAX
    show_errors: false,           // show error messages returned via AJAX?
    act_like_select: false            // include pulldown-icon on right, and always show all options
  }

  // Allowed types of autocompleter
  // The type will govern the ajax_url and possibly other params
  const autocompleterTypes = {
    name: {
      ajax_url: "/ajax/auto_complete/name/@",
      collapse: 1
    },
    clade: {
      ajax_url: "/ajax/auto_complete/name_above_genus/@",
      collapse: 1
    },
    location: { // params[:format] handled in controller
      ajax_url: "/ajax/auto_complete/location/@",
      unordered: true
    },
    project: {
      ajax_url: "/ajax/auto_complete/project/@",
      unordered: true
    },
    species_list: {
      ajax_url: "/ajax/auto_complete/species_list/@",
      unordered: true
    },
    herbarium: { // params[:user_id] handled in controller
      ajax_url: "/ajax/auto_complete/herbarium/@",
      unordered: true
    },
    year: {
      // adapt date_select.js replace_date_select_with_text_field
    }
  }

  // These are internal state variables the user should leave alone.
  const internalOpts = {
    uuid: null,            // unique id for this object
    datalist_elem: null,            // jQuery element of datalist
    pulldown_elem: null,            // jQuery element of pulldown div
    list_elem: null,            // jQuery element of pulldown ul
    focused: false,           // is user in text field?
    menu_up: false,           // is pulldown visible?
    old_value: {},              // previous value of input field
    options: '',              // list of all options
    matches: [],              // list of options currently showing
    current_row: -1,              // number of option currently highlighted (0 = none)
    current_value: null,            // value currently highlighted (null = none)
    current_highlight: -1,              // row of view highlighted (-1 = none)
    current_width: 0,               // current width of menu
    scroll_offset: 0,               // scroll offset
    last_ajax_request: null,            // last ajax request we got results for
    last_ajax_incomplete: true,            // did we get all the results we requested last time?
    ajax_request: null,            // ajax request while underway
    refresh_timer: null,            // timer used to delay update after typing
    hide_timer: null,            // timer used to delay hiding of pulldown
    key_timer: null,            // timer used to emulate key repeat
    do_scrollbar: true,            // should we allow scrollbar? some browsers just can't handle it, e.g., old IE
    do_datalist: null,            // implement using <datalist> instead of doing pulldown ourselves
    row_height: null,            // height of a row in pixels (filled in automatically)
    scrollbar_width: null             // width of scrollbar (filled in automatically)
  }

  Object.assign(this, defaultOpts);
  // Assign ajax_url and a couple other options based on type.
  // Let passed options override defaults and autocompleterTypes defaults
  // Main option passed is token (item separator) via data-autocomplete-separator
  Object.assign(this, opts);

  // Get the DOM element of the input field.
  if (!this.input_elem)
    this.input_elem = document.getElementById(this.input_id);
  if (!this.input_elem)
    alert("MOAutocompleter: Invalid input id: \"" + this.input_id + "\"");

  // console.log(this.input_elem.dataset)
  this.type = this.input_elem.dataset.autocompleter;
  // Check if browser can handle doing scrollbar.
  // this.do_scrollbar = true;
  if (!autocompleterTypes.hasOwnProperty(this.type))
    alert("MOAutocompleter: Invalid type: \"" + this.type + "\"");

  Object.assign(this, autocompleterTypes[this.type]);
  Object.assign(this, internalOpts);


  // Create a unique ID for this instance.
  this.uuid = Object.keys(AUTOCOMPLETERS).length;
  this.input_elem.setAttribute("data-uuid", this.uuid);

  // Figure out a few browser-dependent dimensions.
  this.scrollbar_width = this.getScrollBarWidth();

  // Initialize autocomplete options.
  this.options = "\n" + this.primer + "\n" + this.options;

  // Create datalist if browser is capable.
  if (this.do_datalist) {
    this.create_datalist();
  } else {
    this.create_pulldown();
  }

  // Attach events, etc. to input element.
  this.prepare_input_element(this.input_elem);

  // Keep catalog of autocompleter objects so we can reuse them as needed.
  AUTOCOMPLETERS[this.uuid] = this;
}

Object.assign(MOAutocompleter.prototype, {

  // `handleEvent` is a special function name so the class itself can be a
  // designated event handler.
  // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
  handleEvent: function (event) {
    // this is bound to the class here!
    // console.log(this.name);
    switch (event.type) {
      case "focus":
        this.our_focus(event);
        break;
      case "click":
        this.our_click(event);
        break;
      case "blur":
        this.our_blur(event);
        break;
      case "keydown":
        this.our_keydown(event);
        break;
      case "keyup":
        this.our_keyup(event);
        break;
      case "change":
        this.our_change(event);
        break;
      case "beforeunload":
        this.our_unload(event);
        break;
    }
  },

  // remove_listeners: function () {
  //   this.input_elem.removeEventListener("focus", this);
  //   this.input_elem.removeEventListener("click", this);
  //   this.input_elem.removeEventListener("blur", this);
  //   this.input_elem.removeEventListener("keydown", this);
  //   this.input_elem.removeEventListener("keyup", this);
  //   this.input_elem.removeEventListener("keypress", this);
  //   this.input_elem.removeEventListener("change", this);
  //   window.removeEventListener("beforeunload", this);
  // },

  // To swap out autocompleter properties, send a type
  swap: function (type, opts) {
    if (!this.autocompleterTypes.hasOwnProperty(type)) {
      alert("MOAutocompleter: Invalid type: \"" + this.type + "\"");
    } else {
      this.type = type;
      this.input_elem.setAttribute("data-autocompleter", type)
      // add dependent properties and allow overrides
      Object.assign(this, this.autocompleterTypes[this.type]);
      Object.assign(this, opts);
      this.prepare_input_element(this.input_elem);
    }
  },

  // Prepare another input element to share an existing autocompleter instance.
  // reuse_for: function (other_elem) {
  //   console.log(this.input_id)
  //   console.log(this.ajax_url)
  //   if (typeof other_elem == "string")
  //     other_elem = getElementById(other_elem);
  //   this.switch_inputs(other_elem);
  //   console.log(this)
  //   this.prepare_input_element(this.input_elem);
  // },

  // Move/attach this autocompleter to a new field.
  // switch_inputs: function (other_elem) {
  //   // converted from jQuery input_elem.is(other_elem)
  //   console.log(this.input_elem);
  //   console.log(other_elem);
  //   console.log(this.input_elem === other_elem);

  //   if (!this.input_elem === other_elem) {
  //     this.uuid = other_elem.dataset.uuid;
  //     this.input_elem = other_elem;
  //     this.input_elem.insertAdjacentHTML("afterend", this.pulldown_elem);
  //   }
  // },

  // Prepare input element: attach elements, set properties.
  prepare_input_element: function (elem) {
    // console.log(elem)
    const id = elem.getAttribute("id");

    // NOTE: `this` within an event listener function refers to the element
    // (the eventTarget) -- unless you pass an arrow function as the listener.
    // const this2 = this;

    this.old_value[id] = null;

    // Stimulus - these can be actions on the input
    // Attach events if we aren't using datalist thingy.
    if (!this.do_datalist) {
      elem.addEventListener("focus", this);
      elem.addEventListener("click", this);
      elem.addEventListener("blur", this);
      elem.addEventListener("keydown", this);
      elem.addEventListener("keyup", this);
      elem.addEventListener("keypress", this);
      elem.addEventListener("change", this);
      // Turbo: check this. May need to be turbo.before_render or before_visit
      window.addEventListener("beforeunload", this);
    }

    // Disable default browser autocomplete. Stimulus - do this on HTML element
    elem.setAttribute("autocomplete", "off");
    // sanity check to show which autocompleter is currently on the element
    elem.setAttribute("data-ajax-url", this.ajax_url);
  },

  // ------------------------------ Events ------------------------------

  // User pressed a key in the text field.
  our_keydown: function (event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    // this.debug("keydown(" + key + ")");
    this.clear_key();
    this.focused = true;
    if (this.menu_up) {
      switch (key) {
        case EVENT_KEY_ESC:
          this.schedule_hide();
          this.menu_up = false;
          break;
        case EVENT_KEY_RETURN:
        case EVENT_KEY_TAB:
          if (this.current_row >= 0)
            this.select_row(this.current_row - this.scroll_offset);
          break;
        case EVENT_KEY_HOME:
          this.go_home();
          break;
        case EVENT_KEY_END:
          this.go_end();
          break;
        case EVENT_KEY_PAGEUP:
          this.page_up();
          this.schedule_key(this.page_up);
          break;
        case EVENT_KEY_UP:
          this.arrow_up();
          this.schedule_key(this.arrow_up);
          break;
        case EVENT_KEY_DOWN:
          this.arrow_down();
          this.schedule_key(this.arrow_down);
          break;
        case EVENT_KEY_PAGEDOWN:
          this.page_down();
          this.schedule_key(this.page_down);
          break;
        default:
          this.current_row = -1;
          break;
      }
    }
    if (this.menu_up && this.is_hot_key(key) &&
      !(key == EVENT_KEY_TAB || this.current_row < 0))
      return false;
    return true;
  },

  // Need to prevent these keys from being processed by form.
  our_keypress: function (event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    // this.debug("keypress(key=" + key + ", menu_up=" + this.menu_up + ", hot=" + this.is_hot_key(key) + ")");
    if (this.menu_up && this.is_hot_key(key) &&
      !(key == EVENT_KEY_TAB || this.current_row < 0))
      return false;
    return true;
  },

  // User has released a key.
  our_keyup: function (event) {
    // this.debug("keyup()");
    this.clear_key();
    this.our_change(true);
    return true;
  },

  // Input field has changed.
  our_change: function (do_refresh) {
    const old_val = this.old_value[this.uuid];
    const new_val = this.input_elem.value;
    // this.debug("our_change(" + this.input_elem.value + ")");
    if (new_val != old_val) {
      this.old_value[this.uuid] = new_val;
      if (do_refresh)
        this.schedule_refresh();
    }
  },

  // User clicked into text field.
  our_click: function (event) {
    if (this.act_like_select)
      this.schedule_refresh();
    return false;
  },

  // User entered text field.
  our_focus: function (event) {
    // this.debug("our_focus()");
    if (!this.row_height)
      this.get_row_height();
    this.focused = true;
  },

  // User left the text field.
  our_blur: function (event) {
    // this.debug("our_blur()");
    this.schedule_hide();
    this.focused = false;
  },

  // User has navigated away from page.
  our_unload: function () {
    // If native browser autocomplete is turned off, browsers like chrome
    // and firefox will not remember the value of fields when you go back.
    // This hack re-enables native autocomplete before leaving the page.
    // [This only works for firefox; should work for chrome but doesn't.]
    this.input_elem.setAttribute("autocomplete", "on");
    return false;
  },

  // Prevent these keys from propagating to the input field.
  is_hot_key: function (key) {
    switch (key) {
      case EVENT_KEY_ESC:
      case EVENT_KEY_RETURN:
      case EVENT_KEY_TAB:
      case EVENT_KEY_UP:
      case EVENT_KEY_DOWN:
      case EVENT_KEY_PAGEUP:
      case EVENT_KEY_PAGEDOWN:
      case EVENT_KEY_HOME:
      case EVENT_KEY_END:
        return true;
    }
    return false;
  },

  // ------------------------------ Timers ------------------------------

  // Schedule options to be refreshed after polite delay.
  schedule_refresh: function () {
    this.verbose("schedule_refresh()");
    this.clear_refresh();
    this.refresh_timer = setTimeout((function () {
      this.verbose("doing_refresh()");
      // this.debug("refresh_timer(" + this.input_elem.value + ")");
      this.old_value[this.uuid] = this.input_elem.value;
      if (this.ajax_url)
        this.refresh_options();
      this.update_matches();
      if (this.do_datalist)
        this.update_datalist();
      else
        this.draw_pulldown();
    }).bind(this), this.refresh_delay * 1000);
  },

  // Schedule pulldown to be hidden if nothing happens in the meantime.
  schedule_hide: function () {
    this.clear_hide();
    this.hide_timer = setTimeout(this.hide_pulldown.bind(this), this.hide_delay * 1000);
    if (this.update_primer_on_blur)
      this.update_primer();
  },

  // Schedule a method to be called after key stays pressed for some time.
  schedule_key: function (action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.schedule_key2(action);
    }).bind(this), this.key_delay1 * 1000);
  },
  schedule_key2: function (action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.schedule_key2(action);
    }).bind(this), this.key_delay2 * 1000);
  },

  // Clear refresh timer.
  clear_refresh: function () {
    if (this.refresh_timer) {
      clearTimeout(this.refresh_timer);
      this.refresh_timer = null;
    }
  },

  // Clear hide timer.
  clear_hide: function () {
    if (this.hide_timer) {
      clearTimeout(this.hide_timer);
      this.hide_timer = null;
    }
  },

  // Clear key timer.
  clear_key: function () {
    if (this.key_timer) {
      clearTimeout(this.key_timer);
      this.key_timer = null;
    }
  },

  // ------------------------------ Cursor ------------------------------

  // Move cursor up or down some number of rows.
  page_up: function () { this.move_cursor(-this.page_size); },
  page_down: function () { this.move_cursor(this.page_size); },
  arrow_up: function () { this.move_cursor(-1); },
  arrow_down: function () { this.move_cursor(1); },
  go_home: function () { this.move_cursor(-this.matches.length) },
  go_end: function () { this.move_cursor(this.matches.length) },
  move_cursor: function (rows) {
    this.verbose("move_cursor()");
    const old_row = this.current_row;
    let new_row = old_row + rows;
    const old_scr = this.scroll_offset;
    let new_scr = old_scr;

    // Move cursor, but keep in bounds.
    if (new_row < 0)
      new_row = old_row < 0 ? -1 : 0;
    if (new_row >= this.matches.length)
      new_row = this.matches.length - 1;
    this.current_row = new_row;
    this.current_value = new_row < 0 ? null : this.matches[new_row];

    // Scroll view so new row is visible.
    if (new_row < new_scr)
      new_scr = new_row;
    if (new_scr < 0)
      new_scr = 0;
    if (new_row >= new_scr + this.pulldown_size)
      new_scr = new_row - this.pulldown_size + 1;

    // Update if something changed.
    if (new_row != old_row || new_scr != old_scr) {
      this.scroll_offset = new_scr;
      this.draw_pulldown();
    }
  },

  // Mouse has moved over a menu item.
  highlight_row: function (new_hl) {
    this.verbose("highlight_row()");
    const rows = this.list_elem.children;
    const old_hl = this.current_highlight;
    this.current_highlight = new_hl;
    this.current_row = this.scroll_offset + new_hl;
    if (old_hl != new_hl) {
      if (old_hl >= 0)
        rows[old_hl].classList.remove(this.hot_class);
      if (new_hl >= 0)
        rows[new_hl].classList.add(this.hot_class);
    }
    this.input_elem.focus();
    this.update_width();
  },

  // Called when users scrolls via scrollbar.
  our_scroll: function () {
    this.verbose("our_scroll()");
    const old_scr = this.scroll_offset;
    const new_scr = Math.round(this.pulldown_elem.scrollTop / this.row_height);
    const old_row = this.current_row;
    const new_row = this.current_row;
    if (new_row < new_scr)
      new_row = new_scr;
    if (new_row >= new_scr + this.pulldown_size)
      new_row = new_scr + this.pulldown_size - 1;
    if (new_row != old_row || new_scr != old_scr) {
      this.current_row = new_row;
      this.scroll_offset = new_scr;
      this.draw_pulldown();
    }
  },

  // User has selected a value, either pressing tab/return or clicking on an option.
  select_row: function (row) {
    this.verbose("select_row()");
    // const old_val = this.input_elem.value;
    let new_val = this.matches[this.scroll_offset + row];
    // Close pulldown unless the value the user selected uncollapses into a set
    // of new options.  In that case schedule a refresh and leave it up.
    if (this.collapse > 0 &&
      (new_val.match(/ /g) || []).length < this.collapse) {
      new_val += ' ';
      this.schedule_refresh();
    } else {
      this.schedule_hide();
    }
    this.input_elem.focus();
    this.focused = true;
    this.set_token(new_val);
    this.our_change(false);
  },

  // ------------------------------ Pulldown ------------------------------

  // Stimulus: put this in template instead of adding it here, then just modify
  // Create div for pulldown.
  create_pulldown: function () {
    const div = document.createElement("div");
    div.innerHTML = "<div><ul></ul></div>"
    const list = div.querySelector('ul');
    let i, row;
    div.classList.add(this.pulldown_class);
    for (i = 0; i < this.pulldown_size; i++) {
      row = document.createElement("li");
      row.style.display = 'none';
      this.attach_row_events(row, i);
      list.append(row);
    }
    // if (this.do_scrollbar)
    div.addEventListener("scroll", this.our_scroll.bind(this));
    this.input_elem.insertAdjacentElement("afterend", div);
    this.pulldown_elem = div;
    this.list_elem = list;
  },

  // Add "click" and "mouseover" events to a row of the pulldown menu.
  // Need to do this in a separate method, otherwise row doesn't get
  // a separate value for each row!  Something to do with scope of
  // variables inside for loops.
  attach_row_events: function (e, row) {
    e.addEventListener("click", (function () {
      this.select_row(row);
    }).bind(this));
    e.addEventListener("mouseover", (function () {
      this.highlight_row(row);
    }).bind(this));
  },

  // Stimulus: print this in the document already
  // Get actual row height when it becomes available.
  // Experimentally creates a test row.
  get_row_height: function () {
    const div = document.createElement('div');
    const ul = document.createElement('ul');
    const li = document.createElement('li');
    const body = document.body || document.getElementsByTagName("body")[0];
    div.className = this.pulldown_class;
    div.style.display = 'block';
    div.style.border = div.style.margin = div.style.padding = '0px';
    li.innerHTML = 'test';
    ul.appendChild(li);
    div.appendChild(ul);
    body.appendChild(div);
    this.temp_row = div;
    setTimeout(this.set_row_height.bind(this), 100);
  },
  set_row_height: function () {
    if (this.temp_row) {
      this.row_height = this.temp_row.offsetHeight;
      if (!this.row_height) {
        setTimeout(this.set_row_height.bind(this), 100);
      } else {
        document.body.removeChild(this.temp_row);
        this.temp_row = null;
      }
    }
  },

  // Redraw the pulldown options.
  draw_pulldown: function () {
    this.verbose("draw_pulldown()");
    const menu = this.pulldown_elem;
    const inner = menu.children[0];
    const list = this.list_elem;
    const rows = list.children;
    const size = this.pulldown_size;
    const scroll = this.scroll_offset;
    const cur = this.current_row;
    const matches = this.matches;
    const old_hl = this.current_highlight;
    let new_hl = 0;
    let i, x, y;

    if (this.log) {
      this.debug(
        "Redraw: matches=" + matches.length +
        ", scroll=" + scroll + ", cursor=" + cur
      );
    }

    // Get row height if haven't been able to yet.
    this.set_row_height();
    // console.log(rows)

    // Update menu text first.
    for (i = 0; i < size; i++) {
      let row = rows.item(i);
      x = row.innerHTML;
      if (i + scroll < matches.length) {
        y = this.escapeHTML(matches[i + scroll]);
        if (x != y) {
          if (x == '')
            row.style.display = 'block';
          row.innerHTML = y;
        }
      } else {
        if (x != '') {
          row.innerHTML = '';
          row.style.display = 'none';
        }
      }
    }

    // Highlight that row.
    new_hl = cur - scroll;
    if (new_hl < 0 || new_hl >= size)
      new_hl = -1;
    this.current_highlight = new_hl;
    if (new_hl != old_hl) {
      if (old_hl >= 0)
        rows[old_hl].classList.remove(this.hot_class);
      if (new_hl >= 0)
        rows[new_hl].classList.add(this.hot_class);
    }

    // Make menu visible if nonempty.
    if (matches.length > 0) {
      const top = this.input_elem.offsetTop;
      const left = this.input_elem.offsetLeft;
      const hgt = this.input_elem.offsetHeight;
      const scr = this.input_elem.scrollTop;
      menu.style.top = (top + hgt + scr) + "px";
      menu.style.left = left + "px";

      // Set height of menu.
      // if (this.do_scrollbar) {
      menu.style.overflowY = matches.length > size ? "scroll" : "hidden";
      menu.style.height = this.row_height * (size < matches.length - scroll ? size : matches.length - scroll) + "px";
      inner.style.marginTop = this.row_height * scroll + "px";
      inner.style.height = this.row_height * (matches.length - scroll) + "px";
      menu.scrollTo({ top: this.row_height * scroll });
      // }

      // Set width of menu.
      this.set_width();
      this.update_width();

      // Only show menu if it is nontrivial, i.e., show an option other than
      // the value that's already in the text field.
      if (matches.length > 1 || this.input_elem.value != matches[0]) {
        this.clear_hide();
        menu.style.display = 'block';
        this.menu_up = true;
      } else {
        menu.style.display = 'none';
        this.menu_up = false;
      }
    }

    // Hide the menu if it's empty now.
    else {
      menu.style.display = 'none';
      this.menu_up = false;
    }

    // Make sure input focus stays on text field!
    this.input_elem.focus();
  },

  // Hide pulldown options.
  hide_pulldown: function () {
    this.verbose("hide_pulldown()");
    this.pulldown_elem.style.display = 'none';
    this.menu_up = false;
  },

  // Update width of pulldown.
  update_width: function () {
    this.verbose("update_width()");
    let w = this.list_elem.offsetWidth;
    if (this.matches.length > this.pulldown_size)
      w += this.scrollbar_width;
    if (this.current_width < w) {
      this.current_width = w;
      this.set_width();
    }
  },

  // Set width of pulldown.
  set_width: function () {
    this.verbose("set_width()");
    const w1 = this.current_width;
    let w2 = w1;
    if (this.matches.length > this.pulldown_size)
      w2 -= this.scrollbar_width;
    this.list_elem.style.minWidth = w2 + 'px';
  },

  // ------------------------------ Datalist ------------------------------

  // This is a fancy new feature in HTML 5.  You can supply a list of
  // acceptable values to a textfield via a <datalist> object:
  //
  //   <input type="textfield" list="possible_values"/>
  //   <datalist id="possible_values">
  //     <option>value one</option>
  //     <option>value two</option>
  //     ...
  //   </datalist>
  //
  // In theory this should be much more efficient than doing it ourselves.
  // But for now, I have no pressing reason to bother, since browsers
  // capable of doing this are also more than capable of handling the old
  // dynamic popup pulldown menu.

  create_datalist: function () {
    // XXX Create (empty) datalist element with specific id, then attach that to the input field.
  },

  update_datalist: function () {
    // XXX Update the list of children (<option> elements) inside the datalist.
  },

  // ------------------------------ Matches ------------------------------

  // Update content of pulldown.
  update_matches: function () {
    this.verbose("update_matches()");

    // Remember which option used to be highlighted.
    const last = this.current_row < 0 ? null : this.matches[this.current_row];

    // Update list of options appropriately.
    if (this.act_like_select)
      this.update_select();
    else if (this.collapse > 0)
      this.update_collapsed();
    else if (this.unordered)
      this.update_unordered();
    else
      this.update_normal();

    // Sort and remove duplicates.
    this.matches = this.remove_dups(this.matches.sort());

    // Try to find old highlighted row in new set of options.
    this.update_current_row(last);

    // Reset width each time we change the options.
    this.current_width = this.input_elem.offsetWidth;
  },

  // When "acting like a select" make it display all options in the
  // order given right from the moment they enter the field.
  update_select: function () {
    this.matches = this.primer.split("\n");
  },

  // Grab all matches, doing exact match, ignoring number of words.
  update_normal: function () {
    const val = this.get_token().toLowerCase().normalize();
    const options = this.options.normalize();
    const matches = [];
    if (val != '') {
      let i, j, s;
      for (i = options.indexOf("\n"); i >= 0; i = j) {
        j = options.indexOf("\n", i + 1);
        s = options.substring(i + 1, j > 0 ? j : options.length);
        if (s.length > 0 && s.toLowerCase().indexOf(val) >= 0) {
          matches.push(s);
          if (matches.length >= this.max_matches)
            break;
        }
      }
    }
    this.matches = matches;
  },

  // Grab matches ignoring order of words.
  update_unordered: function () {
    const val = this.get_token().normalize().toLowerCase().
      replace(/^ */, '').replace(/  +/g, ' ');
    const vals = val.split(' ');
    const options = this.options.normalize();
    const matches = [];
    if (val != '') {
      let i, j, k, s, s2;
      for (i = options.indexOf("\n"); i >= 0; i = j) {
        j = options.indexOf("\n", i + 1);
        s = options.substring(i + 1, j > 0 ? j : options.length);
        s2 = ' ' + s.toLowerCase() + ' ';
        for (k = 0; k < vals.length; k++) {
          if (s2.indexOf(' ' + vals[k]) < 0) break;
        }
        if (k >= vals.length) {
          matches.push(s);
          if (matches.length >= this.max_matches)
            break;
        }
      }
    }
    this.matches = matches;
  },

  // Grab all matches, preferring the ones with no additional words.
  // Note: order of options must have genera first, then species, then varieties.
  update_collapsed: function () {
    const val = "\n" + this.get_token().toLowerCase();
    const options = this.options;
    const options2 = this.options.toLowerCase();
    const matches = [];
    if (val != "\n") {
      let the_rest = (val.match(/ /g) || []).length >= this.collapse;
      for (let i = options2.indexOf(val); i >= 0;
        i = options2.indexOf(val, i + 1)) {
        let j = options.indexOf("\n", i + 1);
        let s = options.substring(i + 1, j > 0 ? j : options.length);
        if (s.length > 0) {
          if (the_rest || s.indexOf(' ', val.length - 1) < val.length - 1) {
            matches.push(s);
            if (matches.length >= this.max_matches)
              break;
          } else if (matches.length > 1) {
            break;
          } else {
            if ("\n" + matches[0] == val)
              matches.pop();
            matches.push(s);
            if (matches.length >= this.max_matches)
              break;
            the_rest = true;
          }
        }
      }
      if (matches.length == 1 &&
        (val == "\n" + matches[0].toLowerCase() ||
          val == "\n" + matches[0].toLowerCase() + " "))
        matches.pop();
    }
    this.matches = matches;
  },

  // Remove duplicates from a sorted array.
  remove_dups: function (list) {
    let i, j;
    for (i = 0, j = 1; j < list.length; j++) {
      if (list[j] != list[i])
        list[++i] = list[j];
    }
    if (++i < list.length)
      list.splice(i, list.length - i);
    return list;
  },

  // Look for 'val' in list of matches and highlight it, otherwise highlight first.
  update_current_row: function (val) {
    this.verbose("update_current_row()");
    const matches = this.matches;
    const size = this.pulldown_size;
    let exact = -1;
    let part = -1;
    let new_scr, new_row, i;
    if (val && val.length > 0) {
      for (i = 0; i < matches.length; i++) {
        if (matches[i] == val) {
          exact = i;
          break;
        }
        if (matches[i] == val.substr(0, matches[i].length) &&
          (part < 0 || matches[i].length > matches[part].length))
          part = i;
      }
    }
    new_row = exact >= 0 ? exact : part >= 0 ? part : -1;
    new_scr = this.scroll_offset;
    if (new_scr > new_row)
      new_scr = new_row;
    if (new_scr > matches.length - size)
      new_scr = matches.length - size;
    if (new_scr < new_row - size + 1)
      new_scr = new_row - size + 1;
    if (new_scr < 0)
      new_scr = 0;
    this.current_row = new_row;
    this.scroll_offset = new_scr;
  },

  // ------------------------------ AJAX ------------------------------

  // Send request for updated options.
  refresh_options: function () {
    this.verbose("refresh_options()");
    let val = this.get_token().toLowerCase();
    // const url;

    // Don't make request on empty string!
    if (!val || val.length < 1)
      return;

    // Don't repeat last request accidentally!
    if (this.last_ajax_request == val)
      return;

    // There is no need to make a more constrained request if got all results last time.
    if (this.last_ajax_request &&
      this.last_ajax_request.length > 0 &&
      !this.last_ajax_incomplete &&
      this.last_ajax_request.length < val.length &&
      this.last_ajax_request == val.substr(0, this.last_ajax_request.length))
      return;

    // If a less constrained request is pending, wait for it to return before refining
    // the request, just in case it returns complete results (rendering the more
    // refined request unnecessary).
    if (this.ajax_request &&
      this.last_ajax_request.length < val.length &&
      this.last_ajax_request == val.substr(0, this.last_ajax_request.length))
      return;

    // Make request.
    this.send_ajax_request(val);
  },

  // Send AJAX request for more matching strings.
  send_ajax_request: function (val) {
    this.verbose("send_ajax_request()");
    if (val.length > this.max_request_length)
      val = val.substr(0, this.max_request_length);

    if (this.log) {
      this.debug("Sending AJAX request: " + val);
    }

    // Need to doubly-encode this to prevent router from interpreting slashes, dots, etc.
    url = this.ajax_url.replace(
      '@', encodeURIComponent(encodeURIComponent(val.replace(/\./g, '%2e')))
    );

    this.last_ajax_request = val;

    const controller = new AbortController();
    const signal = controller.signal;

    if (this.ajax_request)
      controller.abort();

    const csrfToken = document.getElementsByName('csrf-token')[0].content

    // this.ajax_request = jQuery.ajax(url, {
    //   data: { authenticity_token: csrfToken },
    //   dataType: "text",
    //   async: true,
    //   error: (function (response) {
    //     this.ajax_request = null;
    //     if (this.show_errors)
    //       alert(response.responseText);
    //   }).bind(this),
    //   success: (function (text) {
    //     this.process_ajax_response(text);
    //   }).bind(this)
    // });

    this.ajax_request = fetch(url, {
      method: 'GET',
      headers: {
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'text/html',
        'Accept': 'text/html'
      },
      credentials: 'same-origin',
      signal
    }).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.text().then((content) => {
            // console.log("content: " + content);
            // do something awesome with result
            this.process_ajax_response(content)
          }).catch((error) => {
            console.error("no_content:", error);
          });
        } else {
          this.ajax_request = null;
          console.log(`got a ${response.status}`);
        }
      }
    }).catch((error) => {
      console.error("Server Error:", error);
    });
  },


  // Process response from server:
  // 1. first line is string actually used to match;
  // 2. the last string is "..." if the set of results is incomplete;
  // 3. the rest are matching results.
  process_ajax_response: function (response) {
    this.verbose("process_ajax_response()");
    let new_opts, i;

    // Clear flag telling us request is pending.
    this.ajax_request = null;

    // Grab list of matching strings.
    i = response.indexOf("\n");
    new_opts = response.substring(i);

    // Record string actually used to do matching: might be less strict
    // than one sent in request.
    this.last_ajax_request = response.substr(0, i);

    // Make sure there's a trailing newline.
    if (new_opts.charAt(new_opts.length - 1) != "\n")
      new_opts += "\n";

    // Check for trailing "..." signaling incomplete set of results.
    if (new_opts.substr(new_opts.length - 5, 5) == "\n...\n") {
      this.last_ajax_incomplete = true;
      new_opts = new_opts.substr(0, new_opts.length - 4);
      if (this.focused)
        this.schedule_refresh(); // (just in case we need to refine the request due to activity while waiting for this response)
    } else {
      this.last_ajax_incomplete = false;
    }

    // Log requests and responses if in debug mode.
    if (this.log) {
      this.debug("Got response for " + this.escapeHTML(this.last_ajax_request) +
        ": " + (new_opts.split("\n").length - 2) + " strings (" +
        (this.last_ajax_incomplete ? "incomplete" : "complete") + ").");
    }

    // Tack on primer if available.
    if (this.primer)
      new_opts = "\n" + this.primer + new_opts;

    // Update menu if anything has changed.
    if (this.options != new_opts && this.focused) {
      this.options = new_opts;
      this.update_matches();
      if (this.do_datalist)
        this.update_datalist();
      else
        this.draw_pulldown();
    }
  },

  // ------------------------------ Tokens ------------------------------

  // Get token under or immediately in front of cursor.
  get_token: function () {
    let val = this.input_elem.value;
    if (this.token) {
      let token = this.token_extents();
      val = val.substring(token.start, token.end);
    }
    return val;
  },

  // Change the token under or immediately in front of the cursor.
  set_token: function (new_val) {
    const old_str = this.input_elem.value;
    if (this.token) {
      let new_str = "";
      const token = this.token_extents();
      if (token.start > 0)
        new_str += old_str.substring(0, token.start);
      new_str += new_val;
      if (token.end < old_str.length)
        new_str += old_str.substring(token.end);
      if (old_str != new_str) {
        const old_scroll = this.input_elem.scrollTop;
        this.input_elem.value = new_str;
        this.setCursorPosition(this.input_elem[0], token.start + new_val.length);
        this.input_elem.scrollTo({ top: old_scroll });
      }
    } else {
      if (old_str != new_val)
        this.input_elem.value = new_val;
    }
  },

  // Get index of first character and character after last of current token.
  token_extents: function () {
    let start, end, sel = this.getInputSelection(this.input_elem[0]);
    const val = this.input_elem.value;
    if (sel.start > 0)
      start = val.lastIndexOf(this.token, sel.start - 1);
    else
      start = 0;
    if (start < 0)
      start = 0;
    else
      start += this.token.length;
    end = val.indexOf(this.token, start);
    if (end <= start || end > sel.length)
      end = sel.len;
    return { start: start, end: end };
  },

  // ------------------------------ Primer ------------------------------

  update_primer: function () {
    const val = this.input_elem.value.replace(/^\s+/, '').replace(/\s+$/, '');
    if (val == "") return;
    const primer = this.primer;
    if (!primer)
      this.primer = primer = "";
    let j, s;
    for (let i = primer.indexOf("\n"); i >= 0; i = j) {
      j = primer.indexOf("\n", i + 1);
      s = primer.substring(i + 1, j > 0 ? j : primer.length);
      if (s == val)
        return;
    }
    this.primer += "\n" + val;
    this.options += "\n" + val;
  },

  // ------------------------------ Input ------------------------------
  // written by Tim Down
  // http://stackoverflow.com/questions/3053542/how-to-get-the-start-and-end-points-of-selection-in-text-area/3053640#3053640

  getInputSelection: function (el) {
    let start, end, len, normalizedValue, range, textInputRange, endRange;
    start = end = len = el.value.length;

    if (typeof el.selectionStart == "number" && typeof el.selectionEnd == "number") {
      start = el.selectionStart;
      end = el.selectionEnd;
    } else {
      range = document.selection.createRange();

      if (range && range.parentElement == el) {
        normalizedValue = el.value.replace(/\r\n/g, "\n");

        // Create a working TextRange that lives only in the input
        textInputRange = el.createTextRange();
        textInputRange.moveToBookmark(range.getBookmark());

        // Check if the start and end of the selection are at the very end
        // of the input, since moveStart/moveEnd doesn't return what we want
        // in those cases
        endRange = el.createTextRange();
        endRange.collapse(false);

        if (textInputRange.compareEndPoints("StartToEnd", endRange) > -1) {
          start = end = len;
        } else {
          start = -textInputRange.moveStart("character", -len);
          start += normalizedValue.slice(0, start).split("\n").length - 1;

          if (textInputRange.compareEndPoints("EndToEnd", endRange) > -1) {
            end = len;
          } else {
            end = -textInputRange.moveEnd("character", -len);
            end += normalizedValue.slice(0, end).split("\n").length - 1;
          }
        }
      }
    }

    return {
      start: start,
      end: end,
      len: len
    };
  },

  setCursorPosition: function (el, pos) {
    if (el.setSelectionRange) {
      el.setSelectionRange(pos, pos);
    } else if (el.createTextRange) {
      const range = el.createTextRange();
      range.collapse(true);
      range.moveEnd('character', pos);
      range.moveStart('character', pos);
      range.select();
    }
  },

  // ------------------------------- DEBUGGING ------------------------------

  debug: function (str) {
    document.getElementById("log").insertAdjacentText("beforeend", str + "<br/>");
  },

  verbose: function (str) {
    // console.log(str);
    // document.getElementById("log").insertAdjacentText("beforeend", str + "<br/>");
  },

  // ------------------------------- UTILITIES ------------------------------

  // These methods are also used in name_lister.js
  // Stimulus: May want to make a shared module
  escapeHTML: function (str) {
    const HTML_ENTITY_MAP = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': '&quot;',
      "'": '&#39;',
      "/": '&#x2F;'
    };

    return str.replace(/[&<>"'\/]/g, function (s) {
      return HTML_ENTITY_MAP[s];
    });
  },

  getScrollBarWidth: function () {
    var inner, outer, w1, w2;
    var body = document.body || document.getElementsByTagName("body")[0];

    if (scroll_bar_width != null)
      return scroll_bar_width;

    var inner = document.createElement('p');
    inner.style.width = "100%";
    inner.style.height = "200px";

    var outer = document.createElement('div');
    outer.style.position = "absolute";
    outer.style.top = "0px";
    outer.style.left = "0px";
    outer.style.visibility = "hidden";
    outer.style.width = "200px";
    outer.style.height = "150px";
    outer.style.overflow = "hidden";
    outer.appendChild(inner);

    body.appendChild(outer);
    var w1 = inner.offsetWidth;
    outer.style.overflow = 'scroll';
    var w2 = inner.offsetWidth;
    if (w1 == w2) w2 = outer.clientWidth;
    body.removeChild(outer);

    scroll_bar_width = w1 - w2;
    return scroll_bar_width;
  }
});

