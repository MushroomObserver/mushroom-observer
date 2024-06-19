import { Controller } from "@hotwired/stimulus"
import { escapeHTML, getScrollBarWidth, EVENT_KEYS } from "src/mo_utilities"
import { get } from "@rails/request.js"

const DEFAULT_OPTS = {
  // what type of autocompleter, subclass of AutoComplete
  TYPE: null,
  // Whether to ignore order of words when matching, set by type
  // (collapse must be 0 if this is true!)
  UNORDERED: false,
  // 0 = normal mode
  // 1 = autocomplete first word, then the rest
  // 2 = autocomplete first word, then second word, then the rest
  // N = etc.
  COLLAPSE: 0,
  // where to request primer from
  AJAX_URL: "/autocompleters/new/",
  // how long to wait before sending AJAX request (seconds)
  REFRESH_DELAY: 0.10,
  // how long to wait before hiding pulldown (seconds)
  HIDE_DELAY: 0.25,
  // initial key repeat delay (seconds)
  KEY_DELAY_1: 0.50,
  // subsequent key repeat delay (seconds)
  KEY_DELAY_2: 0.03,
  // maximum number of options shown at a time
  PULLDOWN_SIZE: 10,
  // amount to move cursor on page up and down
  PAGE_SIZE: 10,
  // max length of string to send via AJAX
  MAX_STRING_LENGTH: 50,
  // Sub-match: starts finding new matches for the string *after the separator*
  // allowed separators (e.g. " OR ")
  SEPARATOR: null,
  // show error messages returned via AJAX?
  SHOW_ERRORS: false,
  // include pulldown-icon on right, and always show all options
  ACT_LIKE_SELECT: false,
  // class of pulldown div, selected by system tests
  PULLDOWN_CLASS: 'auto_complete',
  // class of <li> when highlighted
  HOT_CLASS: 'selected'
}

// Allowed types of autocompleter. Sets some DEFAULT_OPTS from type
const AUTOCOMPLETER_TYPES = {
  clade: {
  },
  herbarium: { // params[:user_id] handled in controller
    UNORDERED: true
  },
  location: { // params[:format] handled in controller
    UNORDERED: true
  },
  name: {
    COLLAPSE: 1
  },
  project: {
    UNORDERED: true
  },
  region: {
    UNORDERED: true
  },
  species_list: {
    UNORDERED: true
  },
  user: {
    UNORDERED: true
  }
}

// These are internal state variables the user should leave alone.
const INTERNAL_OPTS = {
  PULLDOWN_ELEM: null,   // DOM element of pulldown div
  LIST_ELEM: null,       // DOM element of pulldown ul
  ROW_HEIGHT: null,      // height of a ul li row in pixels (determined below)
  SCROLLBAR_WIDTH: null, // width of scrollbar in browser (determined below)
  focused: false,        // is user in text field?
  menu_up: false,        // is pulldown visible?
  old_value: null,       // previous value of input field
  primer: [],            // a server-supplied list of many options
  matches: [],           // list of options currently showing
  current_row: -1,       // index of option currently highlighted (0 = none)
  current_value: null,   // value currently highlighted (null = none)
  current_highlight: -1, // row of view highlighted (-1 = none)
  current_width: 0,      // current width of menu
  scroll_offset: 0,      // scroll offset
  last_fetch_request: '', // last fetch request we got results for
  last_fetch_incomplete: true, // did we get all the results we requested?
  fetch_request: null,   // ajax request while underway
  refresh_timer: null,   // timer used to delay update after typing
  hide_timer: null,      // timer used to delay hiding of pulldown
  key_timer: null        // timer used to emulate key repeat
}

// Connects to data-controller="autocomplete"
export default class extends Controller {
  // The select target is not the input element, but a <select> that can
  // swap out the autocompleter type. The input element is the target.
  static targets = ["input", "select"]

  initialize() {
    Object.assign(this, DEFAULT_OPTS);

    // Check the type of autocompleter set on the input element
    // maybe should not happen on connect, or we could be resetting type
    // Or maybe it should, and the filter swapper should just change this? no.
    this.TYPE = this.inputTarget.dataset.autocomplete;
    if (!AUTOCOMPLETER_TYPES.hasOwnProperty(this.TYPE))
      alert("MOAutocompleter: Invalid type: \"" + this.TYPE + "\"");

    // Only allow types we can handle:
    Object.assign(this, AUTOCOMPLETER_TYPES[this.TYPE]);
    Object.assign(this, INTERNAL_OPTS);

    // Shared MO utilities, imported at the top:
    this.EVENT_KEYS = EVENT_KEYS;
    this.escapeHTML = escapeHTML;
    this.getScrollBarWidth = getScrollBarWidth;
  }

