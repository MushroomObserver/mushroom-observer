import { Controller } from "@hotwired/stimulus"
import { escapeHTML, getScrollBarWidth, EVENT_KEYS } from "src/mo_utilities"
import { get } from "@rails/request.js"

// @pellaea's autocompleter is different from other open source autocompleter
// libraries. It can match words out of order, as in "scientific"
// location_format, and is closely configured to work with the responses MO's
// AutocompleteController produces.

// It is MUCH quicker than off-the-shelf autocompleters in dealing with AJAX
// queries for names and locations, because it calls the db once for all entries
// starting with the typed letter of the alphabet, and then consults this
// internal primer to refine results as the user types more, rather than making
// separate server requests for every letter typed.

// It implements a "virtual list" for the pulldown, which is impossible with the
// HTML <datalist> spec. When there are thousands of `matches`, it is
// impractical to keep them all as DOM nodes; the page becomes unresponsive.
// This controller hot-swaps the innerHTML in the same 10 <li> elements as the
// user scrolls with values from the fetched `matches`, and adjusts the
// margin-top of the <ul> to simulate scrolling.

const DEFAULT_OPTS = {
  // what type of autocompleter, corresponds to a subclass of `AutoComplete`
  TYPE: null,
  // Whether to ignore order of words when matching, set by type
  // (collapse must be 0 if this is true!)
  UNORDERED: false,
  // 0 = normal mode
  // 1 = autocomplete first word, then the rest
  // 2 = autocomplete first word, then second word, then the rest
  // N = etc.
  COLLAPSE: 0,
  // whether to send a new request for every letter, in the case of "region"
  WHOLE_WORDS_ONLY: false,
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
  // class of enclosing wrap div, usually also a .form-group.
  // Must have position: relative (or absolute...)
  WRAP_CLASS: 'dropdown',
  // class of <li> when highlighted.
  HOT_CLASS: 'active'
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
    UNORDERED: true,
    WHOLE_WORDS_ONLY: true
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

// Connects to data-controller="autocompleter"
export default class extends Controller {
  // The root element should usually be the .form-group wrapping the <input>.
  // The select target is not the <input> element, but a <select> that can
  // swap out the autocompleter type. The <input> element is its target.
  static targets = ["input", "select", "pulldown", "list", "hidden", "wrap"]

  initialize() {
    Object.assign(this, DEFAULT_OPTS);

    // Check the type of autocompleter set on the root or input element
    this.TYPE = this.element.dataset.type ?? this.inputTarget.dataset.type;
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

    // Wrap is usually the root element with the controller, a ".form-group".
    // But it could have different markup.
    if (!this.hasWrapTarget) {
      alert("MOAutocompleter: needs a wrapping div with class: \"" +
        this.WRAP_CLASS + "\"");
    }

    // Attach events, etc. to input element.
    this.prepareInputElement();
  }

  // Swap out autocompleter type (and properties)
  // Action may be called from a <select> with
  // `data-action: "autocompleter-swap:swap->autocompleter#swap"`
  // or an event dispatched by another controller.
  swap({ detail }) {
    let type;

    if (this.hasSelectTarget) {
      type = this.selectTarget.value;
    } else if (detail?.hasOwnProperty("type")) {
      type = detail.type;
    }
    if (type == undefined) { return; }

    if (!AUTOCOMPLETER_TYPES.hasOwnProperty(type)) {
      alert("MOAutocompleter: Invalid type: \"" + type + "\"");
    } else {
      this.TYPE = type;
      this.element.setAttribute("data-type", type)
      // add dependent properties and allow overrides
      Object.assign(this, AUTOCOMPLETER_TYPES[this.TYPE]);
      Object.assign(this, detail); // type, request_params
      this.primer = [];
      this.matches = [];
      this.prepareInputElement();
      this.scheduleRefresh(); // refresh the primer
    }
  }

  pulldownTargetConnected() {
    this.getRowHeight();
  }

  // Prepare input element: attach elements, set properties.
  prepareInputElement() {
    // console.log(elem)
    this.old_value = null;

    // Attach events
    this.addEventListeners();

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
  addEventListeners() {
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
        this.ourFocus(event);
        break;
      case "click":
        this.ourClick(event);
        break;
      case "blur":
        this.ourBlur(event);
        break;
      case "keydown":
        this.ourKeydown(event);
        break;
      case "keyup":
        this.ourKeyup(event);
        break;
      case "change":
        this.ourChange(event);
        break;
      case "beforeunload":
        this.ourUnload(event);
        break;
    }
  }

  // ------------------------------ Events ------------------------------

  // User pressed a key in the text field.
  ourKeydown(event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    // this.debug("keydown(" + key + ")");
    this.clearKey();
    this.focused = true;
    if (this.menu_up) {
      switch (key) {
        case this.EVENT_KEYS.esc:
          this.scheduleHide();
          this.menu_up = false;
          break;
        case this.EVENT_KEYS.tab:
        case this.EVENT_KEYS.return:
          event.preventDefault();
          if (this.current_row >= 0)
            this.selectRow(this.current_row - this.scroll_offset);
          break;
        case this.EVENT_KEYS.home:
          this.goHome();
          break;
        case this.EVENT_KEYS.end:
          this.goEnd();
          break;
        case this.EVENT_KEYS.pageup:
          this.pageUp();
          this.scheduleKey(this.pageUp);
          break;
        case this.EVENT_KEYS.up:
          this.arrowUp();
          this.scheduleKey(this.arrowUp);
          break;
        case this.EVENT_KEYS.down:
          this.arrowDown();
          this.scheduleKey(this.arrowDown);
          break;
        case this.EVENT_KEYS.pagedown:
          this.pageDown();
          this.scheduleKey(this.pageDown);
          break;
        default:
          this.current_row = -1;
          break;
      }
    }
    if (this.menu_up && this.isHotKey(key) &&
      !(key == 9 || this.current_row < 0))
      return false;
    return true;
  }

  // Need to prevent these keys from being processed by form.
  ourKeypress(event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    // this.debug("keypress(key=" + key + ", menu_up=" + this.menu_up + ", hot=" + this.isHotKey(key) + ")");
    if (this.menu_up && this.isHotKey(key) &&
      !(key == 9 || this.current_row < 0))
      return false;
    return true;
  }

  // User has released a key.
  ourKeyup(event) {
    // this.debug("keyup()");
    this.clearKey();
    this.ourChange(true);
    return true;
  }

  // Input field has changed.
  ourChange(do_refresh) {
    const old_val = this.old_value;
    const new_val = this.inputTarget.value;
    // this.debug("ourChange(" + this.inputTarget.value + ")");
    if (new_val != old_val) {
      this.old_value = new_val;
      if (do_refresh)
        this.scheduleRefresh();
    }
  }

  // User clicked into text field.
  ourClick(event) {
    if (this.ACT_LIKE_SELECT)
      this.scheduleRefresh();
    return false;
  }

  // User entered text field.
  ourFocus(event) {
    // this.debug("ourFocus()");
    if (!this.ROW_HEIGHT)
      this.getRowHeight();
    this.focused = true;
  }

  // User left the text field.
  ourBlur(event) {
    // this.debug("ourBlur()");
    this.scheduleHide();
    this.focused = false;
  }

  // User has navigated away from page.
  ourUnload() {
    // If native browser autocomplete is turned off, browsers like chrome
    // and firefox will not remember the value of fields when you go back.
    // This hack re-enables native autocomplete before leaving the page.
    // [This only works for firefox; should work for chrome but doesn't.]
    this.inputTarget.setAttribute("autocomplete", "on");
    return false;
  }

  // Prevent these keys from propagating to the input field.
  isHotKey(key) {
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
  scheduleRefresh() {
    this.verbose("scheduleRefresh()");
    this.clearRefresh();
    this.refresh_timer = window.setTimeout((() => {
      this.verbose("doing_refresh()");
      // this.debug("refresh_timer(" + this.inputTarget.value + ")");
      this.old_value = this.inputTarget.value;
      if (this.AJAX_URL)
        this.refreshPrimer();
      this.populateMatches();
      this.drawPulldown();
    }), this.REFRESH_DELAY * 1000);
  }

  // Schedule pulldown to be hidden if nothing happens in the meantime.
  scheduleHide() {
    this.clearHide();
    this.hide_timer = setTimeout(this.hidePulldown.bind(this), this.HIDE_DELAY * 1000);
  }

  // Schedule a method to be called after key stays pressed for some time.
  scheduleKey(action) {
    this.clearKey();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.scheduleKey2(action);
    }).bind(this), this.KEY_DELAY_1 * 1000);
  }
  scheduleKey2(action) {
    this.clearKey();
    this.key_timer = setTimeout((function () {
      action.call(this);
      this.scheduleKey2(action);
    }).bind(this), this.KEY_DELAY_2 * 1000);
  }

  // Clear refresh timer.
  clearRefresh() {
    if (this.refresh_timer) {
      clearTimeout(this.refresh_timer);
      this.refresh_timer = null;
    }
  }

  // Clear hide timer.
  clearHide() {
    if (this.hide_timer) {
      clearTimeout(this.hide_timer);
      this.hide_timer = null;
    }
  }

  // Clear key timer.
  clearKey() {
    if (this.key_timer) {
      clearTimeout(this.key_timer);
      this.key_timer = null;
    }
  }

  // ------------------------------ Cursor ------------------------------

  // Move cursor up or down some number of rows.
  pageUp() { this.moveCursor(-this.PAGE_SIZE); }
  pageDown() { this.moveCursor(this.PAGE_SIZE); }
  arrowUp() { this.moveCursor(-1); }
  arrowDown() { this.moveCursor(1); }
  goHome() { this.moveCursor(-this.matches.length) }
  goEnd() { this.moveCursor(this.matches.length) }
  moveCursor(rows) {
    this.verbose("moveCursor()");
    const old_row = this.current_row,
      old_scr = this.scroll_offset;
    let new_row = old_row + rows,
      new_scr = old_scr;

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
    if (new_row >= new_scr + this.PULLDOWN_SIZE)
      new_scr = new_row - this.PULLDOWN_SIZE + 1;

    // Update if something changed.
    if (new_row != old_row || new_scr != old_scr) {
      this.scroll_offset = new_scr;
      this.drawPulldown();
    }
  }

  // Mouse has moved over a menu item.
  highlightRow(new_hl) {
    this.verbose("highlightRow()");
    const rows = this.listTarget.children,
      old_hl = this.current_highlight;

    this.current_highlight = new_hl;
    this.current_row = this.scroll_offset + new_hl;

    if (old_hl != new_hl) {
      if (old_hl >= 0)
        rows[old_hl].classList.remove(this.HOT_CLASS);
      if (new_hl >= 0)
        rows[new_hl].classList.add(this.HOT_CLASS);
    }
    this.inputTarget.focus();
    this.updateWidth();
  }

  // Called when users scrolls via scrollbar.
  scrollList() {
    this.verbose("scrollList()");
    const old_scr = this.scroll_offset,
      new_scr = Math.round(this.pulldownTarget.scrollTop / this.ROW_HEIGHT),
      old_row = this.current_row;
    let new_row = this.current_row;

    if (new_row < new_scr)
      new_row = new_scr;
    if (new_row >= new_scr + this.PULLDOWN_SIZE)
      new_row = new_scr + this.PULLDOWN_SIZE - 1;
    if (new_row != old_row || new_scr != old_scr) {
      this.current_row = new_row;
      this.scroll_offset = new_scr;
      this.drawPulldown();
    }
  }

  // User selects a value, either pressing tab/return or clicking on an option.
  // Argument needed is the index of the row, not the <li> element. This method
  // may be called from a Stimulus target action or a listener in this class, so
  // the index may be an integer, or have to be derived from the event.target.
  selectRow(idx) {
    this.verbose("selectRow()");
    if (idx instanceof Event)
      idx = parseInt(idx.target.parentElement.dataset.row);

    // const old_val = this.inputTarget.value;
    let new_val = this.matches[this.scroll_offset + idx];
    // Close pulldown unless the value the user selected uncollapses into a set
    // of new options.  In that case schedule a refresh and leave it up.
    if (this.COLLAPSE > 0 &&
      (new_val.match(/ /g) || []).length < this.COLLAPSE) {
      new_val += ' ';
      this.scheduleRefresh();
    } else {
      this.scheduleHide();
    }
    this.inputTarget.focus();
    this.focused = true;
    this.inputTarget.value = new_val;
    this.setSearchToken(new_val);
    this.ourChange(false);
  }

  // ------------------------------ Pulldown ------------------------------

  // The pulldownTarget is printed in the document already. This measures
  // the row height when it becomes available. Creates a test row by cloning
  // the elements and adding text, which gives the correct height.
  getRowHeight() {
    const div = document.createElement('div'),
      ul = this.listTarget.cloneNode(false),
      li = this.listTarget.children[0].cloneNode(true),
      a = li.children[0];

    div.classList.add('test');
    a.innerHTML = 'test';
    ul.appendChild(li);
    div.appendChild(ul);
    document.body.appendChild(div);
    this.temp_row = div;
    this.setRowHeight();
  }

  setRowHeight() {
    if (this.temp_row) {
      this.ROW_HEIGHT = this.temp_row.offsetHeight;
      if (!this.ROW_HEIGHT) {
        this.setRowHeight();
      } else {
        document.body.removeChild(this.temp_row);
        this.temp_row = null;
      }
    }
  }

  // The pulldown is a "virtual list": the <div> contains a <ul> that has only
  // {PULLDOWN_SIZE} (10) <li> elements, but added height and margin to make the
  // element seem "scrollable" within the outer <div>. As the user scrolls, the
  // content of the items is hot-swapped-in from the full `this.matches` list,
  // kept in browser memory, and the <ul> top margin and height are adjusted
  // accordingly. This sleight of hand keeps far fewer elements in the DOM, and
  // is essential for making the page responsive.
  drawPulldown() {
    this.verbose("drawPulldown()");
    const rows = this.listTarget.children,
      size = this.PULLDOWN_SIZE,
      scroll = this.scroll_offset,
      cur = this.current_row,
      matches = this.matches;

    if (this.log) {
      this.debug(
        "Redraw: matches=" + matches.length + ", scroll=" + scroll + ", cursor=" + cur
      );
    }

    // Get row height if haven't been able to yet.
    this.getRowHeight();
    if (rows.length) {
      this.updateRows(rows, matches, size, scroll);
      this.highlightNewRow(rows, cur, size, scroll)
      this.makePulldownVisible(matches, size, scroll)
    }

    // Make sure input focus stays on text field!
    this.inputTarget.focus();
  }

  // This function swaps out the innerHTML of the items from the `matches` array
  // as needed, as the user scrolls.
  updateRows(rows, matches, size, scroll) {
    let i, text, stored;
    for (i = 0; i < size; i++) {
      let row = rows.item(i);
      let link = row.children[0];
      text = link.innerHTML;
      if (i + scroll < matches.length) {
        stored = this.escapeHTML(matches[i + scroll]);
        if (text != stored) {
          // if (text == '')
          //   row.style.display = 'block';
          link.innerHTML = stored;
        }
      } else {
        if (text != '') {
          link.innerHTML = '';
          // row.style.display = 'none';
        }
      }
    }
  }

  // Highlight that row.
  highlightNewRow(rows, cur, size, scroll) {
    const old_hl = this.current_highlight;
    let new_hl = cur - scroll;

    if (new_hl < 0 || new_hl >= size)
      new_hl = -1;
    this.current_highlight = new_hl;
    if (new_hl != old_hl) {
      if (old_hl >= 0)
        rows[old_hl].classList.remove(this.HOT_CLASS);
      if (new_hl >= 0)
        rows[new_hl].classList.add(this.HOT_CLASS);
    }
  }

  // Make pulldown visible if nonempty. Positioning currently depends on
  // Bootstrap classes: the .dropdown-menu will be positioned relative to the
  // wrapping .form-group which must have either class .position-relative or
  // .dropdown
  makePulldownVisible(matches, size, scroll) {
    const pulldown = this.pulldownTarget,
      list = this.listTarget;

    if (matches.length > 0) {
      // console.log("Matches:" + matches)
      // Set height of pulldown.
      pulldown.style.overflowY = matches.length > size ? "scroll" : "hidden";
      pulldown.style.height = this.ROW_HEIGHT *
        (size < matches.length - scroll ? size : matches.length - scroll) +
        "px";
      // Set margin-top and declared height of virtual list.
      list.style.marginTop = this.ROW_HEIGHT * scroll + "px";
      list.style.height = this.ROW_HEIGHT * (matches.length - scroll) + "px";
      pulldown.scrollTo({ top: this.ROW_HEIGHT * scroll });

      // Set width of pulldown.
      this.setWidth();
      this.updateWidth();

      // Only show pulldown if it is nontrivial, i.e., show an option other than
      // the value that's already in the text field. If wrapping div is
      // .dropdown, we can classList.add('.open') instead of
      // style.display = 'block'
      if (matches.length > 1 || this.inputTarget.value != matches[0]) {
        this.clearHide();
        this.wrapTarget?.classList?.add('open');
        this.menu_up = true;
      } else {
        hidePulldown();
      }
    } else {
      // Hide the pulldown if it's empty now.
      this.hidePulldown();
    }
  }

  // Hide pulldown options.
  hidePulldown() {
    this.verbose("hidePulldown()");
    this.wrapTarget?.classList?.remove('open');
    this.menu_up = false;
  }

  // Update width of pulldown.
  updateWidth() {
    this.verbose("updateWidth()");
    let w = this.listTarget.offsetWidth;
    if (this.matches.length > this.PULLDOWN_SIZE)
      w += this.SCROLLBAR_WIDTH;
    if (this.current_width < w) {
      this.current_width = w;
      this.setWidth();
    }
  }

  // Set width of pulldown.
  setWidth() {
    this.verbose("setWidth()");
    const w1 = this.current_width;
    let w2 = w1;
    if (this.matches.length > this.PULLDOWN_SIZE)
      w2 -= this.SCROLLBAR_WIDTH;
    this.listTarget.style.minWidth = w2 + 'px';
  }

  // ------------------------------ Matches ------------------------------

  // Populate virtual list of `matches` from `primer`. This is sort of a query
  // after the query: the `primer` is like an alphabet-letter volume fetched
  // from ActiveRecord's encyclopedia of all possible records, and these
  // functions maintain the evolving `matches` list based on the user's input.
  // There are four strategies for refining the list, below.
  populateMatches() {
    this.verbose("populateMatches()");
    if (this.ACT_LIKE_SELECT)
      this.current_row = 0;

    // Remember which option used to be highlighted.
    const last = this.current_row < 0 ? null : this.matches[this.current_row];

    // Populate list of matches appropriately.
    if (this.ACT_LIKE_SELECT)
      this.populateSelect();
    else if (this.COLLAPSE > 0)
      this.populateCollapsed();
    else if (this.UNORDERED)
      this.populateUnordered();
    else
      this.populateNormal();

    // Sort and remove duplicates, unless it's already sorted.
    if (!this.ACT_LIKE_SELECT)
      this.matches = this.removeDups(this.matches.sort());
    // Try to find old highlighted row in new set of options.
    this.updateCurrentRow(last);
    // Reset width each time we change the options.
    this.current_width = this.inputTarget.offsetWidth;
  }

  // When "acting like a select" make it display all options in the
  // order given right from the moment they enter the field,
  // and pick the first one.
  populateSelect() {
    this.matches = this.primer;
    if (this.matches.length > 0)
      this.inputTarget.value = this.matches[0];
  }

  // Grab all matches, doing exact match, ignoring number of words.
  populateNormal() {
    const token = this.getSearchToken().normalize().toLowerCase(),
      // normalize the Unicode of each string in primer for search
      primer = this.primer.map((str) => { return str.normalize() }),
      matches = [];

    if (token != '') {
      for (let i = 0; i < primer.length; i++) {
        let s = primer[i + 1];
        if (s && s.length > 0 && s.toLowerCase().indexOf(token) >= 0) {
          matches.push(s);
        }
      }
    }
    this.matches = matches;
  }

  // Grab matches ignoring order of words.
  populateUnordered() {
    // regularize spacing in the input
    const token = this.getSearchToken().normalize().toLowerCase().
      replace(/^ */, '').replace(/  +/g, ' '),
      // get the separate words as tokens
      tokens = token.split(' '),
      // normalize the Unicode of each string in primer for search
      primer = this.primer.map((str) => { return str.normalize() }),
      matches = [];

    if (token != '' && primer.length > 1) {
      for (let i = 1; i < primer.length; i++) {
        let s = primer[i] || '',
          s2 = ' ' + s.toLowerCase() + ' ',
          k;
        // check each word in the primer entry for a matching word
        for (k = 0; k < tokens.length; k++) {
          if (s2.indexOf(' ' + tokens[k]) < 0) break;
        }
        if (k >= tokens.length) {
          matches.push(s);
        }
      }
    }
    this.matches = matches;
  }

  // Grab all matches, preferring the ones with no additional words.
  // Note: order must have genera first, then species, then varieties.
  populateCollapsed() {
    const token = this.getSearchToken().toLowerCase(),
      primer = this.primer,
      // make a lowercased duplicate of primer to regularize search
      primer_lc = this.primer.map((str) => { return str.toLowerCase() }),
      matches = [];

    if (token != '' && primer.length > 1) {
      let the_rest = (token.match(/ /g) || []).length >= this.COLLAPSE;

      for (let i = 1; i < primer_lc.length; i++) {
        if (primer_lc[i].indexOf(token) > -1) {
          let s = primer[i];
          if (s.length > 0) {
            if (the_rest || s.indexOf(' ', token.length) < token.length) {
              matches.push(s);
            } else if (matches.length > 1) {
              break;
            } else {
              if (matches[0] == token)
                matches.pop();
              matches.push(s);
              the_rest = true;
            }
          }
        }
      }
      if (matches.length == 1 &&
        (token == matches[0].toLowerCase() ||
          token == matches[0].toLowerCase() + ' '))
        matches.pop();
    }
    this.matches = matches;
  }

  // Remove duplicates from a sorted array.
  removeDups(list) {
    let i, j;
    for (i = 0, j = 1; j < list.length; j++) {
      if (list[j] != list[i])
        list[++i] = list[j];
    }
    if (++i < list.length)
      list.splice(i, list.length - i);
    return list;
  }

  // Look for 'token' in list of matches and highlight it,
  // otherwise highlight first match.
  updateCurrentRow(token) {
    this.verbose("updateCurrentRow()");
    const matches = this.matches,
      size = this.PULLDOWN_SIZE;
    let exact = -1,
      part = -1;

    if (token && token.length > 0) {
      for (let i = 0; i < matches.length; i++) {
        if (matches[i] == token) {
          exact = i;
          break;
        }
        if (matches[i] == token.substr(0, matches[i].length) &&
          (part < 0 || matches[i].length > matches[part].length))
          part = i;
      }
    }
    let new_row = exact >= 0 ? exact : part >= 0 ? part : -1;
    let new_scroll = this.scroll_offset;
    if (new_scroll > new_row)
      new_scroll = new_row;
    if (new_scroll > matches.length - size)
      new_scroll = matches.length - size;
    if (new_scroll < new_row - size + 1)
      new_scroll = new_row - size + 1;
    if (new_scroll < 0)
      new_scroll = 0;

    this.current_row = new_row;
    this.scroll_offset = new_scroll;
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
  getSearchToken() {
    const val = this.inputTarget.value;
    let token = val;

    // If we're only looking for whole words, don't make a request unless
    // trailing space or comma, indicating a user has finished typing a word.
    if (this.WHOLE_WORDS_ONLY && token.charAt(token.length - 1) != ',' &&
      token.charAt(token.length - 1) != ' ') {
      return '';
    }
    if (this.SEPARATOR) {
      const extents = this.searchTokenExtents();
      token = val.substring(extents.start, extents.end);
    }
    return token;
  }

  // Change the token under or immediately in front of the cursor.
  setSearchToken(new_val) {
    const old_str = this.inputTarget.value;
    if (this.SEPARATOR) {
      let new_str = "";
      const extents = this.searchTokenExtents();

      if (extents.start > 0)
        new_str += old_str.substring(0, extents.start);
      new_str += new_val;

      if (extents.end < old_str.length)
        new_str += old_str.substring(extents.end);
      if (old_str != new_str) {
        var old_scroll = this.inputTarget.offsetTop;
        this.inputTarget.value = new_str;
        this.setCursorPosition(this.inputTarget[0],
          extents.start + new_val.length);
        this.inputTarget.offsetTop = old_scroll;
      }
    } else {
      if (old_str != new_val)
        this.inputTarget.value = new_val;
    }
  }

  // Get index of first character and character after last of current token.
  searchTokenExtents() {
    const val = this.inputTarget.value;
    let start = val.lastIndexOf(this.SEPARATOR),
      end = val.length;

    if (start < 0)
      start = 0;
    else
      start += this.SEPARATOR.length;

    return { start, end };
  }

  // ------------------------------ Fetch matches ------------------------------

  // Send request for updated primer.
  refreshPrimer() {
    this.verbose("refreshPrimer()");

    // token may be refined within this function, so it's a variable.
    let token = this.getSearchToken().toLowerCase(),
      last_request = this.last_fetch_request;

    // Don't make request on empty string!
    if (!this.ACT_LIKE_SELECT && (!token || token.length < 1))
      return;

    // Don't repeat last request accidentally!
    if (last_request == token)
      return;

    // Memoize this condition, used twice:
    // "is the new search token an extension of the previous search string?"
    const new_val_refines_last_request =
      !this.WHOLE_WORDS_ONLY &&
      (last_request?.length < token.length) &&
      (last_request == token.substr(0, last_request?.length));

    // No need to make more constrained request if we got all results last time.
    if (!this.last_fetch_incomplete &&
      last_request && (last_request.length > 0) &&
      new_val_refines_last_request)
      return;

    // If a less constrained request is pending, wait for it to return before
    // refining the request, just in case it returns complete results
    // (rendering the more refined request unnecessary).
    if (this.fetch_request && new_val_refines_last_request)
      return;

    if (token.length > this.MAX_STRING_LENGTH)
      token = token.substr(0, this.MAX_STRING_LENGTH);

    // If we're only looking for whole words, strip off trailing space or comma
    if (this.WHOLE_WORDS_ONLY) {
      token = token.trim().replace(/,.*$/, '')
    }

    const query_params = { string: token, ...this.request_params }

    // If it's a param search, ignore the search token and return all results.
    if (this.ACT_LIKE_SELECT) { query_params["all"] = true; }
    if (this.WHOLE_WORDS_ONLY) { query_params["whole"] = true; }

    // Make request.
    this.sendFetchRequest(query_params);
  }

  // Send fetch request for more matching strings.
  async sendFetchRequest(query_params) {
    this.verbose("sendFetchRequest()");

    if (this.log) {
      this.debug("Sending fetch request: " + query_params.string + "...");
    }

    const url = this.AJAX_URL + this.TYPE,
      abort_controller = new AbortController();

    this.last_fetch_request = query_params.string;
    if (this.fetch_request)
      abort_controller.abort();

    const response = await get(url, {
      signal: abort_controller.signal,
      query: query_params,
      responseKind: "json"
    });

    if (response.ok) {
      const json = await response.json
      if (json) {
        this.fetch_request = response
        this.processFetchResponse(json)
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
  processFetchResponse(new_primer) {
    this.verbose("processFetchResponse()");

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
        // just in case we need to refine the request due to
        // activity while waiting for this response
        this.scheduleRefresh();
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
      this.populateMatches();
      this.drawPulldown();
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
    // document.getElementById("log").
    //   insertAdjacentText("beforeend", str + "<br/>");
  }

  verbose(str) {
    // console.log(str);
    // document.getElementById("log").
    //   insertAdjacentText("beforeend", str + "<br/>");
  }
}
