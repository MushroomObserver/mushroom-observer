var AUTOCOMPLETERS = {};

// MO's autocompleter is different.
//
// Most autocompleters make a server request whenever the input changes, and the
// server returns a small amount of data matching the string typed thus far.
//
// MOAutocompleter makes a request at the very first letter, and our server
// returns *the first 1000 entries* corresponding to that letter.
// MOAutocompleter stores that as an array in JS, and consults this `primer`,
// rather than the server, to refine the results presented.
//
// Code convention note: this is a JS `class` not a `module` here because
// autocompleters may be instantiated multiple times on the same page.
// https://dev.to/giantmachines/stop-using-javascript-classes-33ij
//
// How to Use:
//   <input type="text_field" id="field" data-autocompleter="name"/>
//   (the field is initialized by a DOM observer in main.js that calls this
//    when it notices a field with `data-autocompleter` has been loaded:)
//        new MOAutocompleter({ input_id: "field", ... }
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
//       AJAX reply   -- process_fetch_response() -> schedule_refresh()...
//         ...schedule_refresh() -> refresh_primer(), update_matches(), draw_pulldown()

class MOAutocompleter {
  constructor(opts = {}) {
    // console.log(JSON.stringify(opts));
    // These are potentially useful parameters the user might want to tweak.
    const defaultOpts = {
      // id of text field (after initialization becomes a unique identifier)
      input_id: null,
      // JS element of text field
      input_elem: null,
      // what type of autocompleter, subclass of AutoComplete
      type: null,
      // class of pulldown div
      pulldown_class: 'auto_complete',
      // class of <li> when highlighted
      hot_class: 'selected',
      // ignore order of words when matching
      // (collapse must be 0 if this is true!)
      unordered: false,
      // 0 = normal mode
      // 1 = autocomplete first word, then the rest
      // 2 = autocomplete first word, then second word, then the rest
      // N = etc.
      collapse: 0,
      // where to request primer from
      ajax_url: null,
      // how long to wait before sending AJAX request (seconds)
      refresh_delay: 0.10,
      // how long to wait before hiding pulldown (seconds)
      hide_delay: 0.25,
      // initial key repeat delay (seconds)
      key_delay1: 0.50,
      // subsequent key repeat delay (seconds)
      key_delay2: 0.03,
      // maximum number of options shown at a time
      pulldown_size: 10,
      // amount to move cursor on page up and down
      page_size: 10,
      // max length of string to send via AJAX
      max_request_length: 50,
      // show error messages returned via AJAX?
      show_errors: false,
      // include pulldown-icon on right, and always show all options
      act_like_select: false
    }

    // Allowed types of autocompleter
    // The type will govern the ajax_url and possibly other params
    const autocompleterTypes = {
      clade: {
        ajax_url: "/ajax/auto_complete/clade/@",
        collapse: 1
      },
      herbarium: { // params[:user_id] handled in controller
        ajax_url: "/ajax/auto_complete/herbarium/@",
        unordered: true
      },
      location: { // params[:format] handled in controller
        ajax_url: "/ajax/auto_complete/location/@",
        unordered: true
      },
      name: {
        ajax_url: "/ajax/auto_complete/name/@",
        collapse: 1
      },
      project: {
        ajax_url: "/ajax/auto_complete/project/@",
        unordered: true
      },
      species_list: {
        ajax_url: "/ajax/auto_complete/species_list/@",
        unordered: true
      },
      user: {
        ajax_url: "/ajax/auto_complete/user/@",
        unordered: true
      },
      year: {
        // adapt date_select.js replace_date_select_with_text_field
        pulldown_size: length,
        act_like_select: true
      }
    }

    // These are internal state variables the user should leave alone.
    const internalOpts = {
      uuid: null,            // unique id for this object
      pulldown_elem: null,   // DOM element of pulldown div
      list_elem: null,       // DOM element of pulldown ul
      focused: false,        // is user in text field?
      menu_up: false,        // is pulldown visible?
      old_value: {},         // previous value of input field
      primer: [],            // initial server-supplied list of many options
      matches: [],           // list of options currently showing
      current_row: -1,       // index of option currently highlighted (0 = none)
      current_value: null,   // value currently highlighted (null = none)
      current_highlight: -1, // row of view highlighted (-1 = none)
      current_width: 0,      // current width of menu
      scroll_offset: 0,      // scroll offset
      last_fetch_request: null, // last fetch request we got results for
      last_fetch_incomplete: true, // did we get all the results we requested?
      fetch_request: null,    // ajax request while underway
      refresh_timer: null,   // timer used to delay update after typing
      hide_timer: null,      // timer used to delay hiding of pulldown
      key_timer: null,       // timer used to emulate key repeat
      row_height: null,      // height of a row in pixels (determined below)
      scrollbar_width: null  // width of scrollbar (determined below)
    }

    Object.assign(this, defaultOpts);
    // Assign ajax_url and a couple other options based on type.
    // Let passed options override defaults and autocompleterTypes defaults
    Object.assign(this, opts);

    // Get the DOM element of the input field.
    if (!this.input_elem)
      this.input_elem = document.getElementById(this.input_id);
    if (!this.input_elem)
      alert("MOAutocompleter: Invalid input id: \"" + this.input_id + "\"");

    // Check the type of autocompleter set on the input element
    this.type = this.input_elem.dataset.autocompleter;
    if (!autocompleterTypes.hasOwnProperty(this.type))
      alert("MOAutocompleter: Invalid type: \"" + this.type + "\"");

    Object.assign(this, autocompleterTypes[this.type]);
    Object.assign(this, internalOpts);

    // not sure how else to make this available here
    this.autocompleterTypes = autocompleterTypes;

    // Create a unique ID for this instance.
    this.uuid = Object.keys(AUTOCOMPLETERS).length;
    this.input_elem.setAttribute("data-uuid", this.uuid);

    // Figure out a few browser-dependent dimensions.
    this.scrollbar_width = this.getScrollBarWidth();

    // Initialize autocomplete primer with a blank newline.
    this.primer.unshift('\n');

    // Create pulldown.
    this.create_pulldown();

    // Attach events, etc. to input element.
    if (this.type == "year") {
      this.prepare_year_input_element(this.input_elem)
    } else {
      this.prepare_input_element(this.input_elem);
    }

    // Keep catalog of autocompleter objects so we can reuse them as needed.
    AUTOCOMPLETERS[this.uuid] = this;
  }

