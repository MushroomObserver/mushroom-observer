import { Controller } from "@hotwired/stimulus"
import { mo_form_utilities, EVENT_KEYS } from "src/mo_form_utilities"
import { get } from "@rails/request.js"
import { MultiValueMixin } from "controllers/autocompleter/multi_value_mixin"
import { MapIntegrationMixin } from "controllers/autocompleter/map_integration_mixin"

/**
 * BaseAutocompleterController - Core autocompleter functionality
 *
 * This is the base class for all autocompleter controllers. It provides:
 * - Event handling (focus, blur, keydown, keyup, input, change)
 * - Pulldown/virtual list rendering
 * - Hidden ID management
 * - AJAX primer fetching
 * - Cursor navigation
 *
 * Subclasses should override:
 * - populateMatchesForType() - type-specific matching logic
 * - getTypeConfig() - type-specific configuration
 *
 * Usage: Extend this class and register as a Stimulus controller
 */

const DEFAULT_OPTS = {
  TYPE: null,
  UNORDERED: false,
  COLLAPSE: 0,
  WHOLE_WORDS_ONLY: false,
  PRESERVE_ORDER: false,
  AJAX_URL: "/autocompleters/new/",
  REFRESH_DELAY: 0.33,
  HIDE_DELAY: 0.50,
  KEY_DELAY_1: 0.50,
  KEY_DELAY_2: 0.03,
  PULLDOWN_SIZE: 10,
  PAGE_SIZE: 10,
  MAX_STRING_LENGTH: 50,
  SEPARATOR: null,
  SHOW_ERRORS: false,
  ACT_LIKE_SELECT: false,
  WRAP_CLASS: 'dropdown',
  HOT_CLASS: 'active'
}

const INTERNAL_OPTS = {
  ROW_HEIGHT: null,
  SCROLLBAR_WIDTH: null,
  focused: false,
  menu_up: false,
  old_value: null,
  stored_id: 0,
  stored_data: { id: 0 },
  stored_ids: [],
  keepers: [],
  primer: [],
  matches: [],
  current_row: -1,
  current_value: null,
  current_highlight: -1,
  current_width: 0,
  scroll_offset: 0,
  last_fetch_request: '',
  last_fetch_params: '',
  last_fetch_incomplete: true,
  fetch_request: null,
  refresh_timer: null,
  hide_timer: null,
  key_timer: null,
  data_timer: null,
  create_timer: null,
  log: false,
  has_create_link: false
}

// Shared static properties for subclasses (Stimulus doesn't inherit statics)
export const AUTOCOMPLETER_TARGETS = [
  "input", "select", "pulldown", "list", "hidden", "wrap",
  "createBtn", "hasIdIndicator", "keepBtn", "editBtn", "mapWrap",
  "collapseFields"
]
export const AUTOCOMPLETER_OUTLETS = ["map"]

// Types that have their own dedicated controller files.
// Used by swap() to determine if controller change is needed.
const CONTROLLER_TYPES = [
  "clade", "herbarium", "location", "name",
  "project", "region", "species_list", "user"
]

