import { Controller } from "@hotwired/stimulus"
import { mo_form_utilities, EVENT_KEYS } from "src/mo_form_utilities"
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
  // what type of autocompleter, corresponds to a subclass of `Autocomplete`
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
  REFRESH_DELAY: 0.33,
  // how long to wait before hiding pulldown (seconds)
  HIDE_DELAY: 0.50,
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
// Model is used for the field identifier in the hidden input.
const AUTOCOMPLETER_TYPES = {
  clade: {
    model: 'name'
  },
  herbarium: { // params[:user_id] handled in controller
    UNORDERED: true,
    model: 'herbarium'
  },
  location: { // params[:format] handled in controller
    ACT_LIKE_SELECT: false,
    AUTOFILL_SINGLE_MATCH: false,
    UNORDERED: true,
    model: 'location',
    // create_link: '/locations/new?where='
  },
  location_containing: { // params encoded from dataset
    ACT_LIKE_SELECT: true,
    AUTOFILL_SINGLE_MATCH: true,
    model: 'location',
    // create_link: '/locations/new?where='
  },
  location_google: { // params encoded from dataset
    ACT_LIKE_SELECT: true,
    AUTOFILL_SINGLE_MATCH: false,
    model: 'location', // because it's creating a location
  },
  name: {
    COLLAPSE: 1,
    model: 'name'
  },
  project: {
    UNORDERED: true,
    model: 'project'
  },
  region: {
    UNORDERED: true,
    WHOLE_WORDS_ONLY: true,
    model: 'location'
  },
  species_list: {
    UNORDERED: true,
    model: 'species_list'
  },
  user: {
    UNORDERED: true,
    model: 'user'
  }
}

// These are internal state variables the user should leave alone.
const INTERNAL_OPTS = {
  ROW_HEIGHT: null,      // height of a ul li row in pixels (determined below)
  SCROLLBAR_WIDTH: null, // width of scrollbar in browser (determined below)
  focused: false,        // is user in text field?
  menu_up: false,        // is pulldown visible?
  old_value: null,       // previous value of input field
  stored_id: 0,          // id of selected option
  stored_data: { id: 0 }, // data of selected option
  stored_ids: [],        // ids of selected options (for multiple - no data)
  keepers: [],           // data of selected options (for multiple)
  primer: [],            // a server-supplied list of many options
  matches: [],           // list of options currently showing
  current_row: -1,       // index of option currently highlighted (0 = none)
  current_value: null,   // value currently highlighted (null = none)
  current_highlight: -1, // row of view highlighted (-1 = none)
  current_width: 0,      // current width of menu
  scroll_offset: 0,      // scroll offset
  last_fetch_request: '', // last fetch request we got results for
  last_fetch_params: '', // last fetch request we sent, minus the string
  last_fetch_incomplete: true, // did we get all the results we requested?
  fetch_request: null,   // ajax request while underway
  refresh_timer: null,   // timer used to delay update after typing
  hide_timer: null,      // timer used to delay hiding of pulldown
  key_timer: null,       // timer used to emulate key repeat
  data_timer: null,      // timer used to delay hidden data updated event (map)
  create_timer: null,    // timer used to delay create link
  log: false,            // log debug messages to console?
  has_create_link: false // pulldown currently has link to create new record
}

// Connects to data-controller="autocompleter"
export default class extends Controller {
  // The root element should usually be the .form-group wrapping the <input>.
  // The select target is not the <input> element, but a <select> that can
  // swap out the autocompleter type. The <input> element is its target.
  static targets = ["input", "select", "pulldown", "list", "hidden", "wrap",
    "createBtn", "hasIdIndicator", "keepBtn", "editBtn", "mapWrap", "collapseFields"]
  static outlets = ["map"]

  initialize() {
    Object.assign(this, DEFAULT_OPTS);

    // Check the type of autocompleter set on the root or input element
    this.TYPE = this.element.dataset.type ?? this.inputTarget.dataset.type;
    if (!AUTOCOMPLETER_TYPES.hasOwnProperty(this.TYPE))
      alert("MOAutocompleter: Invalid type: \"" + this.TYPE + "\"");

    // Only allow types we can handle:
    Object.assign(this, AUTOCOMPLETER_TYPES[this.TYPE]);
    Object.assign(this, INTERNAL_OPTS);

    // Does this autocompleter affect a map?
    this.hasMap = this.inputTarget.dataset.hasOwnProperty("mapTarget");
    this.hasGeocode = this.inputTarget.dataset.hasOwnProperty("geocodeTarget");

    // Assign the separator for multiple-record autocompleters
    this.SEPARATOR = this.element.dataset.separator;

    // Shared MO utilities, imported at the top:
    this.EVENT_KEYS = EVENT_KEYS;
    Object.assign(this, mo_form_utilities);
  }

  connect() {
    this.element.dataset.autocompleter = "connected";

    // Figure out a few browser-dependent dimensions.
    this.getScrollBarWidth;

    // Wrap is usually the root element with the controller, a ".form-group".
    // But it could have different markup.
    if (!this.hasWrapTarget) {
      alert("MOAutocompleter: needs a wrapping div with class: \"" +
        this.WRAP_CLASS + "\"");
    }

    this.default_action =
      this.listTarget?.children[0]?.children[0]?.dataset.action;
    // Attach events, etc. to input element.
    this.prepareInputElement();
  }

  // Reinitialize autocompleter type (and properties). Callable externally. For
  // example, `swap` may be called from a change event dispatched by another
  // controller: `data-action: "map:pointChanged->autocompleter#swap"`. The
  // form-exif and geocode/map controllers use their autocompleterOutlet to call
  // swap() directly, when changing lat/lngs. We need both - when form-exif
  // updates the lat/lng inputs programmatically, it's not caught as a `change`
  // by geocode/map. (Also, geocode/map only fires its swap after buffering.)
  //
  // Callers of swap() should pass a detail object with a type property.
  // Example: `event: { detail: { type, request_params: { lat, lng } } }`.
  // However, the caller may not pass a type, or it may be the same as the
  // current type. Re-initializing the current type is ok, often means we need
  // to refresh the primer (as with location_containing a changed lat/lng).
  //
  swap({ detail }) {
    let type;
    if (this.hasSelectTarget) {
      type = this.selectTarget.value;
    } else if (detail?.hasOwnProperty("type")) {
      type = detail.type;
    }
    if (type == undefined) { return; }

    let location = false;
    if (detail?.hasOwnProperty("request_params") &&
      detail.request_params?.hasOwnProperty("lat") &&
      detail.request_params?.hasOwnProperty("lng")) {
      location = detail.request_params;
    }

    if (!AUTOCOMPLETER_TYPES.hasOwnProperty(type)) {
      alert("MOAutocompleter: Invalid type: \"" + type + "\"");
    } else {
      this.verbose("autocompleter:swap " + type);
      this.TYPE = type;
      this.element.setAttribute("data-type", type)
      // add dependent properties and allow overrides
      Object.assign(this, AUTOCOMPLETER_TYPES[type]);
      // sanity check to show which autocompleter is currently on the element
      Object.assign(this, detail); // type, request_params
      this.primer = [];
      this.matches = [];
      this.stored_data = { id: 0 };
      this.keepers = [];
      this.last_fetch_params = '';
      this.prepareInputElement();
      this.prepareHiddenInput();
      if (!this.hasEditBtnTarget ||
        this.editBtnTarget?.classList?.contains('d-none')) {
        this.clearHiddenId();
      }
      this.constrainedSelectionUI(location);
    }
  }