  // To swap out autocompleter properties, send a type
  swap(type, opts) {
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
  }

  // Prepare input element: attach elements, set properties.
  prepare_input_element(elem) {
    // console.log(elem)
    const id = elem.getAttribute("id");

    this.old_value[id] = null;

    // Attach events
    this.add_event_listeners(elem);

    // sanity check to show which autocompleter is currently on the element
    elem.setAttribute("data-ajax-url", this.ajax_url);
  }

  // This turns the Rails date selects into text inputs.
  prepare_year_input_element(old_elem) {
    const id = old_elem.getAttribute("id"),
      name = old_elem.getAttribute("name"),
      classList = old_elem.classList,
      style = old_elem.getAttribute("style"),
      value = old_elem.value,
      opts = old_elem.options,
      primer = [],
      new_elem = document.createElement("input");
    new_elem.type = "text";
    const length = opts.length > 20 ? 20 : opts.length;

    for (let i = 0; i < opts.length; i++)
      primer.push(opts.item(i).text);

    new_elem.classList = classList;
    new_elem.style = style;
    new_elem.value = value;
    new_elem.setAttribute("size", 4);

    // Not sure if this works yet...
    if (old_elem[0].onchange)
      new_elem.onchange = old_elem[0].onchange;

    old_elem.replaceWith(new_elem);
    new_elem.setAttribute("id", id);
    new_elem.setAttribute("name", name);

    this.input_elem = new_elem,
      this.primer = primer,
      this.pulldown_size = length,
      this.act_like_select = true

    this.add_event_listeners(new_elem);
  }

