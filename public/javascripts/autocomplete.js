var AUTOCOMPLETERS = {};

var MOAutocompleter = Class.create({
  initialize: function (opts) {

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
    //   2) It watches keyup/down/press and blur events:
    //      It handles cursor movement and selection on keydown.
    //      It stops propogation of tab and enter in both keydown and keypress.
    //      It checks for change whenever a key is released.
    //      It hides the menu when it loses focus, but it does it on a timer to allow
    //       for temporary loss of focus when messing around with the pulldown menu.
    //   3) Several things cause the menu to be redrawn:
    //       cursor movement, any time the matches are recalculated
    //      Several things cause the list of matches to be recalculated:
    //       change in text field, selection of item, receipt of AJAX response
    //      Two things can potentially result in AJAX request:
    //       change in text field, selection of item
    //   4) Summary of important events:
    //       cursor movement        -- redraw                  -- move_cursor() -> draw_pulldown()
    //       selection of menu item -- matches, [AJAX], redraw -- select_row() -> our_change() -> schedule_refresh()
    //       change in text field   -- matches, [AJAX], redraw -- our_change() -> schedule_refresh()
    //       AJAX response          -- matches, menu           -- process_ajax_response() -> schedule_refresh()
    //      (Where schedule_refresh() -> refresh_options() -> update_matches() -> draw_pulldown().)
    //   5) Important medthods:
    //       refresh_options()        send AJAX request
    //       process_ajax_response()  process AJAX response
    //       update_matches()         search options for matches
    //       draw_pulldown()          update pulldown menu

    // These are potentially useful parameters the user might want to tweak.
    Object.extend(this, {
      input_id:             null,            // id of text field
      pulldown_class:       'auto_complete', // class of pulldown div
      hot_class:            'selected',      // class of <li> when highlighted
      unordered:            false,           // ignore order of words when matching
                                             // (collapse must be 0 if this is true!)
      collapse:             0,               // 0 = normal mode
                                             // 1 = autocomplete first word, then the rest
                                             // 2 = autocomplete first word, then second word, then the rest
                                             // N = etc.
      token:                null,            // separator between options
      primer:               null,            // initial list of options (one string per line)
      update_primer_on_blur: false,          // add each entered value into primer (useful if auto-completing a column of fields)
      ajax_url:             null,            // where to request options from
      refresh_delay:        0.10,            // how long to wait before sending AJAX request (seconds)
      hide_delay:           0.25,            // how long to wait before hiding pulldown (seconds)
      key_delay1:           0.50,            // initial key repeat delay (seconds)
      key_delay2:           0.03,            // subsequent key repeat delay (seconds)
      pulldown_size:        10,              // maximum number of options shown at a time
      page_size:            10,              // amount to move cursor on page up and down
      max_request_length:   50               // max length of string to send via AJAX
    });
    Object.extend(this, opts);

    // These are internal state variables the user should leave alone.
    Object.extend(this, {
      input_elem:           null,            // DOM element of text field
      datalist_elem:        null,            // DOM element of datalist
      pulldown_elem:        null,            // DOM element of pulldown div
      list_elem:            null,            // DOM element of pulldown ul
      active:               false,           // is pulldown visible and active?
      old_value:            {},              // previous value of input field
      options:              '',              // list of all options
      matches:              [],              // list of options currently showing
      current_row:          -1,              // number of option currently highlighted (0 = none)
      current_value:        null,            // value currently highlighted (null = none)
      current_highlight:    -1,              // row of view highlighted (-1 = none)
      current_width:        0,               // current width of menu
      scroll_offset:        0,               // scroll offset
      focused:              false,           // do we have input focus?
      last_ajax_request:    null,            // last ajax request we got results for
      last_ajax_incomplete: true,            // did we get all the results we requested last time?
      ajax_request:         null,            // ajax request while underway
      refresh_timer:        null,            // timer used to delay update after typing
      hide_timer:           null,            // timer used to delay hiding of pulldown
      key_timer:            null,            // timer used to emulate key repeat
      do_scrollbar:         null,            // should we allow scrollbar? some browsers just can't handle it, e.g., old IE
      do_datalist:          null,            // implement using <datalist> instead of doing pulldown ourselves
      row_height:           null,            // height of a row in pixels (filled in automatically)
      scrollbar_width:      null             // width of scrollbar (filled in automatically)
    });

    // Check if browser can handle doing scrollbar.
    this.do_scrollbar =
      Prototype.Browser.IE ? Prototype.Browser.IE8 : true;

    // Get the DOM element of the input field.
    if (!this.input_elem)
      this.input_elem = $(this.input_id);
    if (!this.input_elem)
      alert("MOAutocompleter: Invalid input id: \"" + this.input_id + "\"");

    // Figure out a few browser-dependent dimensions.
    this.scrollbar_width = Element.getScrollBarWidth();

    // Initialize options.
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
    AUTOCOMPLETERS[this.input_id] = this;
  },

  // Prepare another input element to share an existing autocompleter instance.
  reuse: function (other_id) {
    var other_elem = $(other_id);
    this.prepare_input_element(other_elem);
  },

  switch_inputs: function (event, elem) {
    if (this.input_id != elem.id) {
      this.input_id   = elem.id;
      this.input_elem = elem;
      this.input_elem.parentNode.appendChild(this.pulldown_elem);
    }
    this.our_focus(event);
  },

  // Prepare input element: attach elements, set properties.
  prepare_input_element: function (elem) {
    this.old_value[elem.id] = null;

    // Attach events if we aren't using datalist thingy.
    if (!this.do_datalist) {
      Event.observe(elem, 'focus', (function (event) {
        this.switch_inputs(event, elem);
      }).bindAsEventListener(this));
      Event.observe(elem, 'blur',     this.our_blur.bindAsEventListener(this));
      Event.observe(elem, 'keydown',  this.our_keydown.bindAsEventListener(this));
      Event.observe(elem, 'keyup',    this.our_keyup.bindAsEventListener(this));
      Event.observe(elem, 'keypress', this.our_keypress.bindAsEventListener(this));
    }

    // Disable default browser autocomplete.
    elem.setAttribute('autocomplete','off');

    // Restore field value when user "goes back" to this page.  Only really need
    // this for firefox browsers which handle the autocomplete="off" attribute,
    // but it shouldn't hurt to do it for all browsers.  Problem is, if
    // autocomplete="off" is set, Firefox deliberately *erases* the field value to
    // prevent potentially sensitive information from being visible to random
    // people walking by a terminal and pressing "back" button.  This fix just
    // sets it right back to the old value.  So there.
    Event.observe(document, 'focus', (function () {
      if (this.old_value[elem.id] != null)
        elem.value = this.old_value[elem.id];
    }).bind(this));
  },

// ------------------------------ Events ------------------------------

  // User pressed a key in the text field.
  our_keydown: function (event) {
    // $('log').innerHTML += "keydown(" + event.keyCode + ")<br/>";
    this.clear_key();
    this.focused = true;
    switch (event.keyCode) {
      case Event.KEY_ESC:
        this.schedule_hide();
        this.active = false;
        break;
      case Event.KEY_RETURN:
      case Event.KEY_TAB:
        if (this.active) {
          if (this.current_row >= 0)
            this.select_row(this.current_row - this.scroll_offset);
          Event.stop(event);
        }
        break;
      case Event.KEY_ESC:
        if (this.active) {
          this.lose_focus();
          Event.stop(event);
        }
        break;
      case Event.KEY_HOME:
        if (this.active) {
          this.go_home();
          Event.stop(event);
        }
        break;
      case Event.KEY_END:
        if (this.active) {
          this.go_end();
          Event.stop(event);
        }
        break;
      case Event.KEY_PAGEUP:
        if (this.active) {
          this.page_up();
          this.schedule_key(this.page_up);
          Event.stop(event);
        }
        break;
      case Event.KEY_UP:
        if (this.active) {
          this.arrow_up();
          this.schedule_key(this.arrow_up);
          Event.stop(event);
        }
        break;
      case Event.KEY_DOWN:
        if (this.active) {
          this.arrow_down();
          this.schedule_key(this.arrow_down);
          Event.stop(event);
        }
        break;
      case Event.KEY_PAGEDOWN:
        if (this.active) {
          this.page_down();
          this.schedule_key(this.page_down);
          Event.stop(event);
        }
        break;
    }
    if (this.on_keydown) this.on_keydown(event);
  },

  // Need to prevent these keys from being processed by form.
  our_keypress: function (event) {
    // $('log').innerHTML += "keypress(" + event.keyCode + ")<br/>";
    switch (event.keyCode) {
      case Event.KEY_RETURN:
      case Event.KEY_TAB:
        if (this.active)
          Event.stop(event);
    }
    if (this.on_keypress) this.on_keypress(event);
  },

  // User has released a key.
  our_keyup: function (event) {
    // $('log').innerHTML += "keyup()<br/>";
    this.clear_key();
    this.our_change();
    if (this.on_keyup) this.on_keyup(event);
  },

  // Input field has changed.
  our_change: function () {
    // $('log').innerHTML += "our_change(" + this.input_elem.value + ")<br/>";
    if (this.input_elem.value != this.old_value[this.input_id])
      this.schedule_refresh();
    if (this.on_change) this.on_change(this.input_elem.value);
  },

  // User entered text field.
  our_focus: function (event) {
    // $('log').innerHTML += "our_focus()<br/>";
    if (!this.row_height)
      this.get_row_height();
    if (this.on_focus) this.on_focus(event);
  },

  // User left the text field.
  our_blur: function (event) {
    // $('log').innerHTML += "our_blur()<br/>";
    this.schedule_hide();
    if (this.on_blur) this.on_blur(event);
  },

// ------------------------------ Timers ------------------------------

  // Schedule options to be refreshed after polite delay.
  schedule_refresh: function () {
    this.verbose("schedule_refresh()");
    this.clear_refresh();
    this.refresh_timer = setTimeout((function() {
    this.verbose("doing_refresh()");
      // $('log').innerHTML += "refresh_timer(" + this.input_elem.value + ")<br/>";
      this.old_value[this.input_id] = this.input_elem.value;
      if (this.ajax_url)
        this.refresh_options();
      this.update_matches();
      if (this.do_datalist)
        this.update_datalist();
      else
        this.draw_pulldown();
    }).bind(this), this.refresh_delay*1000);
  },

  // Schedule pulldown to be hidden if nothing happens in the meantime.
  schedule_hide: function () {
    this.clear_hide();
    this.hide_timer = setTimeout(this.hide_pulldown.bind(this), this.hide_delay*1000);
    if (this.update_primer_on_blur)
      this.update_primer();
  },

  // Schedule a method to be called after key stays pressed for some time.
  schedule_key: function (action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.bind(this).call();
      this.schedule_key2(action);
    }).bind(this), this.key_delay1*1000);
  },
  schedule_key2: function (action) {
    this.clear_key();
    this.key_timer = setTimeout((function () {
      action.bind(this).call();
      this.schedule_key2(action);
    }).bind(this), this.key_delay2*1000);
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
  page_up: function ()
    { this.move_cursor(-this.page_size); },
  page_down: function ()
    { this.move_cursor(this.page_size); },
  arrow_up: function ()
    { this.move_cursor(-1); },
  arrow_down: function ()
    { this.move_cursor(1); },
  go_home: function ()
    { this.move_cursor(-this.matches.length) },
  go_end: function ()
    { this.move_cursor(this.matches.length) },
  move_cursor: function (rows) {
    this.verbose("move_cursor()");
    var old_row = this.current_row;
    var new_row = old_row + rows;
    var old_scr = this.scroll_offset;
    var new_scr = old_scr;

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
    var rows = this.list_elem.childNodes;
    var old_hl = this.current_highlight;
    this.current_highlight = new_hl;
    this.current_row = this.scroll_offset + new_hl;
    if (old_hl != new_hl) {
      if (old_hl >= 0)
        rows[old_hl].removeClassName(this.hot_class);
      if (new_hl >= 0)
        rows[new_hl].addClassName(this.hot_class);
    }
    this.input_elem.focus();
    this.update_width();
  },

  // Called when users scrolls via scrollbar.
  our_scroll: function () {
    this.verbose("our_scroll()");
    var old_scr = this.scroll_offset;
    var new_scr = Math.round(this.pulldown_elem.scrollTop / this.row_height);
    var old_row = this.current_row;
    var new_row = this.current_row;
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
    var old_val = this.input_elem.value;
    var new_val = this.matches[this.scroll_offset+row];
    this.input_elem.focus();
    if (this.collapse > 0 && (new_val.match(/ /g) || []).length < this.collapse)
      new_val += ' ';
    if (this.token) {
      var i = old_val.lastIndexOf(this.token);
      if (i > 0)
        new_val = old_val.substring(0, i + this.token.length) + new_val;
    }
    if (old_val != new_val)
      this.input_elem.value = new_val;
    this.schedule_hide();
  },

// ------------------------------ Pulldown ------------------------------

  // Create div for pulldown.
  create_pulldown: function () {
    var div1  = document.createElement('div');
    var div2  = document.createElement('div');
    var list  = document.createElement('ul');
    var i, row;
    div1.className = this.pulldown_class;
    div1.appendChild(div2);
    div2.appendChild(list);
    for (i=0; i<this.pulldown_size; i++) {
      row = document.createElement('li');
      row.style.display = 'none';
      this.attach_row_events(row, i);
      list.appendChild(row);
    }
    if (this.do_scrollbar)
      Event.observe(div1, 'scroll', this.our_scroll.bind(this));
    this.input_elem.parentNode.appendChild(div1);
    this.pulldown_elem = div1;
    this.list_elem = list;
  },

  // Add "click" and "mouseover" events to a row of the pulldown menu.
  // Need to do this in a separate method, otherwise row doesn't get
  // a separate value for each row!  Something to do with scope of
  // variables inside for loops.
  attach_row_events: function (e, row) {
    Event.observe(e, 'click', (function () {
      this.select_row(row);
      this.our_change();
    }).bind(this));
    Event.observe(e, 'mouseover', (function() {
      this.highlight_row(row);
    }).bind(this));
  },

  // Get actual row height when it becomes available.
  get_row_height: function () {
    var div = document.createElement('div');
    var ul  = document.createElement('ul');
    var li  = document.createElement('li');
    div.className = this.pulldown_class;
    div.style.display = 'block';
    div.style.border = div.style.margin = div.style.padding = '0px';
    li.innerHTML = 'test';
    ul.appendChild(li);
    div.appendChild(ul);
    document.body.appendChild(div);
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
    var menu    = this.pulldown_elem;
    var inner   = menu.firstChild;
    var list    = this.list_elem;
    var rows    = list.childNodes;
    var size    = this.pulldown_size;
    var scroll  = this.scroll_offset;
    var cur     = this.current_row;
    var matches = this.matches;
    var old_hl  = this.current_highlight;
    var new_hl  = 0;
    var i, x, y;

    if (this.log)
      $('log').innerHTML += "Redraw: matches=" + matches.length +
        ", scroll=" + scroll + ", cursor=" + cur + "<br/>";

    // Get row height if haven't been able to yet.
    this.set_row_height();

    // Update menu text first.
    for (i=0; i<size; i++) {
      x = rows[i].innerHTML;
      if (i+scroll < matches.length) {
        y = matches[i+scroll].escapeHTML();
        if (x != y) {
          if (x == '')
            rows[i].style.display = 'block';
          rows[i].innerHTML = y;
        }
      } else {
        if (x != '') {
          rows[i].innerHTML = '';
          rows[i].style.display = 'none';
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
        rows[old_hl].removeClassName(this.hot_class);
      if (new_hl >= 0)
        rows[new_hl].addClassName(this.hot_class);
    }

    // Make menu visible if nonempty.
    if (matches.length > 0) {
      Position.clone(this.input_elem, menu, {
        setHeight: false,
        setWidth: false,
        offsetTop: this.input_elem.offsetHeight
      });
      menu.style.display = 'block';

      // Set height of menu.
      if (this.do_scrollbar) {
        menu.style.overflowY  = matches.length > size ? 'scroll' : 'hidden';
        menu.style.height     = '' + this.row_height * (size < matches.length - scroll ? size : matches.length - scroll) + 'px';
        inner.style.marginTop = '' + this.row_height * scroll + 'px';
        inner.style.height    = '' + this.row_height * (matches.length - scroll) + 'px';
        menu.scrollTop        = this.row_height * scroll;
      }

      // Set width of menu.
      this.set_width();
      this.update_width();

      // Scroll the *window* so that menu is visible.
      Element.ensureVisible(menu);

      // Cancel scheduled hide.
      if (matches.length > 1 || this.input_elem.value != matches[0]) {
        this.clear_hide();
        this.active = true;
      }
    }

    // Else hide it if now empty.
    else {
      menu.style.display = "none";
      this.active = false;
    }

    // Make sure input focus stays on text field!
    this.input_elem.focus();
  },

  // Hide pulldown options.
  hide_pulldown: function () {
    this.verbose("hide_pulldown()");
    this.pulldown_elem.style.display = 'none';
    this.active = false;
  },

  // Update width of pulldown.
  update_width: function () {
    this.verbose("update_width()");
    var w = this.list_elem.offsetWidth;
    if (this.do_scrollbar && this.matches.length > this.pulldown_size)
      w += this.scrollbar_width;
    if (this.current_width < w) {
      this.current_width = w;
      this.set_width();
    }
  },

  // Set width of pulldown.
  set_width: function () {
    this.verbose("set_width()");
    var w1 = this.current_width;
    var w2 = w1;
    if (this.matches.length > this.pulldown_size)
      w2 -= this.scrollbar_width;
    if (Prototype.Browser.IE)
      this.pulldown_elem.style.width = w1 + 'px';
    this.list_elem.style.minWidth = w2 + 'px';
    Element.ensureVisible(this.pulldown_elem);
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

  create_datalist: function() {
    // XXX Create (empty) datalist element with specific id, then attach that to the input field.
  },

  update_datalist: function() {
    // XXX Update the list of children (<option> elements) inside the datalist.
  },

// ------------------------------ Matches ------------------------------

  // Update content of pulldown.
  update_matches: function () {
    this.verbose("update_matches()");
    // Remember which option used to be highlighted.
    var last = this.current_row < 0 ? null : this.matches[this.current_row];

    // Update list of options appropriately.
    if (this.collapse > 0)
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
    this.current_width = this.input_elem.getWidth();
  },

  // Grab all matches, doing exact match, ignoring number of words.
  update_normal: function () {
    var val = "\n" + this.last_token(this.input_elem.value).toLowerCase();
    var options  = this.options;
    var options2 = this.options.toLowerCase();
    var matches = [];
    for (var i=options2.indexOf(val); i>=0; i=options2.indexOf(val, i+1)) {
      var j = options.indexOf("\n", i+1);
      var s = options.substring(i+1, j>0 ? j : options.length);
      if (s.length > 0) {
        matches.push(s);
        if (matches.length >= this.max_matches)
          break;
      }
    }
    this.matches = matches;
  },

  // Grab matches ignoring order of words.
  update_unordered: function () {
    var val = this.last_token(this.input_elem.value).toLowerCase().
                   replace(/^ */, '').replace(/  +/g, ' ');
    var vals = val.split(' ');
    var options  = this.options;
    var options2 = this.options.toLowerCase();
    var matches = [];
    var j, j1, j2;
    var k, s, s2;
    for (var i=0; i>=0; i=j) {
      j1 = options2.indexOf("\n" + vals[0], i) + 1;
      j2 = options2.indexOf(" " + vals[0], i) + 1;
      if (!j1 && !j2) break;
      j = j1 && j1 < j2 || !j2 ? j1 : j2;
      i = options2.lastIndexOf("\n", j);
      j = options2.indexOf("\n", i+1);
      s = options.substring(i+1, j>0 ? j : options.length);
      if (s.length > 0) {
        s2 = ' ' + options2.substring(i+1, j>0 ? j : options.length);
        for (k=1; k<vals.length; k++) {
          if (s2.indexOf(' ' + vals[k]) < 0)
            break;
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
  update_collapsed: function (val) {
    var val = "\n" + this.last_token(this.input_elem.value).toLowerCase();
    var options  = this.options;
    var options2 = this.options.toLowerCase();
    var matches  = [];
    var the_rest = (val.match(/ /g) || []).length >= this.collapse;
    for (var i=options2.indexOf(val); i>=0; i=options2.indexOf(val, i+1)) {
      var j = options.indexOf("\n", i+1);
      var s = options.substring(i+1, j>0 ? j : options.length);
      if (s.length > 0) {
        if (the_rest || s.indexOf(' ', val.length-1) < val.length-1) {
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
    if (matches.length == 1 && "\n" + matches[0] == val)
      matches.pop();
    this.matches = matches;
  },

  // Remove duplicates from a sorted array.
  remove_dups: function (list) {
    var i, j;
    for (i=0, j=1; j<list.length; j++) {
      if (list[j] != list[i])
        list[++i] = list[j];
    }
    if (++i < list.length)
      list.splice(i, list.length - i);
    return list;
  },

  // Get last token, the one being auto-completed.
  last_token: function (val) {
    if (this.token) {
      var i = val.lastIndexOf(this.token);
      if (i >= 0)
        val = val.substring(i + this.token.length, val.length);
    }
    return val;
  },

  // Look for 'val' in list of matches and highlight it, otherwise highlight first.
  update_current_row: function (val) {
    this.verbose("update_current_row()");
    var matches = this.matches;
    var size  = this.pulldown_size;
    var exact = -1;
    var part  = -1;
    var new_scr, new_row, i;
    if (val && val.length > 0) {
      for (i=0; i<matches.length; i++) {
        if (matches[i] == val) {
          exact = i;
          break;
        }
        if (matches[i] == val.substr(0, matches[i].length) &&
             (part < 0 || matches[i].length > matches[part].length))
          part = i;
      }
    }
    new_row = exact >= 0 ? exact : part >= 0 ? part : matches.length > 0 ? 0 : -1;
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
    var val = this.last_token(this.input_elem.value).toLowerCase();
    var url;

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
  send_ajax_request: function(val) {
    this.verbose("send_ajax_request()");
    if (val.length > this.max_request_length)
      val = val.substr(0, this.max_request_length);

    if (this.log)
      $('log').innerHTML += "Sending AJAX request: " + val + "<br/>";

    // Need to doubly-encode this to prevent router from interpreting slashes, dots, etc.
    url = this.ajax_url.replace('@', encodeURIComponent(encodeURIComponent(val.replace(/\./g, '%2e'))));

    this.last_ajax_request = val;

    if (this.ajax_request)
      this.ajax_request.abort();

    this.ajax_request = new Ajax.Request(url, {
      asynchronous: true,

      onFailure: (function (response) {
        this.ajax_request = null;
        alert(response.responseText);
      }).bind(this),

      onComplete: (function (response) {
        this.process_ajax_response(response.responseText);
      }).bind(this)
    });
  },


  // Process response from server:
  // 1. first line is string actually used to match;
  // 2. the last string is "..." if the set of results is incomplete;
  // 3. the rest are matching results.
  process_ajax_response: function(response) {
    this.verbose("process_ajax_response()");
    var new_opts, i;

    // Clear flag telling us request is pending.
    this.ajax_request = null;

    // Grab list of matching strings.
    i = response.indexOf("\n");
    new_opts = response.substring(i);

    // Record string actually used to do matching: might be less strict
    // than one sent in request.
    this.last_ajax_request = response.substr(0, i);

    // Make sure there's a trailing newline.
    if (new_opts.charAt(new_opts.length-1) != "\n")
      new_opts += "\n";

    // Check for trailing "..." signaling incomplete set of results.
    if (new_opts.substr(new_opts.length-5, 5) == "\n...\n") {
      this.last_ajax_incomplete = true;
      new_opts = new_opts.substr(0, new_opts.length - 4);
      this.schedule_refresh(); // (just in case we need to refine the request)
    } else {
      this.last_ajax_incomplete = false;
    }

    // Log requests and responses if in debug mode.
    if (this.log) {
      $('log').innerHTML += "Got response for " + this.last_ajax_request.escapeHTML() +
        ": " + (new_opts.split("\n").length-2) + " strings (" +
        (this.last_ajax_incomplete ? "incomplete" : "complete") + ").<br/>";
    }

    // Tack on primer if available.
    if (this.primer)
      new_opts = "\n" + this.primer + new_opts;

    // Update menu if anything has changed.
    if (this.options != new_opts) {
      this.options = new_opts;
      this.update_matches();
      if (this.do_datalist)
        this.update_datalist();
      else
        this.draw_pulldown();
    }
  },

// ------------------------------ Primer ------------------------------

  update_primer: function () {
    var val = this.input_elem.value.replace(/^\s+/,'').replace(/\s+$/,'');
    if (val == "") return;
    var primer = this.primer;
    var j, s;
    for (var i=primer.indexOf("\n"); i>=0; i=j) {
      j = primer.indexOf("\n", i+1);
      s = primer.substring(i+1, j>0 ? j : primer.length);
      if (s == val)
        return;
    }
    this.primer += "\n" + val;
    this.options += "\n" + val;
  },

  verbose: function (str) {
    // $('log').innerHTML += str + "<br/>";
  }
});