  connect() {
    this.element.dataset.stimulus = "connected";

    // Figure out a few browser-dependent dimensions.
    this.getScrollBarWidth;

    // Create pulldown.
    this.create_pulldown();

    // Attach events, etc. to input element.
    this.prepare_input_element();
  }

  // Swap out autocompleter type (and properties)
  // Action called from a <select> with `data-action: "autocompleter-swap"`
  swap(opts = {}) {
    if (!this.hasSelectTarget)
      return;

    const type = this.selectTarget.value;

    if (!AUTOCOMPLETER_TYPES.hasOwnProperty(type)) {
      alert("MOAutocompleter: Invalid type: \"" + this.TYPE + "\"");
    } else {
      this.TYPE = type;
      this.inputTarget.setAttribute("data-autocompleter", type)
      // add dependent properties and allow overrides
      Object.assign(this, AUTOCOMPLETER_TYPES[this.TYPE]);
      Object.assign(this, opts);
      this.prepare_input_element();
    }
  }

  // Prepare input element: attach elements, set properties.
  prepare_input_element() {
    // console.log(elem)
    this.old_value = null;

    // Attach events
    this.add_event_listeners();

    // sanity check to show which autocompleter is currently on the element
    this.inputTarget.setAttribute("data-ajax-url", this.AJAX_URL + this.TYPE);

    // If the primer is not based on input, go ahead and request from server.
    if (this.ACT_LIKE_SELECT == true) {
      this.inputTarget.click();
      this.inputTarget.focus();
      this.inputTarget.value = ' ';
    }
  }