  // NOTE: `this` within an event listener function refers to the element
  // (the eventTarget) -- unless you pass an arrow function as the listener.
  // But writing a specially named function handleEvent() allows this:
  add_event_listeners(elem) {
    // Stimulus - data-actions on the input can route events to actions here
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

  // In a JS class, `handleEvent` is a special function name. If it has this
  // function, you can designate the class itself as the handler for multiple
  // events. Stimulus uses `handleEvent` under the hood.
  // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
  handleEvent(event) {
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
  }

  // ------------------------------ Events ------------------------------

  // User pressed a key in the text field.
  our_keydown(event) {
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
          event.preventDefault();
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
  }

  // Need to prevent these keys from being processed by form.
  our_keypress(event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    // this.debug("keypress(key=" + key + ", menu_up=" + this.menu_up + ", hot=" + this.is_hot_key(key) + ")");
    if (this.menu_up && this.is_hot_key(key) &&
      !(key == EVENT_KEY_TAB || this.current_row < 0))
      return false;
    return true;
  }

  // User has released a key.
  our_keyup(event) {
    // this.debug("keyup()");
    this.clear_key();
    this.our_change(true);
    return true;
  }

  // Input field has changed.
  our_change(do_refresh) {
    const old_val = this.old_value[this.uuid];
    const new_val = this.input_elem.value;
    // this.debug("our_change(" + this.input_elem.value + ")");
    if (new_val != old_val) {
      this.old_value[this.uuid] = new_val;
      if (do_refresh)
        this.schedule_refresh();
    }
  }

  // User clicked into text field.
  our_click(event) {
    if (this.act_like_select)
      this.schedule_refresh();
    return false;
  }

  // User entered text field.
  our_focus(event) {
    // this.debug("our_focus()");
    if (!this.row_height)
      this.get_row_height();
    this.focused = true;
  }

  // User left the text field.
  our_blur(event) {
    // this.debug("our_blur()");
    this.schedule_hide();
    this.focused = false;
  }

  // User has navigated away from page.
  our_unload() {
    // If native browser autocomplete is turned off, browsers like chrome
    // and firefox will not remember the value of fields when you go back.
    // This hack re-enables native autocomplete before leaving the page.
    // [This only works for firefox; should work for chrome but doesn't.]
    this.input_elem.setAttribute("autocomplete", "on");
    return false;
  }

  // Prevent these keys from propagating to the input field.
  is_hot_key(key) {
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
  }

  // ------------------------------ Timers ------------------------------

  // Schedule primer to be refreshed after polite delay.
  schedule_refresh() {
    this.verbose("schedule_refresh()");
    this.clear_refresh();
    this.refresh_timer = window.setTimeout((() => {
      this.verbose("doing_refresh()");
      // this.debug("refresh_timer(" + this.input_elem.value + ")");
      this.old_value[this.uuid] = this.input_elem.value;
      if (this.ajax_url)
        this.refresh_primer();
      this.update_matches();
      this.draw_pulldown();
    }), this.refresh_delay * 1000);
  }

  // Schedule pulldown to be hidden if nothing happens in the meantime.
  schedule_hide() {
    this.clear_hide();
    this.hide_timer = setTimeout(this.hide_pulldown.bind(this), this.hide_delay * 1000);
  }

  // Schedule a method to be called after key stays pressed for some time.
  schedule_key(action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.schedule_key2(action);
    }).bind(this), this.key_delay1 * 1000);
  }
  schedule_key2(action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.schedule_key2(action);
    }).bind(this), this.key_delay2 * 1000);
  }

  // Clear refresh timer.
  clear_refresh() {
    if (this.refresh_timer) {
      clearTimeout(this.refresh_timer);
      this.refresh_timer = null;
    }
  }

  // Clear hide timer.
  clear_hide() {
    if (this.hide_timer) {
      clearTimeout(this.hide_timer);
      this.hide_timer = null;
    }
  }

  // Clear key timer.
  clear_key() {
    if (this.key_timer) {
      clearTimeout(this.key_timer);
      this.key_timer = null;
    }
  }

  // ------------------------------ Cursor ------------------------------

  // Move cursor up or down some number of rows.
  page_up() { this.move_cursor(-this.page_size); }
  page_down() { this.move_cursor(this.page_size); }
  arrow_up() { this.move_cursor(-1); }
  arrow_down() { this.move_cursor(1); }
  go_home() { this.move_cursor(-this.matches.length) }
  go_end() { this.move_cursor(this.matches.length) }
  move_cursor(rows) {
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
  }

  // Mouse has moved over a menu item.
  highlight_row(new_hl) {
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
  }

  // Called when users scrolls via scrollbar.
  our_scroll() {
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
  }

  // User has selected a value, either pressing tab/return or clicking on an option.
  select_row(row) {
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
    this.input_elem.value = new_val;
    this.our_change(false);
  }

  // ------------------------------ Pulldown ------------------------------

  // Stimulus: maybe put empty list in template instead of adding it here
  // Create div for pulldown.
  create_pulldown() {
    const div = document.createElement("div");
    div.classList.add(this.pulldown_class);

    const list = document.createElement('ul');
    let i, row;
    for (i = 0; i < this.pulldown_size; i++) {
      row = document.createElement("li");
      row.style.display = 'none';
      this.attach_row_events(row, i);
      list.append(row);
    }
    div.appendChild(list)

    div.addEventListener("scroll", this.our_scroll.bind(this));
    this.input_elem.insertAdjacentElement("afterend", div);
    this.pulldown_elem = div;
    this.list_elem = list;
  }

  // Add "click" and "mouseover" events to a row of the pulldown menu.
  // Need to do this in a separate method, otherwise row doesn't get
  // a separate value for each row!  Something to do with scope of
  // variables inside for loops.
  attach_row_events(e, row) {
    e.addEventListener("click", (function () {
      this.select_row(row);
    }).bind(this));
    e.addEventListener("mouseover", (function () {
      this.highlight_row(row);
    }).bind(this));
  }

  // Stimulus: print this in the document already
  // Get actual row height when it becomes available.
  // Experimentally creates a test row.
  get_row_height() {
    // this.input_elem.disabled = true;
    const div = document.createElement('div'),
      ul = document.createElement('ul'),
      li = document.createElement('li');

    div.className = this.pulldown_class;
    div.style.display = 'block';
    div.style.border = div.style.margin = div.style.padding = '0px';
    li.innerHTML = 'test';
    ul.appendChild(li);
    div.appendChild(ul);
    document.body.appendChild(div);
    this.temp_row = div;
    // window.setTimeout(this.set_row_height(), 100);
    this.set_row_height();
    // this.input_elem.disabled = false;
  }
  set_row_height() {
    if (this.temp_row) {
      this.row_height = this.temp_row.offsetHeight;
      if (!this.row_height) {
        // window.setTimeout(this.set_row_height(), 100);
        this.set_row_height();
      } else {
        document.body.removeChild(this.temp_row);
        this.temp_row = null;
      }
    }
  }

  // Redraw the pulldown options.
  draw_pulldown() {
    this.verbose("draw_pulldown()");
    const list = this.list_elem;
    const rows = list.children;
    const size = this.pulldown_size;
    const scroll = this.scroll_offset;
    const cur = this.current_row;
    const matches = this.matches;

    if (this.log) {
      this.debug(
        "Redraw: matches=" + matches.length +
        ", scroll=" + scroll + ", cursor=" + cur
      );
    }

    // Get row height if haven't been able to yet.
    this.get_row_height();
    if (rows.length) {
      this.update_rows(rows, matches, size, scroll);
      this.highlight_new_row(rows, cur, size, scroll)
      this.make_menu_visible(matches, size, scroll)
    }

    // Make sure input focus stays on text field!
    this.input_elem.focus();
  }

  // Update menu text first.
  update_rows(rows, matches, size, scroll) {
    let i, x, y;
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
  }

  // Highlight that row.
  highlight_new_row(rows, cur, size, scroll) {
    const old_hl = this.current_highlight;
    let new_hl = cur - scroll;

    if (new_hl < 0 || new_hl >= size)
      new_hl = -1;
    this.current_highlight = new_hl;
    if (new_hl != old_hl) {
      if (old_hl >= 0)
        rows[old_hl].classList.remove(this.hot_class);
      if (new_hl >= 0)
        rows[new_hl].classList.add(this.hot_class);
    }
  }

  // Make menu visible if nonempty.
  make_menu_visible(matches, size, scroll) {
    const menu = this.pulldown_elem;
    const inner = menu.children[0];

    if (matches.length > 0) {
      // console.log("Matches:" + matches)
      const top = this.input_elem.offsetTop;
      const left = this.input_elem.offsetLeft;
      const hgt = this.input_elem.offsetHeight;
      const scr = this.input_elem.scrollTop;
      menu.style.top = (top + hgt + scr) + "px";
      menu.style.left = left + "px";

      // Set height of menu.
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
  }

  // Hide pulldown options.
  hide_pulldown() {
    this.verbose("hide_pulldown()");
    this.pulldown_elem.style.display = 'none';
    this.menu_up = false;
  }

  // Update width of pulldown.
  update_width() {
    this.verbose("update_width()");
    let w = this.list_elem.offsetWidth;
    if (this.matches.length > this.pulldown_size)
      w += this.scrollbar_width;
    if (this.current_width < w) {
      this.current_width = w;
      this.set_width();
    }
  }

  // Set width of pulldown.
  set_width() {
    this.verbose("set_width()");
    const w1 = this.current_width;
    let w2 = w1;
    if (this.matches.length > this.pulldown_size)
      w2 -= this.scrollbar_width;
    this.list_elem.style.minWidth = w2 + 'px';
  }

  // ------------------------------ Matches ------------------------------

  // Update content of pulldown.
  update_matches() {
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
  }

  // When "acting like a select" make it display all options in the
  // order given right from the moment they enter the field.
  // FIXME - make the year thing do an array
  update_select() {
    this.matches = this.primer;
  }

  // Grab all matches, doing exact match, ignoring number of words.
  update_normal() {
    const val = this.input_elem.value.normalize().toLowerCase();
    const primer = this.primer.map((str) => { return str.normalize() });
    // FIXME this iterator!
    const matches = [];
    if (val != '') {
      let i, s;
      for (i = 0; i < primer.length; i++) {
        s = primer[i + 1];
        if (s.length > 0 && s.toLowerCase().indexOf(val) >= 0) {
          matches.push(s);
          if (matches.length >= this.max_matches)
            break;
        }
      }
    }
    this.matches = matches;
  }

  // Grab matches ignoring order of words.
  update_unordered() {
    const val = this.input_elem.value.normalize().toLowerCase().
      replace(/^ */, '').replace(/  +/g, ' ');
    const vals = val.split(' ');
    const primer = this.primer.map((str) => { return str.normalize() });
    const matches = [];
    if (val != '') {
      let i, k, s, s2;
      for (i = 0; i < primer.length; i++) {
        s = primer[i + 1] || '';
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
  }

  // Grab all matches, preferring the ones with no additional words.
  // Note: order must have genera first, then species, then varieties.
  update_collapsed() {
    const val = "\n" + this.input_elem.value.toLowerCase();
    const primer = this.primer;

    const primer_lc = this.primer.toLowerCase();
    const matches = [];
    if (val != "\n") {
      let the_rest = (val.match(/ /g) || []).length >= this.collapse;
      let i, s;
      for (i = primer_lc.indexOf(val); i >= 0;
        i = primer_lc.indexOf(val, i + 1)) {
        s = primer[i + 1];
        if (s.length > 0) {
          if (the_rest || s.indexOf(' ', val.length - 1) < val.length - 1) {
            matches.push(s);
            if (matches.length >= this.max_matches)
              break;
          } else if (matches.length > 1) {
            break;
          } else {
            if (matches[0] == val)
              matches.pop();
            matches.push(s);
            if (matches.length >= this.max_matches)
              break;
            the_rest = true;
          }
        }
      }
      if (matches.length == 1 &&
        (val == matches[0].toLowerCase() ||
          val == matches[0].toLowerCase() + " "))
        matches.pop();
    }
    this.matches = matches;
  }

  // Remove duplicates from a sorted array.
  remove_dups(list) {
    let i, j;
    for (i = 0, j = 1; j < list.length; j++) {
      if (list[j] != list[i])
        list[++i] = list[j];
    }
    if (++i < list.length)
      list.splice(i, list.length - i);
    return list;
  }

  // Look for 'val' in list of matches and highlight it,
  // otherwise highlight first match.
  update_current_row(val) {
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
  }

  // ------------------------------ Fetch matches ------------------------------

  // Send request for updated primer.
  refresh_primer() {
    this.verbose("refresh_primer()");
    let val = this.input_elem.value.toLowerCase();

    // Don't make request on empty string!
    if (!val || val.length < 1)
      return;

    // Don't repeat last request accidentally!
    if (this.last_fetch_request == val)
      return;

    // No need to make more constrained request if we got all results last time.
    if (this.last_fetch_request &&
      this.last_fetch_request.length > 0 &&
      !this.last_fetch_incomplete &&
      this.last_fetch_request.length < val.length &&
      this.last_fetch_request == val.substr(0, this.last_fetch_request.length))
      return;

    // If a less constrained request is pending, wait for it to return before
    // refining the request, just in case it returns complete results
    // (rendering the more refined request unnecessary).
    if (this.fetch_request &&
      this.last_fetch_request.length < val.length &&
      this.last_fetch_request == val.substr(0, this.last_fetch_request.length))
      return;

    // Make request.
    this.send_fetch_request(val);
  }

  // Send AJAX request for more matching strings.
  send_fetch_request(val) {
    this.verbose("send_fetch_request()");
    if (val.length > this.max_request_length)
      val = val.substr(0, this.max_request_length);

    if (this.log) {
      this.debug("Sending AJAX request: " + val);
    }

    // console.log("Sending AJAX request: " + val);

    // Need to doubly-encode this to prevent router from interpreting slashes,
    // dots, etc.
    const url = this.ajax_url.replace(
      '@', encodeURIComponent(encodeURIComponent(val.replace(/\./g, '%2e')))
    );

    this.last_fetch_request = val;

    const controller = new AbortController();
    const signal = controller.signal;

    if (this.fetch_request)
      controller.abort();

    this.fetch_request = fetch(url, { signal }).then((response) => {
      if (response.ok) {
        if (200 <= response.status && response.status <= 299) {
          response.json().then((json) => {
            // console.log("json: " + json);
            this.process_fetch_response(json)
          }).catch((error) => {
            console.error("no_content:", error);
          });
        } else {
          this.fetch_request = null;
          console.log(`got a ${response.status}`);
        }
      }
    }).catch((error) => {
      // console.error("Server Error:", error);
    });
  }


  // Process response from server:
  // 1. first line is string actually used to match;
  // 2. the last string is "..." if the set of results is incomplete;
  // 3. the rest are matching results.
  process_fetch_response(new_primer) {
    this.verbose("process_fetch_response()");

    // Clear flag telling us request is pending.
    this.fetch_request = null;
    // console.log("new_primer: " + new_primer);

    // Record string actually used to do matching: might be less strict
    // than one sent in request.
    this.last_fetch_request = new_primer[0];

    // Make sure there's a trailing newline.
    if (new_primer[new_primer.length - 1] != '\n')
      new_primer.push("\n");

    // Check for trailing "..." signaling incomplete set of results.
    if (new_primer[new_primer.length - 2] == "...") {
      this.last_fetch_incomplete = true;
      new_primer = new_primer.slice(0, new_primer.length - 2);
      if (this.focused)
        // (just in case we need to refine the request due to
        //  activity while waiting for this response)
        this.schedule_refresh();
    } else {
      this.last_fetch_incomplete = false;
    }

    // Log requests and responses if in debug mode.
    if (this.log) {
      this.debug("Got response for " + this.escapeHTML(this.last_fetch_request) +
        ": " + (new_primer.length - 2) + " strings (" +
        (this.last_fetch_incomplete ? "incomplete" : "complete") + ").");
    }

    // Update menu if anything has changed.
    if (this.primer != new_primer && this.focused) {
      this.primer = new_primer;
      this.update_matches();
      this.draw_pulldown();
    }
  }

  // ------------------------------ Input ------------------------------
  // written by Tim Down
  // http://stackoverflow.com/questions/3053542/how-to-get-the-start-and-end-points-of-selection-in-text-area/3053640#3053640

  getInputSelection(el) {
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
  }

  setCursorPosition(el, pos) {
    if (el.setSelectionRange) {
      el.setSelectionRange(pos, pos);
    } else if (el.createTextRange) {
      const range = el.createTextRange();
      range.collapse(true);
      range.moveEnd('character', pos);
      range.moveStart('character', pos);
      range.select();
    }
  }

  // ------------------------------- DEBUGGING ------------------------------

  debug(str) {
    document.getElementById("log").insertAdjacentText("beforeend", str + "<br/>");
  }

  verbose(str) {
    // console.log(str);
    // document.getElementById("log").insertAdjacentText("beforeend", str + "<br/>");
  }

  // ------------------------------- UTILITIES ------------------------------

  // These methods are also used in name_lister.js
  // Stimulus: May want to make a shared module
  escapeHTML(str) {
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
  }

  getScrollBarWidth() {
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
};

