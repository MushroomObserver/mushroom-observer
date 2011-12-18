// From some post on stackoverflow...
Prototype.Browser.IE6 = Prototype.Browser.IE && parseInt(navigator.userAgent.substring(navigator.userAgent.indexOf("MSIE")+5)) == 6;
Prototype.Browser.IE7 = Prototype.Browser.IE && parseInt(navigator.userAgent.substring(navigator.userAgent.indexOf("MSIE")+5)) == 7;
Prototype.Browser.IE8 = Prototype.Browser.IE && !Prototype.Browser.IE6 && !Prototype.Browser.IE7;

var MOAutocompleter = Class.create({
  initialize: function(opts) {

    // These are potentially useful parameters the user might want to tweak.
    Object.extend(this, {
      input_id:           null,             // id of text field
      input_elem:         null,             // DOM element of text field
      pulldown_id:        null,             // id of pulldown div
      pulldown_class:     'autocompleter',  // class of pulldown div
      hot_class:          'hot',            // class of <li> when highlighted
      collapse:           0,                // 0 = normal mode
                                            // 1 = autocomplete first word, then the rest
                                            // 2 = autocomplete first word, then second word, then the rest
                                            // N = etc.
      pulldown_size:      10,               // maximum number of options shown at a time
      token:              null,             // separator between options
      primer:             null,             // initial list of options
      options:            '',               // list of all options
      ajax_url:           null,             // where to request options from
      refresh_delay:      0.10,             // how long to wait before sending AJAX request (seconds)
      hide_delay:         0.25,             // how long to wait before hiding pulldown (seconds)
      key_delay1:         0.50,             // initial key repeat delay (seconds)
      key_delay2:         0.03,             // subsequent key repeat delay (seconds)
      page_size:          10,               // amount to move cursor on page up and down
      scroll_height:      10,               // number of rows to show before adding scrollbar
      row_height:         20,               // approximate height of a row in pixels (updates automatically when exact value known)
      max_request_length: 50                // max length of string to send via AJAX
    });
    Object.extend(this, opts);

    // These are internal state variables the user should leave alone.
    Object.extend(this, {
      datalist_elem:        null,           // DOM element of datalist
      pulldown_elem:        null,           // DOM element of pulldown div
      list_elem:            null,           // DOM element of pulldown ul
      active:               false,          // is pulldown visible and active?
      old_value:            '',             // previous value of input field
      matches:              [],             // list of options currently showing
      current_row:          0,              // number of option currently highlighted (0 = none)
      current_value:        null,           // value currently highlighted (null = none)
      current_highlight:    -1,             // row of view highlighted (-1 = none)
      scroll_offset:        0,              // scroll offset
      focused:              false,          // do we have input focus?
      last_ajax_request:    null,           // last ajax request we got results for
      last_ajax_incomplete: true,           // did we get all the results we requested last time?
      ajax_request:         null,           // ajax request while underway
      refresh_timer:        null,           // timer used to delay update after typing
      hide_timer:           null,           // timer used to delay hiding of pulldown
      key_timer:            null,           // timer used to emulate key repeat
      do_scrollbar:         null,           // should we allow scrollbar? some browsers just can't handle it, e.g., old IE
      do_datalist:          null            // implement using <datalist> instead of doing pulldown ourselves
    });

    // Check if browser can handle doing scrollbar.
    this.do_scrollbar =
      Prototype.Browser.IE ? Prototype.Browser.IE8 : true;

    // Get the DOM element of the input field.
    if (!this.input_elem)
      this.input_elem = $(this.input_id);
    if (!this.input_elem)
      alert("MOAutocompleter: Invalid input id: \"" + this.input_id + "\"");

    // Disable default browser autocomplete.
    this.input_elem.setAttribute('autocomplete','off');

    // Initialize options.
    this.options = "\n" + this.primer + "\n" + this.options;

    // Create datalist if browser is capable.
    if (this.do_datalist) {
      this.create_datalist();
    }

    // Create pulldown and attach events if we have to do it ourselves.
    else {
      this.create_pulldown();
      Event.observe(this.input_elem, 'keydown',  this.on_keydown.bindAsEventListener(this));
      Event.observe(this.input_elem, 'keyup',    this.on_keyup.bindAsEventListener(this));
      Event.observe(this.input_elem, 'keypress', this.on_keypress.bindAsEventListener(this));
      Event.observe(this.input_elem, 'blur',     this.on_blur.bindAsEventListener(this));
    }

    // Restore field value when user "goes back" to this page.  Only really need
    // this for firefox browsers which handle the autocomplete="off" attribute,
    // but it shouldn't hurt to do it for all browsers.  Problem is, if
    // autocomplete="off" is set, Firefox deliberately *erases* the field value to
    // prevent potentially sensitive information from being visible to random
    // people walking by a terminal and pressing "back" button.  This fix just
    // sets it right back to the old value.  So there. 
    Event.observe(document, 'focus', (function () {
      this.input_elem.value = this.old_value;
    }).bind(this));
  },

// ------------------------------ Events ------------------------------ 

  // User pressed a key in the text field.
  on_keydown: function (event) {
    // $("log").innerHTML += "keydown(" + event.keyCode + ")<br/>";
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
          if (this.current_row > 0)
            this.select_row(this.current_row - this.scroll_offset - 1);
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
  },

  // Need to prevent these keys from being processed by form.
  on_keypress: function (event) {
    // $("log").innerHTML += "keypress(" + event.keyCode + ")<br/>";
    switch (event.keyCode) {
      case Event.KEY_RETURN:
      case Event.KEY_TAB:
        if (this.active)
          Event.stop(event);
    }
  },

  // User has released a key.
  on_keyup: function (event) {
    // $("log").innerHTML += "keyup()<br/>";
    this.clear_key();
    this.on_change();
  },

  // Input field has changed.
  on_change: function () {
    // $("log").innerHTML += "on_change(" + this.input_elem.value + ")<br/>";
    if (this.input_elem.value != this.old_value)
      this.schedule_refresh();
  },

  // User left the text field.
  on_blur: function (event) {
    // $("log").innerHTML += "on_blur()<br/>";
    this.schedule_hide();
  },

// ------------------------------ Timers ------------------------------ 

  // Schedule options to be refreshed after polite delay.
  schedule_refresh: function () {
    this.clear_refresh();
    this.refresh_timer = setTimeout((function() {
      // $("log").innerHTML += "refresh_timer(" + this.input_elem.value + ")<br/>";
      this.old_value = this.input_elem.value;
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
  move_cursor: function (rows) {
    var old_row = this.current_row;
    var new_row = old_row + rows;
    var scroll = this.scroll_offset;

    // Move cursor, but keep in bounds.
    if (new_row < 1)
      new_row = old_row > 0 ? 1 : 0;
    if (new_row > this.matches.length)
      new_row = this.matches.length;
    this.current_row = new_row;
    this.current_value = new_row > 0 ? this.matches[new_row-1] : null;

    // Scroll view so new row is visible.
    if (new_row - 1 < scroll)
      scroll = new_row - 1;
    if (scroll < 0)
      scroll = 0;
    if (new_row > scroll + this.pulldown_size)
      scroll = new_row - this.pulldown_size;
    this.scroll_offset = scroll;
    this.draw_pulldown();
  },

  // Go to first / last match.
  go_home: function () {
    this.current_row = this.matches.length > 0 ? 1 : 0;
    this.scroll_offset = 0;
    this.draw_pulldown();
  },
  go_end: function () {
    this.current_row = this.matches.length;
    this.scroll_offset = this.matches.length - this.pulldown_size;
    if (this.current_row < 0) this.current_row = 0;
    if (this.scroll_offset < 0) this.scroll_offset = 0;
    this.draw_pulldown();
  },

  // Mouse has moved over a menu item.
  highlight_row: function (new_hl) {
    var rows = this.list_elem.childNodes;
    var old_hl = this.current_highlight;
    this.current_highlight = new_hl;
    this.current_row = this.scroll_offset + new_hl + 1;
    if (old_hl != new_hl) {
      if (old_hl >= 0)
        rows[old_hl].removeClassName('hot');
      if (new_hl >= 0)
        rows[new_hl].addClassName('hot');
    } 
    this.input_elem.focus();
  },

  // Called when users scrolls via scrollbar.
  on_scroll: function () {
    this.scroll_offset = Math.round(this.pulldown_elem.scrollTop / this.row_height);
    if (this.current_row < this.scroll_offset + 1)
      this.current_row = this.scroll_offset + 1;
    if (this.current_row > this.scroll_offset + this.pulldown_size)
      this.current_row = this.scroll_offset + this.pulldown_size;
    this.draw_pulldown();
  },

  // User has selected a value, either pressing tab/return or clicking on an option.
  select_row: function (row) {
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
    var div1 = document.createElement('div');
    var div2 = document.createElement('div');
    var list = document.createElement('ul');
    var i, row;
    div1.className = this.pulldown_class;
    div2.style.overflowY = 'hidden';
    div1.appendChild(div2);
    div2.appendChild(list);
    for (i=0; i<this.pulldown_size; i++) {
      row = document.createElement('li');
      row.style.display = 'none';
      this.attach_row_events(row, i);
      list.appendChild(row);
    }
    if (this.do_scrollbar)
      Event.observe(div1, 'scroll', this.on_scroll.bind(this));
    this.input_elem.parentNode.appendChild(div1);
    this.pulldown_elem = div1;
    this.list_elem = list;
  },

  // Redraw the pulldown options.
  draw_pulldown: function () {
    var menu    = this.pulldown_elem;
    var inner   = menu.firstChild;
    var list    = this.list_elem;
    var rows    = list.childNodes;
    var scroll  = this.scroll_offset;
    var cur     = this.current_row;
    var matches = this.matches;
    var old_hl  = this.current_highlight;
    var new_hl  = 0;
    var i, x, y;

    if (this.do_scrollbar) {
      // Make sure row height is accurate.
      if (rows[0].innerHTML != '')
        this.row_height = rows[0].getHeight();

      // Update size and offset of visible part.
      menu.style.overflowY  = matches.length > rows.length ? 'scroll' : 'hidden';
      menu.style.height     = '' + this.row_height * (rows.length < matches.length - scroll ? rows.length : matches.length - scroll) + 'px';
      inner.style.marginTop = '' + this.row_height * scroll + 'px';
      inner.style.height    = '' + this.row_height * (matches.length - scroll) + 'px';
      menu.scrollTop        = this.row_height * scroll;
    }

    // Update menu text first.
    for (i=0; i<rows.length; i++) {
      x = rows[i].innerHTML;
      if (i+scroll < matches.length) {
        y = matches[i+scroll].replace(/ /g, '&nbsp;');
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
    new_hl = cur - scroll - 1;
    if (new_hl < 0 || new_hl >= rows.length)
      new_hl = -1;
    this.current_highlight = new_hl;
    if (new_hl != old_hl) {
      if (old_hl >= 0)
        rows[old_hl].removeClassName('hot');
      if (new_hl >= 0)
        rows[new_hl].addClassName('hot');
    }

    // Make menu visible if nonempty.
    if (matches.length > 0) {
      Position.clone(this.input_elem, menu, {
        setHeight: false,
        setWidth: true,
        offsetTop: this.input_elem.offsetHeight
      });
      menu.style.display = "block";
      Element.ensureVisible(menu);
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

  // Add "click" and "mouseover" events to a row of the pulldown menu.
  // Need to do this in a separate method, otherwise row doesn't get
  // a separate value for each row!  Something to do with scope of
  // variables inside for loops.
  attach_row_events: function (e, row) {
    Event.observe(e, 'click', (function () {
      this.select_row(row);
      this.on_change();
    }).bind(this));
    Event.observe(e, 'mouseover', (function() {
      this.highlight_row(row);
    }).bind(this));
  },

  // Hide pulldown options.
  hide_pulldown: function () {
    this.pulldown_elem.style.display = 'none';
    this.active = false;
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
    if (this.collapse > 0)
      this.update_collapsed();
    else
      this.update_normal();
  },

  // Grab first matches, ignoring number of words, etc.
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
    this.matches = matches.sort();
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
    this.matches = matches.sort();
  },

  // Get last token, the one being auto-completed.
  last_token: function (val) {
    if (this.token) {
      var i = val.last_IndexOf(this.token);
      if (i >= 0)
        val = val.substring(i + this.token.length, val.length);
    }
    return val;
  },

// ------------------------------ AJAX ------------------------------ 

  // Send request for updated options.
  refresh_options: function () {
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
    if (val.length > this.max_request_length)
      val = val.substr(0, this.max_request_length);
    url = this.ajax_url.replace('@', encodeURIComponent(val));

    this.last_ajax_request = val;

    if (this.ajax_request)
      this.ajax_request.abort();

    this.ajax_request = new Ajax.Request(url, {
      asynchronous: true,

      onFailure: (function (response) {
        this.ajax_request = null;
        this.last_ajax_incomplete = false;
        alert("AJAX request failed:\n" + url);
      }).bind(this),

      onComplete: (function (response) {
        this.process_ajax_response(response.responseText);
      }).bind(this)
    });
  },

  
  // Process response from server.
  process_ajax_response: function(response) {
    var new_opts = "\n" + response;
    this.ajax_request = null;
    if (new_opts.charAt(new_opts.length-1) != "\n") {
      new_opts += "\n";
    }
    if (new_opts.substr(new_opts.length-5, 5) == "\n...\n") {
      this.last_ajax_incomplete = true;
      new_opts = new_opts.substr(0, new_opts.length - 4);
      this.schedule_refresh(); // (just in case we need to refine the request)
    } else {
      this.last_ajax_incomplete = false;
    }
    if (this.log) {
      $("log").innerHTML += "Got response for " + this.last_ajax_request +
        ": " + (new_opts.split("\n").length-2) + " strings (" +
        (this.last_ajax_incomplete ? "incomplete" : "complete") + ").<br/>";
    }
    if (this.primer) {
      new_opts = "\n" + this.primer + new_opts;
    }
    if (this.options != new_opts) {
      this.options = new_opts;
      this.update_matches();
      if (this.do_datalist)
        this.update_datalist();
      else
        this.draw_pulldown();
    }
  }
});

// Thanks to: The Pothoven Post, 19 December 2007.
Ajax.Request.prototype.abort = function() {
  // prevent and state change callbacks from being issued
  this.transport.onreadystatechange = Prototype.emptyFunction;
  // abort the XHR (if implemented by browser!)
  if ("abort" in this.transport)
    this.transport.abort();
  // update the request counter
  if (Ajax.activeRequestCount > 0)
    Ajax.activeRequestCount--;
}