  // NOTE: `this` within an event listener function refers to the element
  // (the eventTarget) -- unless you pass an arrow function as the listener.
  // But writing a specially named function handleEvent() allows delegating
  // the class as the handler. more info below:
  add_event_listeners() {
    // Stimulus - data-actions on the input can route events to actions here
    this.inputTarget.addEventListener("focus", this);
    this.inputTarget.addEventListener("click", this);
    this.inputTarget.addEventListener("blur", this);
    this.inputTarget.addEventListener("keydown", this);
    this.inputTarget.addEventListener("keyup", this);
    this.inputTarget.addEventListener("keypress", this);
    this.inputTarget.addEventListener("change", this);
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
        case this.EVENT_KEYS.esc:
          this.schedule_hide();
          this.menu_up = false;
          break;
        case this.EVENT_KEYS.tab:
        case this.EVENT_KEYS.return:
          event.preventDefault();
          if (this.current_row >= 0)
            this.select_row(this.current_row - this.scroll_offset);
          break;
        case this.EVENT_KEYS.home:
          this.go_home();
          break;
        case this.EVENT_KEYS.end:
          this.go_end();
          break;
        case this.EVENT_KEYS.pageup:
          this.page_up();
          this.schedule_key(this.page_up);
          break;
        case this.EVENT_KEYS.up:
          this.arrow_up();
          this.schedule_key(this.arrow_up);
          break;
        case this.EVENT_KEYS.down:
          this.arrow_down();
          this.schedule_key(this.arrow_down);
          break;
        case this.EVENT_KEYS.pagedown:
          this.page_down();
          this.schedule_key(this.page_down);
          break;
        default:
          this.current_row = -1;
          break;
      }
    }
    if (this.menu_up && this.is_hot_key(key) &&
      !(key == 9 || this.current_row < 0))
      return false;
    return true;
  }

  // Need to prevent these keys from being processed by form.
  our_keypress(event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    // this.debug("keypress(key=" + key + ", menu_up=" + this.menu_up + ", hot=" + this.is_hot_key(key) + ")");
    if (this.menu_up && this.is_hot_key(key) &&
      !(key == 9 || this.current_row < 0))
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
    const old_val = this.old_value;
    const new_val = this.inputTarget.value;
    // this.debug("our_change(" + this.inputTarget.value + ")");
    if (new_val != old_val) {
      this.old_value = new_val;
      if (do_refresh)
        this.schedule_refresh();
    }
  }

  // User clicked into text field.
  our_click(event) {
    if (this.ACT_LIKE_SELECT)
      this.schedule_refresh();
    return false;
  }

  // User entered text field.
  our_focus(event) {
    // this.debug("our_focus()");
    if (!this.ROW_HEIGHT)
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
    this.inputTarget.setAttribute("autocomplete", "on");
    return false;
  }

  // Prevent these keys from propagating to the input field.
  is_hot_key(key) {
    switch (key) {
      case this.EVENT_KEYS.esc:
      case this.EVENT_KEYS.return:
      case this.EVENT_KEYS.tab:
      case this.EVENT_KEYS.up:
      case this.EVENT_KEYS.down:
      case this.EVENT_KEYS.pageup:
      case this.EVENT_KEYS.pagedown:
      case this.EVENT_KEYS.home:
      case this.EVENT_KEYS.end:
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
      // this.debug("refresh_timer(" + this.inputTarget.value + ")");
      this.old_value = this.inputTarget.value;
      if (this.AJAX_URL)
        this.refresh_primer();
      this.update_matches();
      this.draw_pulldown();
    }), this.REFRESH_DELAY * 1000);
  }

  // Schedule pulldown to be hidden if nothing happens in the meantime.
  schedule_hide() {
    this.clear_hide();
    this.hide_timer = setTimeout(this.hide_pulldown.bind(this), this.HIDE_DELAY * 1000);
  }

  // Schedule a method to be called after key stays pressed for some time.
  schedule_key(action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.schedule_key2(action);
    }).bind(this), this.KEY_DELAY_1 * 1000);
  }
  schedule_key2(action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.schedule_key2(action);
    }).bind(this), this.KEY_DELAY_2 * 1000);
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
  page_up() { this.move_cursor(-this.PAGE_SIZE); }
  page_down() { this.move_cursor(this.PAGE_SIZE); }
  arrow_up() { this.move_cursor(-1); }
  arrow_down() { this.move_cursor(1); }
  go_home() { this.move_cursor(-this.matches.length) }
  go_end() { this.move_cursor(this.matches.length) }
  move_cursor(rows) {
    this.verbose("move_cursor()");
    const _old_row = this.current_row,
      _old_scr = this.scroll_offset;
    let _new_row = _old_row + rows,
      _new_scr = _old_scr;

    // Move cursor, but keep in bounds.
    if (_new_row < 0)
      _new_row = _old_row < 0 ? -1 : 0;
    if (_new_row >= this.matches.length)
      _new_row = this.matches.length - 1;
    this.current_row = _new_row;
    this.current_value = _new_row < 0 ? null : this.matches[_new_row];

    // Scroll view so new row is visible.
    if (_new_row < _new_scr)
      _new_scr = _new_row;
    if (_new_scr < 0)
      _new_scr = 0;
    if (_new_row >= _new_scr + this.PULLDOWN_SIZE)
      _new_scr = _new_row - this.PULLDOWN_SIZE + 1;

    // Update if something changed.
    if (_new_row != _old_row || _new_scr != _old_scr) {
      this.scroll_offset = _new_scr;
      this.draw_pulldown();
    }
  }

  // Mouse has moved over a menu item.
  highlight_row(new_hl) {
    this.verbose("highlight_row()");
    const _rows = this.LIST_ELEM.children,
      _old_hl = this.current_highlight;

    this.current_highlight = new_hl;
    this.current_row = this.scroll_offset + new_hl;

    if (_old_hl != new_hl) {
      if (_old_hl >= 0)
        _rows[_old_hl].classList.remove(this.HOT_CLASS);
      if (new_hl >= 0)
        _rows[new_hl].classList.add(this.HOT_CLASS);
    }
    this.inputTarget.focus();
    this.update_width();
  }

  // Called when users scrolls via scrollbar.
  our_scroll() {
    this.verbose("our_scroll()");
    const _old_scr = this.scroll_offset,
      _new_scr = Math.round(this.PULLDOWN_ELEM.scrollTop / this.ROW_HEIGHT),
      _old_row = this.current_row;
    let _new_row = this.current_row;

    if (_new_row < _new_scr)
      _new_row = _new_scr;
    if (_new_row >= _new_scr + this.PULLDOWN_SIZE)
      _new_row = _new_scr + this.PULLDOWN_SIZE - 1;
    if (_new_row != _old_row || _new_scr != _old_scr) {
      this.current_row = _new_row;
      this.scroll_offset = _new_scr;
      this.draw_pulldown();
    }
  }

  // User selects a value, either pressing tab/return or clicking on an option.
  select_row(row) {
    this.verbose("select_row()");
    // const old_val = this.inputTarget.value;
    let _new_val = this.matches[this.scroll_offset + row];
    // Close pulldown unless the value the user selected uncollapses into a set
    // of new options.  In that case schedule a refresh and leave it up.
    if (this.COLLAPSE > 0 &&
      (_new_val.match(/ /g) || []).length < this.COLLAPSE) {
      _new_val += ' ';
      this.schedule_refresh();
    } else {
      this.schedule_hide();
    }
    this.inputTarget.focus();
    this.focused = true;
    this.inputTarget.value = _new_val;
    this.set_search_token(_new_val);
    this.our_change(false);
  }

  // ------------------------------ Pulldown ------------------------------

  // Create div for pulldown. Presence of this is checked in system tests.
  create_pulldown() {
    const _pulldown = document.createElement("div");
    _pulldown.classList.add(this.PULLDOWN_CLASS);

    const _list = document.createElement('ul');
    _list.classList.add(this.LIST_CLASS);

    let i, _item;
    for (i = 0; i < this.PULLDOWN_SIZE; i++) {
      _item = document.createElement("li");
      _item.style.display = 'none';
      this.attach_row_events(_item, i);
      _list.append(_item);
    }
    _pulldown.appendChild(_list)

    _pulldown.addEventListener("scroll", this.our_scroll.bind(this));
    this.inputTarget.insertAdjacentElement("afterend", _pulldown);
    this.PULLDOWN_ELEM = _pulldown;
    this.LIST_ELEM = _list;
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
    const div = document.createElement('div'),
      ul = document.createElement('ul'),
      li = document.createElement('li');

    div.className = this.PULLDOWN_CLASS;
    div.style.display = 'block';
    div.style.border = div.style.margin = div.style.padding = '0px';
    li.innerHTML = 'test';
    ul.appendChild(li);
    div.appendChild(ul);
    document.body.appendChild(div);
    this.temp_row = div;
    // window.setTimeout(this.set_row_height(), 100);
    this.set_row_height();
  }
  set_row_height() {
    if (this.temp_row) {
      this.ROW_HEIGHT = this.temp_row.offsetHeight;
      if (!this.ROW_HEIGHT) {
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
    const _list = this.LIST_ELEM,
      _rows = _list.children,
      _size = this.PULLDOWN_SIZE,
      _scroll = this.scroll_offset,
      _current = this.current_row,
      _matches = this.matches;

    if (this.log) {
      this.debug(
        "Redraw: matches=" + _matches.length + ", scroll=" + _scroll + ", cursor=" + _current
      );
    }

    // Get row height if haven't been able to yet.
    this.get_row_height();
    if (_rows.length) {
      this.update_rows(_rows, _matches, _size, _scroll);
      this.highlight_new_row(_rows, _current, _size, _scroll)
      this.make_menu_visible(_matches, _size, _scroll)
    }

    // Make sure input focus stays on text field!
    this.inputTarget.focus();
  }

  // Update menu text first.
  update_rows(rows, matches, size, scroll) {
    let i, x, y;
    for (i = 0; i < size; i++) {
      let _row = rows.item(i);
      x = _row.innerHTML;
      if (i + scroll < matches.length) {
        y = this.escapeHTML(matches[i + scroll]);
        if (x != y) {
          if (x == '')
            _row.style.display = 'block';
          _row.innerHTML = y;
        }
      } else {
        if (x != '') {
          _row.innerHTML = '';
          _row.style.display = 'none';
        }
      }
    }
  }

  // Highlight that row.
  highlight_new_row(rows, cur, size, scroll) {
    const _old_hl = this.current_highlight;
    let _new_hl = cur - scroll;

    if (_new_hl < 0 || _new_hl >= size)
      _new_hl = -1;
    this.current_highlight = _new_hl;
    if (_new_hl != _old_hl) {
      if (_old_hl >= 0)
        rows[_old_hl].classList.remove(this.HOT_CLASS);
      if (_new_hl >= 0)
        rows[_new_hl].classList.add(this.HOT_CLASS);
    }
  }

  // Make menu visible if nonempty.
  make_menu_visible(matches, size, scroll) {
    const _pulldown = this.PULLDOWN_ELEM,
      _list = _pulldown.children[0];

    if (matches.length > 0) {
      // console.log("Matches:" + matches)
      const _top = this.inputTarget.offsetTop,
        _left = this.inputTarget.offsetLeft,
        _hgt = this.inputTarget.offsetHeight,
        _scr = this.inputTarget.scrollTop;
      _pulldown.style.top = (_top + _hgt + _scr) + "px";
      _pulldown.style.left = _left + "px";

      // Set height of menu.
      _pulldown.style.overflowY = matches.length > size ? "scroll" : "hidden";
      _pulldown.style.height = this.ROW_HEIGHT *
        (size < matches.length - scroll ? size : matches.length - scroll) +
        "px";
      _list.style.marginTop = this.ROW_HEIGHT * scroll + "px";
      _list.style.height = this.ROW_HEIGHT * (matches.length - scroll) + "px";
      _pulldown.scrollTo({ top: this.ROW_HEIGHT * scroll });

      // Set width of menu.
      this.set_width();
      this.update_width();

      // Only show menu if it is nontrivial, i.e., show an option other than
      // the value that's already in the text field.
      if (matches.length > 1 || this.inputTarget.value != matches[0]) {
        this.clear_hide();
        _pulldown.style.display = 'block';
        this.menu_up = true;
      } else {
        _pulldown.style.display = 'none';
        this.menu_up = false;
      }
    }

    // Hide the menu if it's empty now.
    else {
      _pulldown.style.display = 'none';
      this.menu_up = false;
    }
  }

  // Hide pulldown options.
  hide_pulldown() {
    this.verbose("hide_pulldown()");
    this.PULLDOWN_ELEM.style.display = 'none';
    this.menu_up = false;
  }

  // Update width of pulldown.
  update_width() {
    this.verbose("update_width()");
    let w = this.LIST_ELEM.offsetWidth;
    if (this.matches.length > this.PULLDOWN_SIZE)
      w += this.SCROLLBAR_WIDTH;
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
    if (this.matches.length > this.PULLDOWN_SIZE)
      w2 -= this.SCROLLBAR_WIDTH;
    this.LIST_ELEM.style.minWidth = w2 + 'px';
  }

  // ------------------------------ Matches ------------------------------

  // Update content of pulldown.
  update_matches() {
    this.verbose("update_matches()");
    if (this.ACT_LIKE_SELECT)
      this.current_row = 0;
    // Remember which option used to be highlighted.
    const _last = this.current_row < 0 ? null : this.matches[this.current_row];

    // Update list of options appropriately.
    if (this.ACT_LIKE_SELECT)
      this.update_select();
    else if (this.COLLAPSE > 0)
      this.update_collapsed();
    else if (this.UNORDERED)
      this.update_unordered();
    else
      this.update_normal();

    // Sort and remove duplicates, unless it's already sorted.
    if (!this.ACT_LIKE_SELECT)
      this.matches = this.remove_dups(this.matches.sort());
    // Try to find old highlighted row in new set of options.
    this.update_current_row(_last);
    // Reset width each time we change the options.
    this.current_width = this.inputTarget.offsetWidth;
  }

  // When "acting like a select" make it display all options in the
  // order given right from the moment they enter the field,
  // and pick the first one.
  update_select() {
    this.matches = this.primer;
    if (this.matches.length > 0)
      this.inputTarget.value = this.matches[0];
  }

  // Grab all matches, doing exact match, ignoring number of words.
  update_normal() {
    const _token = this.get_search_token().normalize().toLowerCase(),
      // normalize the Unicode of each string in primer for search
      _primer = this.primer.map((str) => { return str.normalize() }),
      _matches = [];

    if (_token != '') {
      for (let i = 0; i < _primer.length; i++) {
        let s = _primer[i + 1];
        if (s && s.length > 0 && s.toLowerCase().indexOf(_token) >= 0) {
          _matches.push(s);
        }
      }
    }

    this.matches = _matches;
  }

  // Grab matches ignoring order of words.
  update_unordered() {
    // regularize spacing in the input
    const _token = this.get_search_token().normalize().toLowerCase().
      replace(/^ */, '').replace(/  +/g, ' '),
      // get the separate words as _tokens
      _tokens = _token.split(' '),
      // normalize the Unicode of each string in primer for search
      _primer = this.primer.map((str) => { return str.normalize() }),
      _matches = [];

    if (_token != '' && _primer.length > 1) {
      for (let i = 1; i < _primer.length; i++) {
        let s = _primer[i] || '',
          s2 = ' ' + s.toLowerCase() + ' ',
          k;
        // check each word in the primer entry for a matching word
        for (k = 0; k < _tokens.length; k++) {
          if (s2.indexOf(' ' + _tokens[k]) < 0) break;
        }
        if (k >= _tokens.length) {
          _matches.push(s);
        }
      }
    }

    this.matches = _matches;
  }

  // Grab all matches, preferring the ones with no additional words.
  // Note: order must have genera first, then species, then varieties.
  update_collapsed() {
    const _token = this.get_search_token().toLowerCase(),
      _primer = this.primer,
      // make a lowercased duplicate of primer to regularize search
      _primer_lc = this.primer.map((str) => { return str.toLowerCase() }),
      _matches = [];

    if (_token != '' && _primer.length > 1) {
      let _the_rest = (_token.match(/ /g) || []).length >= this.COLLAPSE;

      for (let i = 1; i < _primer_lc.length; i++) {
        if (_primer_lc[i].indexOf(_token) > -1) {
          let _s = _primer[i];
          if (_s.length > 0) {
            if (_the_rest || _s.indexOf(' ', _token.length) < _token.length) {
              _matches.push(_s);
            } else if (_matches.length > 1) {
              break;
            } else {
              if (_matches[0] == _token)
                _matches.pop();
              _matches.push(_s);
              _the_rest = true;
            }
          }
        }
      }
      if (_matches.length == 1 &&
        (_token == matches[0].toLowerCase() ||
          _token == matches[0].toLowerCase() + ' '))
        _matches.pop();
    }
    this.matches = _matches;
  }

  /**
   * Index of string in future primer array with IDs
   * where primer == [[text_string, id], [text_string, id]]
   * @param primer {!Array} - the input array
   * @param val {object} - the value to search
   * @return {Array} or just i
   */
  // get_primer_index_of(primer, val) {
  //   for (let i = 0; i < primer.length; i++) {
  //     const index = primer[i].indexOf(val);
  //     if (index > -1) {
  //       // return [i, index];
  //       return i;
  //     }
  //   }
  // }

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
    const _matches = this.matches,
      _size = this.PULLDOWN_SIZE;
    let _exact = -1,
      _part = -1;

    if (val && val.length > 0) {
      for (let i = 0; i < _matches.length; i++) {
        if (_matches[i] == val) {
          _exact = i;
          break;
        }
        if (_matches[i] == val.substr(0, _matches[i].length) &&
          (_part < 0 || _matches[i].length > _matches[_part].length))
          _part = i;
      }
    }
    let _new_row = _exact >= 0 ? _exact : _part >= 0 ? _part : -1;
    let _new_scroll = this.scroll_offset;
    if (_new_scroll > _new_row)
      _new_scroll = _new_row;
    if (_new_scroll > _matches.length - _size)
      _new_scroll = _matches.length - _size;
    if (_new_scroll < _new_row - _size + 1)
      _new_scroll = _new_row - _size + 1;
    if (_new_scroll < 0)
      _new_scroll = 0;

    this.current_row = _new_row;
    this.scroll_offset = _new_scroll;
  }

  /**
  * ------------------------------ Search Token ------------------------------
  *
  * The user input string for which we're currently requesting a server response
  * for matches. Usually that's the whole string, but in cases where the
  * autocompleter accepts a `separator` argument (currently only ' OR ', on the
  * advanced search page) the new search token would be the segment of the user
  * input string *after* that separator.
  *
  * That way, you get autocompletes for each part of "Agaricaceae OR Agaricales"
  */

  // Get search token under or immediately in front of cursor.
  get_search_token() {
    const _val = this.inputTarget.value;
    let _token = _val;
    if (this.SEPARATOR) {
      const _extents = this.search_token_extents();
      _token = _val.substring(_extents.start, _extents.end);
    }
    return _token;
  }

  // Change the token under or immediately in front of the cursor.
  set_search_token(new_val) {
    const _old_str = this.inputTarget.value;
    if (this.SEPARATOR) {
      let _new_str = "";
      const _extents = this.search_token_extents();

      if (_extents.start > 0)
        _new_str += _old_str.substring(0, _extents.start);
      _new_str += new_val;

      if (_extents.end < _old_str.length)
        _new_str += _old_str.substring(_extents.end);
      if (_old_str != _new_str) {
        let _old_scroll = this.inputTarget.offsetTop;
        this.inputTarget.value = _new_str;
        this.setCursorPosition(this.inputTarget[0],
          _extents.start + new_val.length);
        this.inputTarget.offsetTop = _old_scroll;
      }
    } else {
      if (_old_str != new_val)
        this.inputTarget.value = new_val;
    }
  }

  // Get index of first character and character after last of current token.
  search_token_extents() {
    const _val = this.inputTarget.value;
    let start = _val.lastIndexOf(this.SEPARATOR),
      end = _val.length;

    if (start < 0)
      start = 0;
    else
      start += this.SEPARATOR.length;

    return { start, end };
  }

  // ------------------------------ Fetch matches ------------------------------

  // Send request for updated primer.
  refresh_primer() {
    this.verbose("refresh_primer()");

    const _token = this.get_search_token().toLowerCase(),
      _last_request = this.last_fetch_request;

    // Don't make request on empty string!
    if (!this.ACT_LIKE_SELECT && (!_token || _token.length < 1))
      return;

    // Don't repeat last request accidentally!
    if (_last_request == _token)
      return;

    // Memoize this condition, used twice:
    // "is the new search token an extension of the previous search string?"
    const _new_val_refines_last_request =
      (_last_request?.length < _token.length) &&
      (_last_request == _token.substr(0, _last_request?.length));

    // No need to make more constrained request if we got all results last time.
    if (!this.last_fetch_incomplete &&
      _last_request && (_last_request.length > 0) &&
      _new_val_refines_last_request)
      return;

    // If a less constrained request is pending, wait for it to return before
    // refining the request, just in case it returns complete results
    // (rendering the more refined request unnecessary).
    if (this.fetch_request && _new_val_refines_last_request)
      return;

    if (_token.length > this.MAX_STRING_LENGTH)
      _token = _token.substr(0, this.MAX_STRING_LENGTH);

    const _query_params = { string: _token, ...this.request_params }

    // If it's a param search, ignore the search token and return all results.
    if (this.ACT_LIKE_SELECT) { _query_params["all"] = true; }

    // Make request.
    this.send_fetch_request(_query_params);
  }

  // Send AJAX request for more matching strings.
  async send_fetch_request(query_params) {
    this.verbose("send_fetch_request()");

    if (this.log) {
      this.debug("Sending fetch request: " + query_params.string + "...");
    }

    const _url = this.AJAX_URL + this.TYPE,
      _controller = new AbortController();

    this.last_fetch_request = query_params.string;
    if (this.fetch_request)
      _controller.abort();

    const response = await get(_url, {
      signal: _controller.signal,
      query: query_params,
      responseKind: "json"
    });

    if (response.ok) {
      const json = await response.json
      if (json) {
        this.fetch_request = response
        this.process_fetch_response(json)
      }
    } else {
      this.fetch_request = null;
      console.log(`got a ${response.status}: ${response.text}`);
    }

  }

  // Process response from server:
  // 1. first line is string actually used to match;
  // 2. the last string is "..." if the set of results is incomplete;
  // 3. the rest are matching results.
  process_fetch_response(new_primer) {
    this.verbose("process_fetch_response()");

    // Clear flag telling us request is pending.
    this.fetch_request = null;

    // Record string actually used to do matching: might be less strict
    // than one sent in request.
    this.last_fetch_request = new_primer[0];

    // Check for trailing "..." signaling incomplete set of results.
    if (new_primer[new_primer.length - 1] == "...") {
      this.last_fetch_incomplete = true;
      new_primer = new_primer.slice(0, new_primer.length - 1);
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
        ": " + (new_primer.length - 1) + " strings (" +
        (this.last_fetch_incomplete ? "incomplete" : "complete") + ").");
    }

    // Update menu if anything has changed.
    if (this.primer != new_primer && this.focused) {
      this.primer = new_primer;
      this.update_matches();
      this.draw_pulldown();
    }
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
    // document.getElementById("log").insertAdjacentText("beforeend", str + "<br/>");
  }

  verbose(str) {
    // console.log(str);
    // document.getElementById("log").insertAdjacentText("beforeend", str + "<br/>");
  }
}
