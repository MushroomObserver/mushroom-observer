
var base = Autocompleter.Base;
var CachedAutocompleter = Class.create(base, {
  initialize: function(element, update, url, options) {
    this.baseInitialize(element, update, options);

    // Ajax initialization.
    this.options.asynchronous  = true;
    this.options.onComplete    = this.onComplete.bind(this);
    this.options.defaultParams = this.options.parameters || null;
    this.url                   = url;

    // Initialization for our modifications.
    this.lastValue = element.value;
    this.allowHide = true;
    this.loading   = false;
    this.letter    = null;
    this.cache     = [];
    this.primer    = this.options.primer || [];

    // Install onChange callback as a method.  (I have it call this whenever
    // the user clicks or presses tab/return, or when they leave the field.)
    this.onChange = options.onChange ? options.onChange.bind(this) : null;

    // If we want pulldown to show instantly on focus, need to watch event.
    if (this.options.instant) {
      Event.observe(this.element, 'focus', this.activate.bindAsEventListener(this));
      this.options.minChars = -1;
    }

    // Overwrite default onShow callback to have it NOT set the width.
    this.options.onShow = function(element, update) { 
      if (!update.style.position || update.style.position == 'absolute') {
        update.style.position = 'absolute';
        Position.clone(element, update, {
          setHeight: false, 
          setWidth: (options.inheritWidth ? true : false),
          offsetTop: element.offsetHeight
        });
      }
      Element.show(update);
    };
  },

  // Insert this code at the top of the render() method to change the div's
  // scroll offset to keep highlighted list item in view.
  old_render: base.prototype.render,
  render: function() {
    var e = this.getEntry(this.index);
    if (e) {
      var ey = e.y || e.offsetTop;
      var eh = e.offsetHeight;
      var uy = this.update.scrollTop;
      var uh = this.update.offsetHeight - 17;
      var ny = ey+eh > uy+uh ? ey+eh - uh : uy;
      ny = ey < ny ? ey : ny;
      if (uy != ny)
        this.update.scrollTop = ny;
    }
    this.old_render();
  },

  // Rewrite these methods to prevent wrapping on keyboard up/down.
  markPrevious: function()
    { if(this.index > 0) this.index-- },
  markNext: function()
    { if(this.index < this.entryCount-1) this.index++ },

  // Have to move indicator each time we show it, just in case the user has
  // resized the window or something.
  startIndicator: function() {
    var indicator = this.options.indicator;
    if (indicator) {
      var e = $(this.element);
      Position.clone(this.element, indicator, {
        setWidth: false,
        setHeight: false,
        offsetTop: (e.offsetHeight - 15) / 2,
        offsetLeft: (e.offsetWidth - 17)
      });
      Element.show(indicator);
    }
  },

  // Use this.allowHide to let me prevent it from hiding the dropdown.
  old_hide: base.prototype.hide,
  hide: function() {
    if (this.allowHide) {
      this.old_hide();
      this.allowHide = false;
    }
  },

  // Override default behavior for tab and return: we don't want it to hide the
  // dropdown -- just select the current entry (and possibly redraw dropdown).
  old_onKeyPress: base.prototype.onKeyPress,
  onKeyPress: function(event) {
    if (this.active)
      switch(event.keyCode) {
      case Event.KEY_TAB:
      case Event.KEY_RETURN:
        this.selectEntry();
        Event.stop(event);
        return;
      }
    this.allowHide = true;
    this.old_onKeyPress(event);
  },

  // When user clicks on an item we want it to keep the dropdown open.
  old_onClick: base.prototype.onClick,
  onClick: function(event) {
    this.element.focus();
    this.hasFocus = true;
    this.allowHide = false;
    this.old_onClick(event);
  },

  // When user leaves the field, allow it to hide the dropdown, and call the
  // onChange callback if the value has changed.
  old_onBlur: base.prototype.onBlur,
  onBlur: function(event) {
    this.allowHide = true;
    this.old_onBlur(event);
    if (this.onChange && this.element.value != this.lastValue)
      this.onChange(this.element.value);
    this.lastValue = this.element.value;
  },

  // Get index of first and last character of current token.
  getTokenBounds: function() {
    if (this.tokenBounds != null)
      return this.tokenBounds;
    var value = this.element.value;
    var a=0, b=value.length-1;
    if (this.options.tokens.length > 0) {
      var seps = this.options.tokens;
      var num = seps.length
      var diff = 0;
      var old_value = this.oldElementValue;
      while (diff < value.length && diff < old_value.length) {
        if (value.substring(0, diff+1) != old_value.substring(0, diff+1))
          break;
        diff++;
      }
      for (var i=0; i<num; i++) {
        var x = value.substr(0,diff+1).lastIndexOf(seps[i]);
        if (x > -1) {
          a = x + seps[i].length;
          break;
        }
      }
      for (var i=0; i<num; i++) {
        var x = value.substr(diff).indexOf(seps[i]);
        if (x > -1) {
          b = diff + x - 1;
          break;
        }
      }
    }
    return (this.tokenBounds = [a, b]);
  },

  // Get the current token (without separators, unstripped).
  getToken: function() {
    var value = this.element.value;
    if (this.options.tokens.length > 0) {
      var bounds = this.getTokenBounds();
      value = value.substring(bounds[0], bounds[1]+1);
    }
    return value;
  },

  // Replace the current token with the given value (unstripped).
  replaceToken: function(value) {
    if (this.options.tokens.length > 0) {
      var bounds = this.getTokenBounds();
      var whole = this.element.value;
      if (bounds[0] > 0)
        value = whole.substring(0, bounds[0]) + value;
      if (bounds[1] < whole.length)
        value = value + whole.substring(bounds[1] + 1);
    }
    this.oldElementValue = this.element.value = value;
    this.tokenBounds = null;
  },

  // When an entry is selected we need to run getUpdatedChoices() again in case
  // there are multiple choices that have been collapsed (e.g. species under a
  // given genus).  Also, leave it active.
  selectEntry: function() {
    this.updateElement(this.getCurrentEntry());
    this.getUpdatedChoices();
  },

  // Scriptaculous messes this up, too.  How did this ever work for them??!
  updateElement: function(selectedElement) {
    var value = '';
    if (this.options.select) {
      var nodes = $(selectedElement).select('.' + this.options.select) || [];
      if (nodes.length > 0)
        value = Element.collectTextNodes(nodes[0], this.options.select);
    } else {
      value = Element.collectTextNodesIgnoreClass(selectedElement, 'informal');
    }
    if (this.options.collapse && value.indexOf(' ') < 0)
      value += ' ';
    this.replaceToken(value);
    this.element.focus();
    if (this.options.afterUpdateElement)
      this.options.afterUpdateElement(this.element, selectedElement);
  },

  // This is called when AJAX request returns: result is a list of items, one
  // per line.  (Letter request is prepended as the first character, just in
  // case the matches don't necessarily start with the requested letter.)
  onComplete: function(request) {
    var list = [];
    var str = request.responseText;
    var x;

    // First, extract request letter this is the results for.
    var letter = str.charAt(0).toLowerCase();
    str = str.substr(1);

    // Now extract results, one line at a time.
    while ((x = str.indexOf("\n")) >= 0) {
      if (x > 0)
        list.push(str.substr(0, x));
      str = str.substr(x+1);
    }

    // Try to drop new cache in place "atomically".
    this.cache = list;
    this.cacheLetter = letter;
    this.loading = false;

    // Now we can finally draw dropdown correctly.
    if (list.length > 0)
      this.getUpdatedChoices();
  },

  // This is where the bulk of our modifications go.  This is called whenever
  // the user types something, clicks on something, or otherwise changes the
  // text field.  It checks if the cache is appropriate (based on first letter)
  // and draws the menu of choices as appropriate, collapsing multiple choices
  // that start with the same first word (if this behavior is requested).
  getUpdatedChoices: function() {
    var part = this.getToken();
    var results = [];
    var strings;

    // Get first letter.
    var letter = part;
    while (letter.length > 0 && !letter.match(/^[A-Za-z0-9]/))
      letter = letter.substr(1);

    // Display all choices instantly if given 'instant' option.
    if (this.options.instant && part.length == 0) {
      strings = this.primer;
      for (var i=0; i<strings.length; i++)
        results.push(i);
    }

    // Otherwise wait for first letter.
    else if (letter.length > 0) {
      letter = letter.charAt(0).toLowerCase();

      // Need to request list for new first-letter?
      if (!this.options.noAjax && this.letter != letter) {
        this.letter = letter;
        if (this.cache == null || this.cacheLetter != letter) {
          this.loading = true;
          this.startIndicator();
          new Ajax.Request(this.url + '/' + letter, this.options);
        }
      }

      var part2 = part.toLowerCase();
      var part3 = ' ' + part2;
      var part4 = '&lt;' + part2;
      var plen = part.length;
      var more_detail = false;
      var do_words = this.options.wordMatch;

      // Get list of matches.  Search cache from AJAX request first, since
      // that is theoretically guaranteed to be correct (if it's there).
      // If that fails, then try the primer list that comes with the page.
      for (var i=0; i<2; i++) {
        var list = i == 0 ? this.cache : this.primer;
        for (var j=0; j<list.length; j++) {
          var str = list[j].toLowerCase();
          if (str.substr(0,plen) == part2) {
            if (str.length > plen)
              more_detail = true;
            results.push(j);
          } else if (do_words && (str.indexOf(part3) >= 0 ||
                                  str.indexOf(part4) >= 0)) {
            results.push(j);
          }
        }
        if (results.length > 0) {
          strings = list;
          break;
        }
      }

      // Collapse multple choices that all start with the same first word.
      // "more_detail" is true if there are inexact matches.
      if (this.options.collapse && more_detail) {
        if (results.length > 1) {
          // Suppress genus if only one matches, display only species now.
          // if (strings[results[0]].toLowerCase() == part.toLowerCase())
          //   results.shift();

          // Suppress species when still choosing among multiple genera.
          var genera = 0;
          for (var i=0; i<results.length; i++)
            if (strings[results[i]].substr(plen).indexOf(' ') < 0)
              genera++;
          if (genera > 1) {
            new_results = [];
            for (var i=0; i<results.length; i++)
              if (strings[results[i]].substr(plen).indexOf(' ') < 0)
                new_results.push(results[i]);
            results = new_results;
          }
        }
      }
    }

    // Abort if there is only one result and it is an exact match.
    if (results.length == 1 &&
      strings[results[0]].toLowerCase() == part.toLowerCase())
      results = [];

    // Make list scrollable if there are lots of items.
    if (results.length > 10) {
      this.update.style.overflow = "auto";
      this.update.style.height = "250px";
    } else {
      this.update.style.overflow = "hidden";
      this.update.style.height = null;
    }

    // Turn list of choices into an HTML itemized list.
    var html = "";
    for (var i=0; i<results.length; i++)
      html += "<li><nobr>" + strings[results[i]] + "</nobr></li>\n";
    html = "<ul>\n" + html + "</ul>\n";
    this.updateChoices(html);

    // Occasionally gets stuck with opacity turned down, presumably from some
    // random event interrupting Effect.Appear()?  This seems to fix it...
    this.update.setOpacity(1.0);
  }
});