// Type configurations for runtime type switching (used by swap method)
const AUTOCOMPLETER_TYPES = {
  clade: {
    model: 'name'
  },
  herbarium: {
    UNORDERED: true,
    model: 'herbarium'
  },
  location: {
    ACT_LIKE_SELECT: false,
    AUTOFILL_SINGLE_MATCH: false,
    UNORDERED: true,
    model: 'location'
  },
  location_containing: {
    ACT_LIKE_SELECT: true,
    AUTOFILL_SINGLE_MATCH: true,
    model: 'location'
  },
  location_google: {
    ACT_LIKE_SELECT: true,
    AUTOFILL_SINGLE_MATCH: false,
    model: 'location'
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
    PRESERVE_ORDER: true,
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

export default class BaseAutocompleterController extends Controller {
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

  // ---------------------- Lifecycle ----------------------

  initialize() {
    Object.assign(this, DEFAULT_OPTS);
    Object.assign(this, INTERNAL_OPTS);

    // Get type-specific config from subclass
    const typeConfig = this.getTypeConfig();
    Object.assign(this, typeConfig);

    // Does this autocompleter affect a map?
    this.hasMap = this.inputTarget?.dataset?.hasOwnProperty("mapTarget");
    this.hasGeocode = this.inputTarget?.dataset?.hasOwnProperty("geocodeTarget");

    // Assign the separator for multiple-record autocompleters
    this.SEPARATOR = this.element.dataset.separator;

    // Shared MO utilities
    this.EVENT_KEYS = EVENT_KEYS;
    Object.assign(this, mo_form_utilities);

    // Apply mixins
    Object.assign(this, MultiValueMixin);
    Object.assign(this, MapIntegrationMixin);
  }

  connect() {
    this.element.dataset.autocompleter = "connected";
    this.getScrollBarWidth;

    if (!this.hasWrapTarget) {
      console.warn("BaseAutocompleter: needs a wrapping div with class: \"" +
        this.WRAP_CLASS + "\"");
    }

    this.default_action =
      this.listTarget?.children[0]?.children[0]?.dataset.action;
    this.prepareInputElement();
  }

  /**
   * Override in subclasses to provide type-specific configuration.
   * @returns {Object} Configuration object with TYPE, model, and any overrides
   */
  getTypeConfig() {
    return {
      TYPE: null,
      model: null
    };
  }

  // ---------------------- Type Switching ----------------------

  /**
   * Reinitialize autocompleter type at runtime. Called externally by other
   * controllers (e.g., map, geocode, form-exif) to change the autocompleter
   * behavior dynamically.
   *
   * If swapping to a type with its own dedicated controller (e.g., clade to
   * region), changes the data-controller attribute and lets Stimulus handle
   * the disconnect/connect. Otherwise, reinitializes in place (e.g., location
   * to location_google).
   *
   * @param {Object} detail - Contains type and optional request_params
   */
  swap({ detail }) {
    let type;
    if (this.hasSelectTarget) {
      type = this.selectTarget.value;
    } else if (detail?.hasOwnProperty("type")) {
      type = detail.type;
    }
    if (type == undefined || type === this.TYPE) { return; }

    if (!AUTOCOMPLETER_TYPES.hasOwnProperty(type)) {
      console.warn("BaseAutocompleter: Invalid type: \"" + type + "\"");
      return;
    }

    // Check if we need to switch to a different controller
    // (e.g., clade -> region requires controller change)
    if (this.shouldChangeController(type)) {
      this.verbose("autocompleter:swap controller to " + type);
      const newController = `autocompleter--${type}`;
      this.element.setAttribute("data-type", type);
      this.element.setAttribute("data-controller", newController);
      // Stimulus will disconnect this controller and connect the new one
      return;
    }

    // Otherwise, reinitialize in place (e.g., location -> location_google)
    let location = false;
    if (detail?.hasOwnProperty("request_params") &&
      detail.request_params?.hasOwnProperty("lat") &&
      detail.request_params?.hasOwnProperty("lng")) {
      location = detail.request_params;
    }

    this.verbose("autocompleter:swap " + type);
    this.TYPE = type;
    this.element.setAttribute("data-type", type);
    // Add dependent properties and allow overrides
    Object.assign(this, AUTOCOMPLETER_TYPES[type]);
    Object.assign(this, detail); // type, request_params
    // Reset state
    this.primer = [];
    this.matches = [];
    this.stored_data = { id: 0 };
    this.keepers = [];
    this.last_fetch_params = '';
    // Re-prepare inputs
    this.prepareInputElement();
    this.prepareHiddenInput();
    if (!this.hasEditBtnTarget ||
      this.editBtnTarget?.classList?.contains('d-none')) {
      this.clearHiddenId();
    }
    this.constrainedSelectionUI(location);
  }

  /**
   * Determine if swapping to newType requires changing the Stimulus controller.
   * Returns true if newType has a dedicated controller AND it's different from
   * the current controller.
   */
  shouldChangeController(newType) {
    // Only types in CONTROLLER_TYPES have dedicated controllers
    if (!CONTROLLER_TYPES.includes(newType)) return false;

    // Get current controller type from identifier (e.g., "autocompleter--clade")
    const currentType = this.identifier.replace("autocompleter--", "");

    // Change controller if switching to a different dedicated controller type
    return CONTROLLER_TYPES.includes(currentType) && currentType !== newType;
  }

  /**
   * When swapping autocompleter types, update hidden input identifiers.
   */
  prepareHiddenInput() {
    const identifier = AUTOCOMPLETER_TYPES[this.TYPE]?.['model'] + '_id';
    if (!identifier || identifier === 'undefined_id') return;

    const form = this.hiddenTarget.name.split('[')[0];

    if (form === "") {
      this.hiddenTarget.name = identifier;
      this.hiddenTarget.id = identifier;
    } else {
      this.hiddenTarget.name = form + '[' + identifier + ']';
      this.hiddenTarget.id = form + "_" + identifier;
    }
  }

  // ---------------------- Input Preparation ----------------------

  prepareInputElement() {
    this.old_value = null;
    this.addEventListeners();

    if (this.inputTarget.value.length > 0) {
      this.updateHiddenId();
    }

    const hidden_id = parseInt(this.hiddenTarget.value);
    this.cssHasIdOrNo(hidden_id);
  }

  addEventListeners() {
    this.inputTarget.addEventListener("focus", this);
    this.inputTarget.addEventListener("click", this);
    this.inputTarget.addEventListener("blur", this);
    this.inputTarget.addEventListener("keydown", this);
    this.inputTarget.addEventListener("keyup", this);
    this.inputTarget.addEventListener("keypress", this);
    this.inputTarget.addEventListener("input", this);
    this.inputTarget.addEventListener("change", this);
    window.addEventListener("beforeunload", this);
  }

  handleEvent(event) {
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

  // ---------------------- Events ----------------------

  ourKeydown(event) {
    const key = event.which == 0 ? event.keyCode : event.which;
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
          if (this.current_row >= 0) {
            event.preventDefault();
            this.selectRow(this.current_row - this.scroll_offset);
          }
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

  ourKeypress(event) {
    const key = event.which == 0 ? event.keyCode : event.which;
    if (this.menu_up && this.isHotKey(key) &&
      !(key == 9 || this.current_row < 0))
      return false;
    return true;
  }

  ourKeyup(event) {
    this.clearKey();
    this.ourChange(true);
    return true;
  }

  ourChange(do_refresh) {
    const old_value = this.old_value;
    const new_value = this.inputTarget.value;
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

  ourClick(event) {
    if (this.ACT_LIKE_SELECT)
      this.verbose("autocompleter:ourClick()");
    this.scheduleRefresh();
    return false;
  }

  ourFocus(event) {
    if (!this.ROW_HEIGHT)
      this.getRowHeight();
    this.focused = true;
  }

  ourBlur(event) {
    this.scheduleHide();
    this.focused = false;
  }

  ourUnload() {
    this.inputTarget.setAttribute("autocomplete", "on");
    return false;
  }

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

  // ---------------------- Timers ----------------------

  scheduleRefresh() {
    if (this.TYPE === "location_google") {
      this.scheduleGoogleRefresh();
    } else {
      this.verbose("autocompleter:scheduleRefresh()");
      this.clearRefresh();
      this.refresh_timer = setTimeout((() => {
        this.verbose("autocompleter: doing refreshPrimer()");
        this.old_value = this.inputTarget.value;
        if (this.AJAX_URL) { this.refreshPrimer(); }
        this.populateMatches();
        if (!this.AUTOFILL_SINGLE_MATCH || this.matches.length > 1) {
          this.drawPulldown();
        }
      }), this.REFRESH_DELAY * 1000);
    }
  }

  scheduleHide() {
    this.clearHide();
    this.hide_timer = setTimeout(
      this.hidePulldown.bind(this), this.HIDE_DELAY * 1000
    );
  }

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

  clearRefresh() {
    clearTimeout(this.refresh_timer);
  }

  clearHide() {
    if (this.hide_timer) {
      clearTimeout(this.hide_timer);
      this.hide_timer = null;
    }
  }

  clearKey() {
    if (this.key_timer) {
      clearTimeout(this.key_timer);
      this.key_timer = null;
    }
  }

  // ---------------------- Cursor ----------------------

  pageUp() { this.moveCursor(-this.PAGE_SIZE); }
  pageDown() { this.moveCursor(this.PAGE_SIZE); }
  arrowUp() { this.moveCursor(-1); }
  arrowDown() { this.moveCursor(1); }
  goHome() { this.moveCursor(-this.matches.length) }
  goEnd() { this.moveCursor(this.matches.length) }

  moveCursor(rows) {
    const old_row = this.current_row,
      old_scr = this.scroll_offset;
    let new_row = old_row + rows,
      new_scr = old_scr;

    if (new_row < 0)
      new_row = old_row < 0 ? -1 : 0;
    if (new_row >= this.matches.length)
      new_row = this.matches.length - 1;
    this.current_row = new_row;
    this.current_value = new_row < 0 ? null : this.matches[new_row];

    if (new_row < new_scr)
      new_scr = new_row;
    if (new_scr < 0)
      new_scr = 0;
    if (new_row >= new_scr + this.PULLDOWN_SIZE)
      new_scr = new_row - this.PULLDOWN_SIZE + 1;

    if (new_row != old_row || new_scr != old_scr) {
      this.scroll_offset = new_scr;
      this.drawPulldown();
    }
  }

  highlightRow(new_hl) {
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

  selectRow(idx) {
    if (this.matches.length === 0) return;

    if (idx instanceof Event) { idx = parseInt(idx.target.dataset.row); }
    let new_match = this.matches[this.scroll_offset + idx],
      new_val = new_match.name;

    if (this.COLLAPSE > 0 &&
      (new_val.match(/ /g) || []).length < this.COLLAPSE) {
      new_val += ' ';
      this.verbose("gotcha!()");
      this.scheduleRefresh();
    } else {
      this.scheduleHide();
    }
    this.assignHiddenId(new_match);
    this.setSearchToken(new_val);
    this.ourChange(false);
    this.inputTarget.focus();
    this.focused = true;
  }

  // ---------------------- Pulldown ----------------------

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

  drawPulldown() {
    const rows = this.listTarget.children,
      scroll = this.scroll_offset;

    if (this.log) {
      this.debug(
        "Redraw: matches=" + this.matches.length +
        ", scroll=" + scroll + ", cursor=" + this.current_row
      );
    }
    if (!this.ROW_HEIGHT)
      this.getRowHeight();
    if (rows.length) {
      this.updateRows(rows);
      this.highlightNewRow(rows);
      this.makePulldownVisible();
    }
    this.inputTarget.focus();
  }

  updateRows(rows) {
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
  }

  updateRow(i, link, text) {
    const { name, ...new_data } = this.matches[i + this.scroll_offset];
    let stored = this.escapeHTML(name);

    if (text != stored) {
      if (stored === " ") stored = "&nbsp;";
      link.innerHTML = stored;
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

  highlightNewRow(rows) {
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

  makePulldownVisible() {
    const matches = this.matches,
      offset = this.scroll_offset,
      size = this.PULLDOWN_SIZE,
      row_height = this.ROW_HEIGHT,
      length_ahead = this.matches.length - this.scroll_offset,
      current_size = size < length_ahead ? size : length_ahead,
      overflow = this.matches.length > this.PULLDOWN_SIZE ? "scroll" : "hidden";

    if (matches.length > 0) {
      this.pulldownTarget.style.overflowY = overflow;
      this.pulldownTarget.style.height = row_height * current_size + "px";
      this.listTarget.style.marginTop = row_height * offset + "px";
      this.listTarget.style.height = row_height * length_ahead + "px";
      this.pulldownTarget.scrollTo({ top: row_height * offset });

      this.setWidth();
      this.updateWidth();

      if (matches.length > 1 || this.getSearchToken() != matches[0]['name']) {
        this.clearHide();
        this.wrapTarget?.classList?.add('open');
        this.menu_up = true;
      } else {
        this.hidePulldown();
      }
    } else {
      this.hidePulldown();
    }
  }

  hidePulldown() {
    this.wrapTarget?.classList?.remove('open');
    this.menu_up = false;
  }

  updateWidth() {
    let w = this.listTarget.offsetWidth;
    if (this.matches.length > this.PULLDOWN_SIZE)
      w += this.SCROLLBAR_WIDTH;
    if (this.current_width < w) {
      this.current_width = w;
      this.setWidth();
    }
  }

  setWidth() {
    const w1 = this.current_width;
    let w2 = w1;
    if (this.matches.length > this.PULLDOWN_SIZE)
      w2 -= this.SCROLLBAR_WIDTH;
    this.listTarget.style.minWidth = w2 + 'px';
  }

  // ---------------------- Hidden IDs ----------------------

  updateHiddenId() {
    this.verbose("autocompleter:updateHiddenId()");
    this.verbose("autocompleter:getSearchToken().trim(): ");
    this.verbose(this.getSearchToken().trim());
    if (this.SEPARATOR) { this.removeUnusedKeepersAndIds(); }

    const perfect_match =
      this.matches.find((m) => m['name'] === this.getSearchToken().trim());

    if (perfect_match) {
      if (this.lastHiddenTargetValue() != perfect_match['id']) {
        this.assignHiddenId(perfect_match);
      }
    } else if (!this.ignoringTextInput() && this.matches.length > 0) {
      this.clearHiddenId();
    }
  }

  lastHiddenTargetValue() {
    if (this.SEPARATOR) {
      return this.hiddenTarget.value.split(",").pop();
    } else {
      return this.hiddenTarget.value
    }
  }

  assignHiddenId(match) {
    this.verbose("autocompleter:assignHiddenId()");
    this.verbose(match);
    if (!match) return;
    this.storeCurrentHiddenData();
    this.updateHiddenTargetValue(match);
    this.cssHasIdOrNo(parseInt(match['id']));
    this.hiddenIdChanged();
  }

  updateHiddenTargetValue(match) {
    if (this.SEPARATOR) {
      this.updateHiddenTargetValueMultiple(match);
    } else {
      this.updateHiddenTargetValueSingle(match);
    }
  }

  updateHiddenTargetValueSingle(match) {
    this.verbose("autocompleter:updateHiddenTargetValueSingle()");
    this.hiddenTarget.value = match['id'];
    Object.keys(match).forEach(key => {
      this.hiddenTarget.dataset[key] = match[key];
    });
  }

  clearHiddenId() {
    this.verbose("autocompleter:clearHiddenId()");
    this.storeCurrentHiddenData();
    this.clearLastHiddenTargetValue();
    this.hiddenIdChanged();
    this.cssHasIdOrNo(null);
  }

  clearLastHiddenTargetValue() {
    this.verbose("autocompleter:clearLastHiddenTargetValue()");
    if (this.inputTarget.value.length === 0) {
      this.clearHiddenIdAndData();
      this.keepers = [];
    } else if (this.SEPARATOR) {
      this.clearLastHiddenIdAndKeeper();
    } else {
      this.clearHiddenIdAndData();
    }
  }

  clearHiddenIdAndData() {
    this.hiddenTarget.value = '';
    this.hiddenTarget.setAttribute('value', '');
    Object.keys(this.hiddenTarget.dataset).forEach(key => {
      if (!key.match(/Target/))
        delete this.hiddenTarget.dataset[key];
    });
  }

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
    if (this.hasMapWrapTarget) {
      if (this.wrapTarget.classList.contains('create')) {
        this.mapWrapTarget.classList.remove('d-none');
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

  storeCurrentHiddenDataSingle() {
    this.verbose("autocompleter:storeCurrentHiddenDataSingle()");
    this.stored_id = parseInt(this.hiddenTarget.value);
    let { name, north, south, east, west } = this.hiddenTarget.dataset;
    this.stored_data = { id: this.stored_id, name, north, south, east, west };
    this.verbose("stored_data: " + JSON.stringify(this.stored_data));
  }

  hiddenIdChanged() {
    if (this.SEPARATOR) {
      this.hiddenIdsChangedMultiple();
    } else {
      this.hiddenIdChangedSingle();
    }
  }

  hiddenIdChangedSingle() {
    const hidden_id = parseInt(this.hiddenTarget.value || 0),
      { name, north, south, east, west } = this.hiddenTarget.dataset,
      hidden_data = { id: hidden_id, name, north, south, east, west };

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
          // Fill box inputs from location data if available
          if (hidden_data.north || hidden_data.south ||
              hidden_data.east || hidden_data.west) {
            this.mapOutlet.updateBoundsInputs(hidden_data);
          }
          // Only trigger map rectangle drawing when a location was selected
          // (has an ID). Don't trigger Google geocode when ID is cleared.
          if (hidden_id) {
            this.mapOutlet.showBox();
          }
        }
      }, 750)
    }
  }

  // ---------------------- Matches ----------------------

  populateMatches() {
    this.verbose("autocompleter:populateMatches()");
    const last = this.current_row < 0 ? null : this.matches[this.current_row];

    // Call type-specific match population
    this.populateMatchesForType();

    // Sort and remove duplicates, unless already sorted or preserving order.
    // PRESERVE_ORDER skips sorting (server handles order); duplicates already
    // removed server-side.
    if (!this.ACT_LIKE_SELECT && !this.PRESERVE_ORDER)
      this.matches = this.removeDups(this.matches.sort(
        (a, b) => (a.name || "").localeCompare(b.name || "")
      ));

    this.verbose(this.matches);
    this.updateCurrentRow(last);
    this.current_width = this.inputTarget.offsetWidth;
    this.updateHiddenId();
  }

  /**
   * Override in subclasses to provide type-specific matching.
   * Should populate this.matches based on this.primer and search token.
   *
   * Default implementation checks UNORDERED flag for runtime switching
   * (e.g., when swap() is called from a select dropdown).
   */
  populateMatchesForType() {
    if (this.UNORDERED) {
      this.populateUnordered();
    } else {
      this.populateNormal();
    }
  }

  populateNormal() {
    const token = this.getSearchToken().normalize().toLowerCase(),
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

  populateUnordered() {
    const token = this.getSearchToken().normalize().toLowerCase().
      replace(/^ */, '').replace(/  +/g, ' '),
      tokens = token.split(' '),
      primer = this.primer,
      primer_nm = this.primer.map((obj) => (
        { name: obj['name'].normalize().toLowerCase() }
      )),
      matches = [];

    if (token != '' && primer.length > 1) {
      for (let i = 1; i < primer.length; i++) {
        let s = primer_nm[i]['name'] || '',
          s2 = ' ' + s + ' ',
          k;
        for (k = 0; k < tokens.length; k++) {
          if (s2.indexOf(' ' + tokens[k]) < 0) break;
        }
        if (k >= tokens.length) {
          matches.push(primer[i]);
        }
      }
    }
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

  populateCollapsed() {
    const token = this.getSearchToken().toLowerCase(),
      primer = this.primer,
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
    }
    this.matches = matches;
  }

  populateSelect() {
    const match_names = this.matches.map((m) => m['name']),
      primer_names = this.primer.map((m) => m['name']);

    if (match_names.every(item => primer_names.includes(item)) &&
      primer_names.every(item => match_names.includes(item))) return;

    this.matches = this.primer;

    const _selected = this.matches.find(
      (m) => m['name'] === this.inputTarget.value
    );
    if (this.matches.length > 0 && !_selected) {
      this.inputTarget.value = this.matches[0]['name'];
      this.assignHiddenId(this.matches[0]);
    }
  }

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

  // ---------------------- Search Token ----------------------

  getSearchToken() {
    const val = this.inputTarget.value;
    let token = val;

    if (this.WHOLE_WORDS_ONLY &&
      ![',', ' '].includes(token.charAt(token.length - 1))) {
      return '';
    }
    if (this.SEPARATOR) {
      const extents = this.searchTokenExtents();
      token = val.substring(extents.start, extents.end);
    }
    // Strip trailing periods that may be added by browser autocomplete
    // when user accidentally types two spaces (e.g., "Amanita muscaria.")
    token = token.replace(/\.+$/, '');
    return token;
  }

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

  // ---------------------- Fetch ----------------------

  refreshPrimer() {
    this.verbose("autocompleter:refreshPrimer()");

    let token = this.getSearchToken().toLowerCase(),
      last_request = this.last_fetch_request.toLowerCase();

    if (!this.ACT_LIKE_SELECT &&
      (last_request == token || (!token || token.length < 1))) {
      this.verbose("autocompleter: same request, bailing");
      return;
    }

    const new_val_refines_last_request =
      !this.WHOLE_WORDS_ONLY &&
      (last_request?.length < token.length) &&
      (last_request == token.substr(0, last_request?.length));

    if (!this.last_fetch_incomplete &&
      last_request && (last_request.length > 0) &&
      new_val_refines_last_request) {
      this.verbose("autocompleter: got all results last time, bailing");
      return;
    }

    if (this.fetch_request && new_val_refines_last_request) {
      this.verbose("autocompleter: request pending, bailing");
      return;
    }

    if (token.length > this.MAX_STRING_LENGTH)
      token = token.substr(0, this.MAX_STRING_LENGTH);

    if (this.WHOLE_WORDS_ONLY) {
      token = token.trim().replace(/,.*$/, '')
    }

    const query_params = { string: token, ...this.request_params }

    if (this.ACT_LIKE_SELECT) { query_params["all"] = true; }
    if (this.WHOLE_WORDS_ONLY) { query_params["whole"] = true; }

    const { string, ...new_params } = query_params;
    if (this.last_fetch_params && this.ACT_LIKE_SELECT &&
      (JSON.stringify(new_params) === this.last_fetch_params)) {
      this.verbose("autocompleter: params haven't changed, bailing");
      this.verbose(new_params)
      return;
    }

    this.sendFetchRequest(query_params);
  }

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

  processFetchResponse(new_primer) {
    this.verbose("autocompleter:processFetchResponse()");

    this.fetch_request = null;

    if (new_primer.length > 1 &&
      new_primer[new_primer.length - 1]['name'] == "...") {
      this.last_fetch_incomplete = true;
      new_primer = new_primer.slice(0, new_primer.length - 1);
    } else {
      this.last_fetch_incomplete = false;
    }

    if (this.log) {
      this.debug("Got response for " +
        this.escapeHTML(this.last_fetch_request) + ": " +
        (new_primer.length - 1) + " strings (" +
        (this.last_fetch_incomplete ? "incomplete" : "complete") + ").");
    }

    this.verbose("autocompleter:new_primer length:" + new_primer.length)
    if (new_primer.length === 0) {
      if (this.ACT_LIKE_SELECT) {
        const { lat, lng, ..._params } = JSON.parse(this.last_fetch_params);
        this.swap({
          detail: {
            type: "location_google", request_params: { lat, lng },
          }
        })
      }
    } else if (this.primer != new_primer && this.focused) {
      this.primer = new_primer;
      this.populateMatches();
      if (!this.AUTOFILL_SINGLE_MATCH || this.matches.length > 1) {
        this.drawPulldown();
      }
    }

    if ((this.primer.length > 1) && this.ACT_LIKE_SELECT) {
      this.inputTarget.focus();
    }
  }

  // ---------------------- Debugging ----------------------

  debug(str) {
    // console.log(str);
  }

  verbose(str) {
    // console.log(str);
  }
}