  // Depending on the type of autocompleter, the UI may need to change.
  // detail may also contain request_params for lat/lng.
  constrainedSelectionUI(location = false) {
    if (this.TYPE === "location_google") {
      this.verbose("autocompleter: swapped to location_google");
      this.element.classList.add('create');
      this.element.classList.remove('offer-create');
      this.element.classList.remove('constrained');
      if (this.hasMapWrapTarget) {
        this.mapWrapTarget.classList.remove('d-none');
      } else {
        this.verbose("autocompleter: no map wrap");
      }
      this.activateMapOutlet(location);
    } else if (this.ACT_LIKE_SELECT) {
      this.verbose("autocompleter: swapped to ACT_LIKE_SELECT");
      this.deactivateMapOutlet();
      // primer is not based on input, so go ahead and request from server.
      this.focused = true; // so it will draw the pulldown immediately
      this.refreshPrimer(); // directly refresh the primer w/request_params
      this.element.classList.add('constrained');
      this.element.classList.remove('create');
    } else {
      this.verbose("autocompleter: swapped regular");
      this.deactivateMapOutlet();
      this.scheduleRefresh();
      this.element.classList.remove('constrained', 'create');
    }
  }

  swapCreate() {
    this.swap({ detail: { type: "location_google" } });
  }

  leaveCreate() {
    if (!(['location_google'].includes(this.TYPE) && this.hasMapOutlet)) return;

    this.verbose("autocompleter: leaveCreate()");
    const location = this.mapOutlet.validateLatLngInputs(false);
    // Will swap to location, or location_containing if lat/lngs are present
    if (this.mapOutlet.ignorePlaceInput !== true) {
      this.mapOutlet.sendPointChanged(location);
    }
  }

  // Connects autocompleter to map controller to call its methods
  activateMapOutlet(location = false) {
    if (!this.hasMapOutlet) {
      this.verbose("autocompleter: no map outlet");
      return;
    }

    this.verbose("autocompleter:activateMapOutlet()");
    // open the map if not already open
    if (!this.mapOutlet.opened && this.mapOutlet.hasToggleMapBtnTarget) {
      this.verbose("autocompleter: open map");
      this.mapOutlet.toggleMapBtnTarget.click();
    }
    // set the map type so box is editable
    this.mapOutlet.map_type = "hybrid"; // only if location_google
    // set the map to stop ignoring place input
    this.mapOutlet.ignorePlaceInput = false;

    // Often, this swap to location_google is for geolocating place_names and
    // should pay attention to text only. But in some cases the swap (e.g., from
    // form-exif) sends request_params lat/lng, so geocode when switching.
    if (location) {
      // this.mapOutlet.geocodeLatLng(location);
      this.mapOutlet.tryToGeocode();
    }
  }

  deactivateMapOutlet() {
    if (!this.hasMapOutlet) return;

    this.verbose("autocompleter: deactivateMapOutlet()");
    if (this.mapOutlet.rectangle) this.mapOutlet.clearRectangle();
    this.mapOutlet.map_type = "observation";
    // if (this.mapOutlet.rectangle) this.mapOutlet.rectangle.setEditable(false);

    this.mapOutlet.northInputTarget.value = '';
    this.mapOutlet.southInputTarget.value = '';
    this.mapOutlet.eastInputTarget.value = '';
    this.mapOutlet.westInputTarget.value = '';
    this.mapOutlet.highInputTarget.value = '';
    this.mapOutlet.lowInputTarget.value = '';
  }

  // pulldownTargetConnected() {
  //   this.getRowHeight();
  // }

  // Prepare input element: attach elements, set properties.
  prepareInputElement() {
    // console.log(elem)
    this.old_value = null;

    // Attach events
    this.addEventListeners();

    // Check the input for prefilled values in a form
    if (this.inputTarget.value.length > 0) {
      // this.scheduleRefresh(); // matches may not be populated
      this.updateHiddenId();
    }

    const hidden_id = parseInt(this.hiddenTarget.value);
    this.cssHasIdOrNo(hidden_id);
  }

