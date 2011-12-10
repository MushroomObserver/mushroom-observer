var MOAutocompleter = Class.create({
  initialize: function(opts) {

    // These are potentially useful parameters the user might want to tweak.
    Object.extend(this, {
      input_id:           null,             // id of text field
      input_elem:         null,             // DOM element of text field
      pulldown_id:        null,             // id of pulldown div
      pulldown_elem:      null,             // DOM element of pulldown div
      pulldown_class:     'autocompleter',  // class of pulldown div
      hot_class:          'hot',            // class of <li> when highlighted
      collapse:           0,                // 0 = normal mode
                                            // 1 = autocomplete first word, then the rest
                                            // 2 = autocomplete first word, then second word, then the rest
                                            // N = etc.
      max_matches:        10,               // maximum number of options shown at a time
      token:              null,             // separator between options
      primer:             null,             // initial list of options
      options:            '',               // list of all options
      ajax_url:           null,             // where to request options from
      refresh_delay:      0.10,             // how long to wait before sending AJAX request (seconds)
      hide_delay:         0.25,             // how long to wait before hiding pulldown (seconds)
      key_delay1:         0.50,             // initial key repeat delay (seconds)
      key_delay2:         0.03,             // subsequent key repeat delay (seconds)
      page_size:          10,               // amount to move cursor on page up and down
      scroll_height:      10                // number of rows to show before adding scrollbar
    });
    Object.extend(this, opts);

    // These are internal state variables the user should leave alone.
    Object.extend(this, {
      active:               false,          // is pulldown visible and active?
      old_value:            '',             // previous value of input field
      matches:              [],             // list of options currently showing
      current_row:          0,              // number of option currently highlighted (0 = none)
      current_value:        null,           // value currently highlighted (null = none)
      focused:              false,          // do we have input focus?
      last_ajax_request:    null,           // last ajax request we got results for
      last_ajax_incomplete: true,           // did we get all the results we requested last time?
      ajax_request:         null,           // ajax request while underway
      refresh_timer:        null,           // timer used to delay update after typing
      hide_timer:           null,           // timer used to delay hiding of pulldown
      key_timer:            null            // timer used to emulate key repeat
    });

    if (!this.input_elem)
      this.input_elem = $(this.input_id);
    if (!this.input_elem)
      alert("MOAutocompleter: Invalid input id: \"" + this.input_id + "\"");
    if (!this.pulldown_id)
      this.create_pulldown();
    if (!this.pulldown_elem)
      this.pulldown_elem = $(this.pulldown_id);
    if (!this.pulldown_elem)
      alert("MOAutocompleter: Invalid pulldown id: \"" + this.pulldown_id + "\"");

    this.options = "\n" + this.primer + "\n" + this.options;

    Event.observe(this.input_elem, 'keydown', this.on_keydown.bindAsEventListener(this));
    Event.observe(this.input_elem, 'keyup',   this.on_keyup.bindAsEventListener(this));
    Event.observe(this.input_elem, 'blur',    this.on_blur.bindAsEventListener(this));
  },

  // Create div for pulldown if user hasn't already done so.
  create_pulldown: function () {
    var div = document.createElement('div');
    var ul = document.createElement('ul');
    div.className = this.pulldown_class;
    div.appendChild(ul);
    this.input_elem.parentNode.appendChild(div);
    this.pulldown_elem = div;
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
      case Event.KEY_TAB:
      case Event.KEY_RETURN:
        if (this.active) {
          this.select_row(this.current_row);
          Event.stop(event);
          return;
        }
      case Event.KEY_ESC:
        if (this.active) {
          this.lose_focus();
          Event.stop(event);
          return;
        }
      case Event.KEY_PAGEUP:
        if (this.active) {
          this.page_up();
          this.schedule_key(this.page_up);
          Event.stop(event);
          return;
        }
      case Event.KEY_UP:
        if (this.active) {
          this.arrow_up();
          this.schedule_key(this.arrow_up);
          Event.stop(event);
          return;
        }
      case Event.KEY_DOWN:
        if (this.active) {
          this.arrow_down();
          this.schedule_key(this.arrow_down);
          Event.stop(event);
          return;
        }
      case Event.KEY_PAGEDOWN:
        if (this.active) {
          this.page_down();
          this.schedule_key(this.page_down);
          Event.stop(event);
          return;
        }
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
    var new_val = this.input_elem.value;
    // $("log").innerHTML += "on_change(" + new_val + ")<br/>";
    if (this.old_value != new_val) {
      if (this.ajax_url)
        this.schedule_refresh();
      this.update_pulldown();
      this.old_value = new_val;
    }
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
    this.refresh_timer = setTimeout(this.refresh_options.bind(this), this.refresh_delay*1000);
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
    if (new_row < 1)
      new_row = old_row > 0 ? 1 : 0;
    if (new_row > this.matches.length)
      new_row = this.matches.length;
    if (old_row > 0 && old_row != new_row)
      this.highlight_row(old_row, false);
    if (new_row != old_row)
      this.highlight_row(new_row, true);
    this.current_row = new_row;
    this.current_value = new_row > 0 ? this.matches[new_row-1] : null;
  },

  // Change highlight state of row.
  highlight_row: function (row, state) {
    var e = this.pulldown_elem.firstChild.childNodes[row-1];
    if (!state) {
      e.removeClassName('hot');
    } else {
      e.addClassName('hot');
      this.warp_to_row(e);
    }
  },

  // Ensure div is scrolled so that e is visible.
  warp_to_row: function(e) {
    var s = this.pulldown_elem;
    var ey = e.y || e.offsetTop;
    var eh = e.offsetHeight;
    var sy = s.scrollTop;
    var sh = s.offsetHeight;
    var ny = ey+eh > sy+sh ? ey+eh - sh : sy;
    ny = ey < ny ? ey : ny;
    if (sy != ny)
      s.scrollTop = ny;
  },

  // User has selected a value, either pressing return or clicking on an option.
  select_row: function (row) {
    var old_val = this.input_elem.value;
    var new_val = this.matches[row-1];
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

  // Redraw the pulldown options.
  draw_pulldown: function () {
    var menu    = this.pulldown_elem;
    var old_row = this.current_row;
    var old_val = this.current_value;
    var new_row = 1;
    var matches = this.matches;
    var ul      = menu.firstChild;
    var rows    = ul.childNodes;

    // Remove old highlight.
    if (old_row > 0 && old_row <= rows.length)
      rows[old_row-1].removeClassName('hot');

    // Draw text in menu first.
    for (var i=0; i<rows.length; i++) {
      if (i < matches.length) {
        rows[i].innerHTML = matches[i];
        if (matches[i] == old_val)
          new_row = i+1;
      }
    }
    for (var i=rows.length; i<matches.length; i++) {
      var row = document.createElement('li');
      row.innerHTML = matches[i];
      this.attach_onclick(row, i+1);
      ul.appendChild(row);
      if (matches[i] == old_val) {
        new_row = i+1;
        row.addClassName('hot');
      }
    }
    for (var i=rows.length-1; i>=matches.length; i--) {
      ul.removeChild(rows[i]);
    }

    // Choose new row to highlight, if any.
    if (new_row <= rows.length)
      rows[new_row-1].addClassName('hot');
    this.current_row = new_row;
    this.current_value = new_row > 0 ? matches[new_row-1] : null;

    // Make menu visible if nonempty.
    if (matches.length > 0) {
      Position.clone(this.input_elem, menu, {
        setHeight: false,
        setWidth: true,
        offsetTop: this.input_elem.offsetHeight
      });
      if (this.matches.length > this.scroll_height) {
        var w = menu.offsetWidth;
        var h = ul.firstChild.offsetHeight;
        if (!h || h == 0) h = this.input_elem.offsetHeight;
        menu.style.overflowY = 'scroll';
        menu.style.height = h * this.scroll_height + 'px';
      } else {
        menu.style.overflowY = 'hidden';
        menu.style.height = 'auto';
      }
      menu.style.display = "block";
      Element.ensureVisible(menu);
      this.clear_hide();
      this.active = true;
      this.warp_to_row(ul.childNodes[new_row-1])
    }

    // Else hide it if now empty.
    else {
      menu.style.display = "none";
      this.active = false;
    }
  },

  // Add "on click" event to a row of the pulldown menu.
  // Need to do this in a separate method, otherwise row doesn't get
  // a separate value for each row!  Something to do with scope of
  // variables inside for loops.
  attach_onclick: function (e, row) {
    Event.observe(e, 'click', (function () {
      this.select_row(row);
      this.on_change();
    }).bind(this));
  },

  // Hide pulldown options.
  hide_pulldown: function () {
    this.pulldown_elem.hide();
  },

  // Update content of pulldown.
  update_pulldown: function () {
    if (this.collapse > 0)
      this.update_collapsed();
    else
      this.update_normal();
    this.draw_pulldown();
  },

  // Grab first matches, ignoring number of words, etc.
  update_normal: function () {
    var val = "\n" + this.last_token();
    var options = this.options;
    var matches = [];
    for (var i=options.indexOf(val); i>=0; i=options.indexOf(val, i+1)) {
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
    var val = "\n" + this.last_token();
    var options  = this.options;
    var matches  = [];
    var the_rest = (val.match(/ /g) || []).length >= this.collapse;
    for (var i=options.indexOf(val); i>=0; i=options.indexOf(val, i+1)) {
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
  last_token: function () {
    var val = this.input_elem.value;
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
    var val = this.last_token();
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

    if (this.ajax_request)
      this.ajax_request.abort();
    this.last_ajax_request = val;
    url = this.ajax_url.replace('@', encodeURIComponent(val));
    this.ajax_request = new Ajax.Request(url, {
      asynchronous: true,

      onFailure: (function (response) {
        this.ajax_request = null;
        this.last_ajax_incomplete = false;
        alert("AJAX request failed:\n" + url);
      }).bind(this),

      onComplete: (function (response) {
        var new_opts = "\n" + response.responseText;
        this.ajax_request = null;
        if (new_opts.charAt(new_opts.length-1) != "\n")
          new_opts += "\n";
        if (new_opts.substr(new_opts.length-5, 5) == "\n...\n") {
          this.last_ajax_incomplete = true;
          new_opts = new_opts.substr(0, new_opts.length - 4);
          this.schedule_refresh(); // (just in case we need to refine the request)
        } else {
          this.last_ajax_incomplete = false;
        }
        if (this.log)
          $("log").innerHTML += "Got response for " + this.last_ajax_request +
            ": " + (new_opts.split("\n").length-2) + " strings (" +
            (this.last_ajax_incomplete ? "incomplete" : "complete") + ").<br/>";
        if (this.primer)
          new_opts = "\n" + this.primer + new_opts;
        if (this.options != new_opts) {
          this.options = new_opts;
          this.update_pulldown();
        }
      }).bind(this)
    });
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