  // When swapping autocompleter types, swap the hidden input identifiers.
  // and save the current value of the hidden input.
  prepareHiddenInput() {
    const identifier = AUTOCOMPLETER_TYPES[this.TYPE]['model'] + '_id',
      form = this.hiddenTarget.name.split('[')[0];

    if (form === "") {
      this.hiddenTarget.name = identifier;
      this.hiddenTarget.id = identifier;
    } else {
      this.hiddenTarget.name = form + '[' + identifier + ']';
      this.hiddenTarget.id = form + "_" + identifier;
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
    this.inputTarget.addEventListener("input", this);
    this.inputTarget.addEventListener("change", this);
    // Turbo: check this. May need to be turbo.before_render or before_visit
    window.addEventListener("beforeunload", this);
  }

  // In a JS class, `handleEvent` is a special function name. If it has this
  // function, you can designate the class itself as the handler for multiple
  // events. Stimulus uses `handleEvent` under the hood.
  // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
  handleEvent(event) {
    // console.log("autocompleter: " + event.type)
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
      case "input":
        this.ourChange(true);
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
    const old_value = this.old_value;
    const new_value = this.inputTarget.value;
    // this.debug("ourChange(" + this.inputTarget.value + ")");
    // console.log("ourChange(" + this.inputTarget.value + ")");
    if (new_value.length == 0) {
      this.cssCollapseFields();
      this.clearHiddenId();
      this.leaveCreate();
      if (this.SEPARATOR) { this.removeUnusedKeepersAndIds(); }
    } else {
      this.cssUncollapseFields();
      if (new_value != old_value) {
        this.old_value = new_value;
        if (do_refresh) {
          this.verbose("autocompleter:ourChange()");
          this.scheduleRefresh();
        }
      }
    }
  }

  // User clicked into text field.
  ourClick(event) {
    if (this.ACT_LIKE_SELECT)
      this.verbose("autocompleter:ourClick()");
    this.scheduleRefresh();
    return false;
  }

  // User entered text field.
  ourFocus(event) {
    // this.debug("autocompleter:ourFocus()");
    if (!this.ROW_HEIGHT)
      this.getRowHeight();
    this.focused = true;
  }

  // User left the text field.
  ourBlur(event) {
    // this.debug("autocompleter:ourBlur()");
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

  cssCollapseFields() {
    if (!this.hasCollapseFieldsTarget) return;

    $(this.collapseFieldsTarget).collapse('hide');
  }

  cssUncollapseFields() {
    if (!this.hasCollapseFieldsTarget) return;

    $(this.collapseFieldsTarget).collapse('show');
  }

  // ------------------------------ Timers ------------------------------

  // Schedule matches to be recalculated from primer, or even primer refreshed,
  // after a polite delay.
  scheduleRefresh() {
    if (this.TYPE === "location_google") {
      this.scheduleGoogleRefresh();
    } else {
      this.verbose("autocompleter:scheduleRefresh()");
      this.clearRefresh();
      this.refresh_timer = setTimeout((() => {
        this.verbose("autocompleter: doing refreshPrimer()");
        // this.debug("refresh_timer(" + this.inputTarget.value + ")");
        this.old_value = this.inputTarget.value;
        // async, anything after this executes immediately
        if (this.AJAX_URL) { this.refreshPrimer(); }
        // still necessary if primer unchanged, as likely
        this.populateMatches();
        if (!this.AUTOFILL_SINGLE_MATCH || this.matches.length > 1) {
          this.drawPulldown();
        }
      }), this.REFRESH_DELAY * 1000);
    }
  }

  // This should only refresh the primer if we don't have lat/lngs - the lat/lng
  // effectively keeps the selections. If we refresh on the string, we'll get
  // stuck with a single geolocatePlaceName result, which is only ever one.
  // If we don't have lat/lngs, just draw the pulldown.
  scheduleGoogleRefresh() {
    if (this.hasMapOutlet &&
      this.mapOutlet.hasLatInputTarget &&
      this.mapOutlet.hasLngInputTarget &&
      this.mapOutlet?.latInputTarget.value &&
      this.mapOutlet?.lngInputTarget.value) {
      this.drawPulldown();
      return;
    }

    this.verbose("autocompleter:scheduleGoogleRefresh()");
    this.clearRefresh();
    this.refresh_timer = setTimeout((() => {
      const current_input = this.inputTarget.value;
      this.verbose("autocompleter: doing google refresh");
      this.verbose(current_input);
      this.old_value = current_input;
      // async, anything after this executes immediately
      // STORE AND COMPARE SEARCH STRING. Otherwise we're doing double lookups
      if (this.hasGeocodeOutlet) {
        this.geocodeOutlet.tryToGeolocate(current_input);
      } else if (this.hasMapOutlet) {
        this.mapOutlet.tryToGeolocate(current_input);
      }
      // still necessary if primer unchanged, as likely?
      // this.populateMatches();
      // this.drawPulldown();
    }), this.REFRESH_DELAY * 1000);
  }

  // Schedule pulldown to be hidden if nothing happens in the meantime.
  scheduleHide() {
    this.clearHide();
    this.hide_timer = setTimeout(
      this.hidePulldown.bind(this), this.HIDE_DELAY * 1000
    );
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
    // if (this.refresh_timer) {
    clearTimeout(this.refresh_timer);
    //   this.refresh_timer = null;
    // }
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
    // this.verbose("autocompleter: moveCursor()");
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

  // User has tabbed or arrowDown/Up to a menu item.
  // (mouseover handled by CSS)
  highlightRow(new_hl) {
    // this.verbose("autocompleter: highlightRow()");
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
    this.verbose("autocompleter:scrollList()");
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
    // this.verbose("autocompleter: selectRow()");
    if (this.matches.length === 0) return;

    if (idx instanceof Event) { idx = parseInt(idx.target.dataset.row); }
    let new_match = this.matches[this.scroll_offset + idx],
      new_val = new_match.name;
    // Close pulldown unless the value the user selected uncollapses into a set
    // of new options.  In that case schedule a refresh and leave it up.
    if (this.COLLAPSE > 0 &&
      (new_val.match(/ /g) || []).length < this.COLLAPSE) {
      new_val += ' ';
      this.verbose("gotcha!()");
      this.scheduleRefresh();
    } else {
      this.scheduleHide();
    }
    this.assignHiddenId(new_match);
    this.setSearchToken(new_val); // updates input field
    this.ourChange(false);
    this.inputTarget.focus();
    this.focused = true;
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

    Object.keys(ul.dataset).forEach(dataKey => {
      delete ul.dataset[dataKey];
    });
    Object.keys(a.dataset).forEach(dataKey => {
      delete a.dataset[dataKey];
    });

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
  // Called after populateMatches()
  drawPulldown() {
    // this.verbose("autocompleter: drawPulldown()");
    const rows = this.listTarget.children,
      scroll = this.scroll_offset;

    if (this.log) {
      this.debug(
        "Redraw: matches=" + this.matches.length +
        ", scroll=" + scroll + ", cursor=" + this.current_row
      );
    }
    // Get row height if haven't been able to yet.
    if (!this.ROW_HEIGHT)
      this.getRowHeight();
    if (rows.length) {
      this.updateRows(rows);
      this.highlightNewRow(rows);
      this.makePulldownVisible();
    }
    // Make sure input focus stays on text field!
    this.inputTarget.focus();
  }

  // This function swaps out the innerHTML of the items from the `matches` array
  // as needed, as the user scrolls. rows are the <li> elements in the pulldown.
  //  Called from drawPulldown().
  updateRows(rows) {
    // this.verbose("autocompleter: updateRows(rows)");
    let i, text;
    for (i = 0; i < this.PULLDOWN_SIZE; i++) {
      let row = rows.item(i),
        link = row.children[0];
      text = link.innerHTML;
      if (i === 0) link.setAttribute('href', "#");
      if (i + this.scroll_offset < this.matches.length) {
        this.updateRow(i, link, text);
      } else {
        this.emptyRow(i, link, text);
      }
    }
    // If no matches, show a link to create a new record.
    // if (this.matches.length === 1 && this.has_create_link === true) {
    //   this.addCreateLink(rows.item(0));
    // }
  }

  // Needs to restore href and data-action if they were changed.
  updateRow(i, link, text) {
    const { name, ...new_data } = this.matches[i + this.scroll_offset];
    let stored = this.escapeHTML(name);

    if (text != stored) {
      if (stored === " ") stored = "&nbsp;";
      link.innerHTML = stored;
      // Assign the dataset of matches[i + this.scroll_offset], minus name
      Object.keys(new_data).forEach(key => {
        link.dataset[key] = new_data[key];
      });
      if (i === 0) link.dataset.action = this.default_action;
      delete this.dataset?.turboStream;
      link.classList.remove('d-none');
    }
  }

  emptyRow(i, link, text) {
    if (text != '') {
      link.innerHTML = '';
      Object.keys(link.dataset).forEach(key => {
        if (!['row', 'action'].includes(key))
          delete link.dataset[key];
      });
      if (i === 0) link.dataset.action = this.default_action;
      link.classList.add('d-none');
    }
  }

  // Highlight that row (CSS only - does not populate hidden ID).
  //  Called from drawPulldown().
  highlightNewRow(rows) {
    // this.verbose("autocompleter: highlightNewRow(rows)");
    const old_hl = this.current_highlight;
    let new_hl = this.current_row - this.scroll_offset;

    if (new_hl < 0 || new_hl >= this.PULLDOWN_SIZE)
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
  // wrapping .form-group which must have class .dropdown.
  //  Called from drawPulldown().
  makePulldownVisible() {
    // this.verbose("autocompleter: makePulldownVisible()");
    const matches = this.matches,
      offset = this.scroll_offset,
      size = this.PULLDOWN_SIZE,
      row_height = this.ROW_HEIGHT,
      length_ahead = this.matches.length - this.scroll_offset,
      current_size = size < length_ahead ? size : length_ahead,
      overflow = this.matches.length > this.PULLDOWN_SIZE ? "scroll" : "hidden";

    if (matches.length > 0) {
      // console.log("Matches:" + matches)
      this.pulldownTarget.style.overflowY = overflow;
      // Set height of pulldown.
      this.pulldownTarget.style.height = row_height * current_size + "px";
      // Set margin-top and declared height of virtual list.
      this.listTarget.style.marginTop = row_height * offset + "px";
      this.listTarget.style.height = row_height * length_ahead + "px";
      this.pulldownTarget.scrollTo({ top: row_height * offset });

      // Set width of pulldown.
      this.setWidth();
      this.updateWidth();

      // Only show pulldown if it is nontrivial, i.e., has an option other than
      // the value that's already in the text field.
      if (matches.length > 1 || this.getSearchToken() != matches[0]['name']) {
        this.clearHide();
        this.wrapTarget?.classList?.add('open');
        this.menu_up = true;
      } else {
        this.hidePulldown();
      }
    } else {
      // Hide the pulldown if it's empty now.
      this.hidePulldown();
    }
  }

  // Hide pulldown options.
  hidePulldown() {
    // this.verbose("hidePulldown()");
    this.wrapTarget?.classList?.remove('open');
    this.menu_up = false;
  }

  // Update width of pulldown.
  updateWidth() {
    // this.verbose("updateWidth()");
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
    // this.verbose("setWidth()");
    const w1 = this.current_width;
    let w2 = w1;
    if (this.matches.length > this.PULLDOWN_SIZE)
      w2 -= this.SCROLLBAR_WIDTH;
    this.listTarget.style.minWidth = w2 + 'px';
  }

  // ------------------------------ Hidden IDs ------------------------------

  // Assign ID of any perfectly matching option, even if not expressly selected.
  // This guards against user selecting a match, then, say, deleting a letter
  // and retyping the letter. Without this, an exact match would lose its ID.
  // NOTE: Needs to handle multiple IDs when there is a separator.
  updateHiddenId() {
    this.verbose("autocompleter:updateHiddenId()");
    this.verbose("autocompleter:getSearchToken().trim(): ");
    this.verbose(this.getSearchToken().trim());
    // Fires on every change
    if (this.SEPARATOR) { this.removeUnusedKeepersAndIds(); }

    const perfect_match =
      this.matches.find((m) => m['name'] === this.getSearchToken().trim());

    if (perfect_match) {
      // only assign if it's not already assigned
      if (this.lastHiddenTargetValue() != perfect_match['id']) {
        this.assignHiddenId(perfect_match);
      }
    } else if (!this.ignoringTextInput() && this.matches.length > 0) {
      // Only clear if we have matches to validate against.
      // If matches haven't loaded yet, trust the form's prefilled hidden value.
      this.clearHiddenId();
    }
  }

  // Gets the most recent value in the hidden input, which may be an array.
  lastHiddenTargetValue() {
    if (this.SEPARATOR) {
      return this.hiddenTarget.value.split(",").pop();
    } else {
      this.hiddenTarget.value
    }
  }

  // Assigns not only the ID, but also any data attributes of selected row.
  // Data is stored as numbers and floats, not strings.
  assignHiddenId(match) {
    this.verbose("autocompleter:assignHiddenId()");
    this.verbose(match);
    if (!match) return;
    // Before we change the hidden input, store the old value(s) and data
    this.storeCurrentHiddenData();

    // update the new value of the hidden input, which casts it as a string.
    // Also sets data attributes.
    this.updateHiddenTargetValue(match); // converts to string
    // The indicator only relates to the most recent match when multiple
    this.cssHasIdOrNo(parseInt(match['id']));
    // This checks the hidden_data against the stored_data
    this.hiddenIdChanged();
  }

  // Note that we're making the hidden input the source of truth.
  // The autocompleter stored attributes are for comparing to the last value.
  updateHiddenTargetValue(match) {
    if (this.SEPARATOR) {
      this.updateHiddenTargetValueMultiple(match);
    } else {
      this.updateHiddenTargetValueSingle(match);
    }
  }

  // add the new id at the same index of the array as the search token.
  // Converts array back to string.
  updateHiddenTargetValueMultiple(match) {
    this.verbose("autocompleter:updateHiddenTargetValueMultiple()");
    let new_array = this.stored_ids,
      idx = this.getSearchTokenIndex(),
      { name, id } = match,
      new_data = { name, id };

    if (idx > -1) {
      new_array[idx] = parseInt(match['id']);
      this.hiddenTarget.value = new_array.join(",");
      this.keepers[idx] = new_data;
    }
  }

  updateHiddenTargetValueSingle(match) {
    this.verbose("autocompleter:updateHiddenTargetValueSingle()");
    this.hiddenTarget.value = match['id'];
    // assign the dataset of the selected row to the hidden input
    Object.keys(match).forEach(key => {
      // if (!['id', 'name'].includes(key))
      this.hiddenTarget.dataset[key] = match[key];
    });
  }

  // Clears not only the ID, but also any data attributes of selected row,
  // and for multiple value autocompleters, the most recent "keeper".
  clearHiddenId() {
    this.verbose("autocompleter:clearHiddenId()");
    // Before we change the hidden input, store the old value and data
    this.storeCurrentHiddenData();
    // Clears hidden_id and hidden field data attributes (except `target` atts).
    this.clearLastHiddenTargetValue();
    // This checks the hidden_data against the stored_data
    this.hiddenIdChanged();
    // Remove the green checkmark
    this.cssHasIdOrNo(null);
  }

  // Removes the last id in the hidden input (array as csv string)
  clearLastHiddenTargetValue() {
    this.verbose("autocompleter:clearLastHiddenTargetValue()");
    // If input is completely empty, clear everything regardless of SEPARATOR
    if (this.inputTarget.value.length === 0) {
      this.clearHiddenIdAndData();
      this.keepers = [];
    } else if (this.SEPARATOR) {
      this.clearLastHiddenIdAndKeeper();
    } else {
      this.clearHiddenIdAndData();
    }
  }

  // Multiple: We have to be careful here to delete only the id that is
  // at the same index as the search token. Otherwise it keeps deleting.
  clearLastHiddenIdAndKeeper() {
    this.verbose("autocompleter:clearLastHiddenIdAndKeeper()");
    // not worried about integers here
    let hidden_ids = this.hiddenIdsAsIntegerArray(),
      idx = this.getSearchTokenIndex();

    this.verbose("autocompleter:hidden_ids: ")
    this.verbose(JSON.stringify(hidden_ids));
    this.verbose("autocompleter:idx: ")
    this.verbose(idx);

    if (idx > -1 && hidden_ids.length > idx) {
      hidden_ids.splice(idx, 1);
      this.hiddenTarget.value = hidden_ids.join(",");
      // also clear the dataset
      if (this.keepers.length > idx) {
        this.verbose("autocompleter:keepers: ")
        this.verbose(JSON.stringify(this.keepers));
        this.keepers.splice(idx, 1);
      }
    }
  }

  clearHiddenIdAndData() {
    this.hiddenTarget.value = '';
    this.hiddenTarget.setAttribute('value', '');
    // clear the dataset also
    Object.keys(this.hiddenTarget.dataset).forEach(key => {
      if (!key.match(/Target/))
        delete this.hiddenTarget.dataset[key];
    });
  }

  // check if any names in `keepers` are not in the input values.
  // if so, remove them from the keepers and the hidden input.
  removeUnusedKeepersAndIds() {
    if (!this.SEPARATOR || this.keepers.length === 0) return;

    this.verbose("autocompleter:removeUnusedKeepersAndIds()");
    this.verbose("autocompleter:keepers: ")
    this.verbose(JSON.stringify(this.keepers));

    const input_names = this.getInputArray(),
      hidden_ids = this.hiddenIdsAsIntegerArray();
    this.verbose("autocompleter:input_names: ")
    this.verbose(JSON.stringify(input_names));
    this.verbose("autocompleter:hidden_ids: ")
    this.verbose(JSON.stringify(hidden_ids));

    this.keepers.filter((d) => !input_names.includes(d.name)).forEach((d) => {
      const idx = hidden_ids.indexOf(d.id);
      if (idx > -1) {
        hidden_ids.splice(idx, 1);
      }
      const kidx = this.keepers.indexOf(d);
      if (kidx > -1) {
        this.keepers.splice(kidx, 1);
      }
    });
    // update the hidden input
    this.hiddenTarget.value = hidden_ids.join(",");
    // also check for missing?
    this.addMissingKeepersAndIds(input_names);
  }

  // If the input names don't match what's stored in our keepers or hidden ids,
  // we need to add them in. NOTE: The fetch response that updates keepers and
  // ids expects for the keepers and ids to be the same length and at the same
  // index as the input names, so we can't just push things into arrays. We
  // need to arrange them at the right index for each existing keeper and id.
  // Account for pasting into an existing list.
  addMissingKeepersAndIds(input_names) {
    if (input_names.length == 0) return;

    this.verbose("autocompleter:addMissingKeepersAndIds()");
    // Prepare null values in the array where we need to add new keepers
    this.addMissingKeepers(input_names);
    // Do the same for the hidden IDs. Check these against the keeper ids.
    this.addMissingHiddenIds(input_names);

    // Now try to fetch records for the missing input names
    const missing = input_names.filter((n) => {
      return !this.keepers.map((d) => d.name).includes(n);
    });

    if (missing.length > 0) {
      this.fetchMissingRecords(missing);
    }
  }

  addMissingKeepers(input_names) {
    if (!(this.keepers.length < input_names.length)) return;

    const new_keepers = new Array(input_names.length).
      fill({ name: null, id: null });
    if (this.keepers.length > 0) {
      // Put current keepers in the right positions in the new array
      input_names.forEach((n, i) => {
        const idx = this.keepers.map((d) => d.name).indexOf(n);
        if (idx > -1) {
          new_keepers[i] = this.keepers[idx];
        }
      });
    }
    this.keepers = new_keepers;
  }

  addMissingHiddenIds(input_names) {
    const hidden_ids = this.hiddenIdsAsIntegerArray();
    if (!(hidden_ids.length < input_names.length)) return;

    const new_ids = new Array(input_names.length).fill(null);
    if (hidden_ids.length > 0) {
      // Put current ids in the right positions in the new array
      this.keepers.forEach((n, i) => {
        const idx = hidden_ids.indexOf(n.id);
        if (idx > -1) {
          new_ids[i] = hidden_ids[idx];
        }
      });
    }
    this.hiddenTarget.value = new_ids.join(",");
  }

  // Fetch records for the missing input names.
  fetchMissingRecords(missing) {
    this.verbose("autocompleter:fetchMissingRecords(missing): ")
    this.verbose(JSON.stringify(missing));
    // send these staggered so they don't cancel each other.
    missing.forEach((token, i) => {
      setTimeout(() => {
        this.matchOneToken(token);
      }, i * 450);
    });
  }
  // only clear if we're not in "ignorePlaceInput" mode
  ignoringTextInput() {
    if (!this.hasMapOutlet) return false;

    this.verbose("autocompleter:ignoringTextInput()");
    return this.mapOutlet.ignorePlaceInput;
  }

  // Respond to the state of the hidden input. Initially we may not have id, but
  // we also don't offer create until they've typed something.
  // The `keepBtn` is for freezing the current box so people can pick a point.
  // Otherwise you can't click a point inside the box.
  cssHasIdOrNo(hidden_id) {
    this.verbose("autocompleter:cssHasIdOrNo()");

    if (hidden_id && !isNaN(hidden_id) && hidden_id != 0) {
      this.wrapTarget.classList.add('has-id');
      this.wrapTarget.classList.remove('offer-create');
      if (this.hasKeepBtnTarget) {
        this.keepBtnTarget.classList.remove("d-none");
      }
      // Directly show indicator as backup to CSS cascade
      if (this.hasHasIdIndicatorTarget) {
        this.hasIdIndicatorTarget.style.display = 'inline-block';
      }
    } else {
      this.wrapTarget.classList.remove('has-id');
      if (this.inputTarget.value &&
        !this.wrapTarget.classList.contains('create')) {
        this.wrapTarget.classList.add('offer-create');
      }
      if (this.hasKeepBtnTarget) {
        this.keepBtnTarget.classList.add("d-none");
      }
      // Directly hide indicator as backup to CSS cascade
      if (this.hasHasIdIndicatorTarget) {
        this.hasIdIndicatorTarget.style.display = 'none';
      }
    }
    // On forms where a map may not be relevant, we also show/hide the map.
    // Only show if we're in "create" mode.
    if (this.hasMapWrapTarget) {
      if (this.wrapTarget.classList.contains('create')) {
        this.mapWrapTarget.classList.remove('d-none');
      } else {
        // this.mapWrapTarget.classList.add('d-none');
      }
    }
  }

  storeCurrentHiddenData() {
    if (this.SEPARATOR) {
      this.storeCurrentHiddenDataMultiple();
    } else {
      this.storeCurrentHiddenDataSingle();
    }
  }

  storeCurrentHiddenDataMultiple() {
    this.verbose("autocompleter:storeCurrentHiddenDataMultiple()");
    this.stored_ids = this.hiddenIdsAsIntegerArray();
    this.verbose("stored_ids: " + JSON.stringify(this.stored_ids));
  }

  storeCurrentHiddenDataSingle() {
    this.verbose("autocompleter:storeCurrentHiddenDataSingle()");
    this.stored_id = parseInt(this.hiddenTarget.value); // value is a string
    let { name, north, south, east, west } = this.hiddenTarget.dataset;
    this.stored_data = { id: this.stored_id, name, north, south, east, west };
    this.verbose("stored_data: " + JSON.stringify(this.stored_data));
  }

  // called on assign and clear, also when mapOutlet is connected
  // This only affects the UI reflecting the new data situation.
  hiddenIdChanged() {
    if (this.SEPARATOR) {
      this.hiddenIdsChangedMultiple();
    } else {
      this.hiddenIdChangedSingle();
    }
  }

  hiddenIdsChangedMultiple() {
    const hidden_ids = this.hiddenIdsAsIntegerArray();

    if (JSON.stringify(hidden_ids) == JSON.stringify(this.stored_ids)) {
      this.verbose("autocompleter: hidden_ids did not change");
    } else {
      clearTimeout(this.data_timer);
      this.data_timer = setTimeout(() => {
        this.verbose("autocompleter: hidden_ids changed");
        this.verbose("autocompleter:hidden_ids: ")
        this.verbose(JSON.stringify(hidden_ids));
        this.cssHasIdOrNo(this.lastHiddenTargetValue());
        this.inputTarget.focus();
      }, 750)
    }
  }

  hiddenIdChangedSingle() {
    const hidden_id = parseInt(this.hiddenTarget.value || 0),
      // stored_id = parseInt(this.stored_id || 0),
      { name, north, south, east, west } = this.hiddenTarget.dataset,
      hidden_data = { id: hidden_id, name, north, south, east, west };

    // comparing data, not just ids, because google locations have same -1 id
    if (JSON.stringify(hidden_data) == JSON.stringify(this.stored_data)) {
      this.verbose("autocompleter: hidden_data did not change");
    } else {
      clearTimeout(this.data_timer);
      this.data_timer = setTimeout(() => {
        this.verbose("autocompleter: hidden_data changed");
        this.verbose("autocompleter:hidden_data: ")
        this.verbose(JSON.stringify(hidden_data));
        this.cssHasIdOrNo(hidden_id);
        if (this.hasKeepBtnTarget) {
          this.keepBtnTarget.classList.remove('active');
        }
        this.inputTarget.focus();
        if (this.hasMapOutlet) {
          this.mapOutlet.showBox();
        }
      }, 750)
    }
  }

  hiddenIdsAsIntegerArray() {
    return this.hiddenTarget.value.
      split(",").map((e) => parseInt(e.trim())).filter(Number);
  }

  // ------------------------------ Matches ------------------------------

  // Populate virtual list of `matches` from `primer`. This is sort of a query
  // after the query: the `primer` is like an alphabet-letter volume fetched
  // from ActiveRecord's encyclopedia of all possible records, and these
  // functions maintain the evolving `matches` list based on the user's input.
  // There are four strategies for refining the list, below.
  populateMatches() {
    this.verbose("autocompleter:populateMatches()");

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
      this.matches = this.removeDups(this.matches.sort(
        (a, b) => (a.name || "").localeCompare(b.name || "")
      ));

    this.verbose(this.matches);
    // Try to find old highlighted row in new set of options.
    this.updateCurrentRow(last);
    // Reset width each time we change the options.
    this.current_width = this.inputTarget.offsetWidth;
    // Check for a perfect match, because we now have new matches.
    this.updateHiddenId();
  }

  // When "acting like a select" make it display all options in the
  // order given right from the moment they enter the field,
  // and pick the first one, as long as there isn't one already selected.
  // They can still override the selections by clearing the field and typing.
  // The create link is added both here and in the updateRows() method.
  populateSelect() {
    // Laborious but necessary(?) way to check if these are the same options.
    const match_names = this.matches.map((m) => m['name']),
      primer_names = this.primer.map((m) => m['name']);

    if (match_names.every(item => primer_names.includes(item)) &&
      primer_names.every(item => match_names.includes(item))) return;

    this.matches = this.primer;

    const _selected = this.matches.find(
      (m) => m['name'] === this.inputTarget.value
    );
    if (this.matches.length > 0 && !_selected) {
      // if (!this.has_create_link) {
      this.inputTarget.value = this.matches[0]['name'];
      this.assignHiddenId(this.matches[0]);
      // } else {
      //   this.inputTarget.value = " ";
      // }
    }
  }

  // Grab all matches, doing exact match, ignoring number of words.
  populateNormal() {
    const token = this.getSearchToken().normalize().toLowerCase(),
      // normalize the Unicode of each string in primer for search
      primer = this.primer,
      primer_nm = this.primer.map((obj) => (
        { name: obj['name'].normalize().toLowerCase() }
      )),
      matches = [];

    if (token != '' && primer.length > 1) {
      for (let i = 1; i < primer.length; i++) {
        let s = primer_nm[i]['name'];
        if (s && s.length > 0 && s.indexOf(token) >= 0) {
          matches.push(primer[i]);
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
      primer = this.primer,
      // normalize the Unicode of each string in primer for search
      primer_nm = this.primer.map((obj) => (
        { name: obj['name'].normalize().toLowerCase() }
      )),
      matches = [];

    if (token != '' && primer.length > 1) {
      for (let i = 1; i < primer.length; i++) {
        let s = primer_nm[i]['name'] || '',
          s2 = ' ' + s + ' ',
          k;
        // check each word in the primer entry for a matching word
        for (k = 0; k < tokens.length; k++) {
          if (s2.indexOf(' ' + tokens[k]) < 0) break;
        }
        if (k >= tokens.length) {
          matches.push(primer[i]);
        }
      }
    }
    // If no matches, show a link to create a new record.
    // This is here because the primer may have results, but not the matches.
    if (this.hasCreateBtnTarget && this.TYPE !== "location_google") {
      if (matches.length === 0) {
        clearTimeout(this.create_timer);
        this.create_timer = setTimeout(() => {
          this.createBtnTarget.classList.remove('d-none');
        }, 1000)
      } else {
        this.createBtnTarget.classList.add('d-none');
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
      primer_lc = this.primer.map((obj) => (
        { name: obj['name'].toLowerCase() }
      )),
      matches = [];

    if (token != '' && primer.length > 1) {
      let the_rest = (token.match(/ /g) || []).length >= this.COLLAPSE;

      for (let i = 1; i < primer.length; i++) {
        if (primer_lc[i]['name'].indexOf(token) > -1) {
          let s = primer[i]['name'];
          if (s.length > 0) {
            if (the_rest || s.indexOf(' ', token.length) < token.length) {
              matches.push(primer[i]);
            } else if (matches.length > 1) {
              break;
            } else {
              if (matches[0] == token)
                matches.pop();
              matches.push(primer[i]);
              the_rest = true;
            }
          }
        }
      }
      // This removes our ability to match an id! We need to keep single matches
      // if (matches.length == 1 &&
      //   (token.trim() == matches[0]['name'].toLowerCase())) {
      //   matches.pop();
      // }
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
    this.verbose("autocompleter:updateCurrentRow()");
    const matches = this.matches,
      size = this.PULLDOWN_SIZE;
    let exact = -1,
      part = -1;

    if (token && token.length > 0) {
      for (let i = 0; i < matches.length; i++) {
        if (matches[i]['name'] == token) {
          exact = i;
          break;
        }
        if (matches[i]['name'] == token.substr(0, matches[i]['name'].length) &&
          (part < 0 ||
            matches[i]['name'].length > matches[part]['name'].length))
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
    // this.verbose("autocompleter:getSearchToken() before: " + token);

    // If we're only looking for whole words, don't make a request unless
    // trailing space or comma, indicating a user has finished typing a word.
    if (this.WHOLE_WORDS_ONLY &&
      ![',', ' '].includes(token.charAt(token.length - 1))) {
      return '';
    }
    if (this.SEPARATOR) {
      const extents = this.searchTokenExtents();
      token = val.substring(extents.start, extents.end);
    }
    // this.verbose("autocompleter:getSearchToken() after: " + token);
    return token;
  }

  // Change the token under or immediately in front of the cursor.
  // (Updates the value of the input field, handles multiple values.)
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
        this.setCursorPosition(
          this.inputTarget, extents.start + new_val.length
        );
        this.inputTarget.scrollTop = old_scroll;
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

    // this.verbose("autocompleter:searchTokenExtents() start: " + start);
    // this.verbose("autocompleter:searchTokenExtents() end: " + end);
    return { start, end };
  }

  // When there are multiple values separated by a separator.
  getSearchTokenIndex() {
    this.verbose("autocompleter:getSearchTokenIndex()");
    const token = this.getLastInput();
    return this.getInputIndexOf(token);
  }

  getInputIndexOf(token) {
    this.verbose("autocompleter:getInputIndexOf()");
    const idx = this.getInputArray().indexOf(token);
    this.verbose(idx);
    return idx;
  }

  getLastInput() {
    this.verbose("autocompleter:getLastInput()");
    const token = this.getInputArray().pop();
    this.verbose(token);
    return token;
  }

  getInputArray() {
    this.verbose("autocompleter:getInputArray()");
    const input_value = this.inputTarget.value;
    const input_array = (() => {
      // Don't return an array with an empty string, return an empty array.
      if (input_value == "") {
        return [];
      } else {
        return input_value.split(this.SEPARATOR).map((v) => v.trim());
      }
    })();
    this.verbose(input_array);
    return input_array;
  }

  getInputCount() {
    this.verbose("autocompleter:getInputCount()");
    const count = this.getInputArray().length;
    this.verbose(count);
    return count;
  }

  // ------------------------------ Fetch matches ------------------------------

  // Send request for updated primer.
  refreshPrimer() {
    this.verbose("autocompleter:refreshPrimer()");

    // token may be refined within this function, so it's a variable.
    let token = this.getSearchToken().toLowerCase(),
      last_request = this.last_fetch_request.toLowerCase();

    // Don't repeat last request accidentally, and unless we don't care about
    // input (as with location_containing), don't make request on empty string.
    // Furthermore, don't keep requesting if someone's trying to delete a
    // selection already made in act_like_select.
    if (!this.ACT_LIKE_SELECT &&
      (last_request == token || (!token || token.length < 1))) {
      this.verbose("autocompleter: same request, bailing");
      return;
    }

    // Memoize this condition, used twice:
    // "is the new search token an extension of the previous search string?"
    const new_val_refines_last_request =
      !this.WHOLE_WORDS_ONLY &&
      (last_request?.length < token.length) &&
      (last_request == token.substr(0, last_request?.length));

    // No need to make more constrained request if we got all results last time.
    if (!this.last_fetch_incomplete &&
      last_request && (last_request.length > 0) &&
      new_val_refines_last_request) {
      this.verbose("autocompleter: got all results last time, bailing");
      return;
    }

    // If a less constrained request is pending, wait for it to return before
    // refining the request, just in case it returns complete results
    // (rendering the more refined request unnecessary).
    if (this.fetch_request && new_val_refines_last_request) {
      this.verbose("autocompleter: request pending, bailing");
      return;
    }

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

    // If in select mode (ignoring string), and params haven't changed, bail.
    const { string, ...new_params } = query_params;
    if (this.last_fetch_params && this.ACT_LIKE_SELECT &&
      (JSON.stringify(new_params) === this.last_fetch_params)) {
      this.verbose("autocompleter: params haven't changed, bailing");
      this.verbose(new_params)
      return;
    }

    // Make request.
    this.sendFetchRequest(query_params);
  }

  // Send fetch request for more matching strings.
  async sendFetchRequest(query_params, single_match = false) {
    this.verbose("autocompleter:sendFetchRequest()");
    this.verbose(query_params);

    if (this.log) {
      this.verbose("Sending fetch request: " + query_params.string + "...");
    }

    const url = this.AJAX_URL + this.TYPE,
      abort_controller = new AbortController();

    const { string, ...params } = query_params;
    this.last_fetch_request = string;
    this.last_fetch_params = JSON.stringify(params);

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
        if (single_match) {
          this.processMatchFetchResponse(json)
        } else {
          this.processFetchResponse(json)
        }
      }
    } else {
      this.fetch_request = null;
      console.log(`got a ${response.status}: ${response.text}`);
    }
  }

  // Map controller sends back a primer formatted for the autocompleter
  refreshGooglePrimer({ primer }) {
    // Ensure primer is processed even if input lost focus (e.g., after clicking
    // "New locality" button). processFetchResponse checks this.focused.
    this.focused = true;
    this.processFetchResponse(primer)
  }

  // Process response from server:
  // 1. first line is first character of string actually used to match; [Unused]
  // 2. the last string is "..." if the set of results is incomplete;
  // 3. the rest are matching results.
  //
  // `this.primer` is a huge array of records matching the letters
  // typed to get the set down to a manageable size which is assumed
  // not to change too often.  `this.matches` is the smaller array of
  // records "refined" from the primer, matching the search token as
  // it is typed out. The pulldown menu is populated with the matches.
  //
  processFetchResponse(new_primer) {
    this.verbose("autocompleter:processFetchResponse()");

    // Clear flag telling us request is pending.
    this.fetch_request = null;

    // Check for trailing "..." signaling incomplete set of results.
    if (new_primer.length > 1 &&
      new_primer[new_primer.length - 1]['name'] == "...") {
      this.last_fetch_incomplete = true;
      new_primer = new_primer.slice(0, new_primer.length - 1);
    } else {
      this.last_fetch_incomplete = false;
    }

    // Log requests and responses if in debug mode.
    if (this.log) {
      this.debug("Got response for " +
        this.escapeHTML(this.last_fetch_request) + ": " +
        (new_primer.length - 1) + " strings (" +
        (this.last_fetch_incomplete ? "incomplete" : "complete") + ").");
    }

    this.verbose("autocompleter:new_primer length:" + new_primer.length)
    if (new_primer.length === 0) {
      // this.has_create_link = true;
      // this.primer = [{ name: this.create_text, id: 0 }];
      if (this.ACT_LIKE_SELECT) {
        const { lat, lng, ..._params } = JSON.parse(this.last_fetch_params);
        this.swap({
          detail: {
            type: "location_google", request_params: { lat, lng },
          }
        })
      }
    } else if (this.primer != new_primer && this.focused) {
      // Update menu if anything has changed.
      // this.has_create_link = false;
      this.primer = new_primer;
      this.populateMatches();
      if (!this.AUTOFILL_SINGLE_MATCH || this.matches.length > 1) {
        this.drawPulldown();
      }
    }

    // If act like select, focus the input field.`
    if ((this.primer.length > 1) && this.ACT_LIKE_SELECT) {
      // this.inputTarget.click(); // this fires another scheduleRefresh
      this.inputTarget.focus();
    }
  }


  // ------------------------------ SINGLE MATCH ------------------------------

  // For multiple-value autocompleters, try to get a matching record for a
  // single input value. This is for the case where the user pastes in an array
  // of values, so it's skipping the single match process.
  matchOneToken(token) {
    const query_params = { string: token, ...this.request_params }
    query_params["whole"] = true;
    query_params["all"] = true;
    query_params["exact"] = true;

    // Make request.
    this.sendFetchRequest(query_params, true);
  }

  // If we get a match, add the record to the hidden input and keepers array.
  processMatchFetchResponse(new_primer) {
    this.verbose("autocompleter:processMatchFetchResponse()");
    this.verbose("autocompleter:new_primer: ")
    this.verbose(JSON.stringify(new_primer));

    // Clear flag telling us request is pending.
    this.fetch_request = null;

    // If results, we're going to assume the first match is an exact match.
    if (new_primer.length > 0) {
      let exact_match = new_primer[0];
      // The match may have extra data we don't need in the keepers.
      // We only need the id and name.
      exact_match = { id: exact_match['id'], name: exact_match['name'] };
      // Order is important here. Figure out where the match is in the input.
      const idx = this.getInputIndexOf(exact_match['name']);
      if (idx == -1) { return; }

      let hidden_ids = this.hiddenIdsAsIntegerArray();
      // if the exact match is not in the hidden ids, add it at the right index.
      if (!hidden_ids.includes(exact_match['id'])) {
        hidden_ids.splice(idx, 1, exact_match['id']);
        this.hiddenTarget.value = hidden_ids.join(",");
      }
      // if it's not in keepers, add it at the right index. (Note extra data
      // would block the match here.)
      if (!this.keepers.includes(exact_match)) {
        this.keepers.splice(idx, 1, exact_match);
      }
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
