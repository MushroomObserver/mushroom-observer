
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

    // Install onChange callback as a method.  (I have it call this whenever
    // the user clicks or presses tab/return, or when they leave the field.)
    this.onChange = options.onChange ? options.onChange.bind(this) : null;

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

  // When an entry is selected we need to run getUpdatedChoices() again in case
  // there are multiple choices that have been collapsed (e.g. species under a
  // given genus).
  selectEntry: function() {
    // Token stuff doesn't seem to work right -- this seems to disable it.
    this.tokenBounds = [-1];
    this.updateElement(this.getCurrentEntry());
    this.getUpdatedChoices();
  },

  // This is called when AJAX request returns: result is a list of items, one
  // per line.  (Letter request is prepended as the first character, just in
  // case the matches don't necessarily start with the requested letter.)
  onComplete: function(request) {
    var list = this.cache = [];
    var str = request.responseText;
    var x;

    // First, extract request letter this is the results for.
    this.cacheLetter = str.charAt(0).toLowerCase();
    str = str.substr(1);

    // Now extract results, one line at a time.
    while ((x = str.indexOf("\n")) >= 0) {
      list.push(str.substr(0, x));
      str = str.substr(x+1);
    }

    // Now we can finally draw dropdown correctly.
    this.loading = false;
    if (list.length > 0)
      this.getUpdatedChoices();
  },

  // This is where the bulk of our modifications go.  This is called whenever
  // the user types something, clicks on something, or otherwise changes the
  // text field.  It checks if the cache is appropriate (based on first letter)
  // and draws the menu of choices as appropriate, collapsing multiple choices
  // that start with the same first word (if this behavior is requested).
  getUpdatedChoices: function() {
    var part = this.element.value;
    var results = [];

    // Get first letter.
    var letter = part;
    while (letter.length > 0 && !letter.match(/^[A-Za-z0-9]/))
      letter = letter.substr(1);
    if (letter.length > 0) {
      letter = letter.charAt(0).toLowerCase();

      // Need to request list for new first-letter?
      if (this.letter != letter) {
        this.letter = letter;
        if (this.cache == null || this.cacheLetter != letter) {
          this.loading = true;
          this.startIndicator();
          this.options.parameters = 'letter=' + letter;
          new Ajax.Request(this.url, this.options);
          return;
        }
      } else if (this.loading) {
        return;
      }

      var part2 = part.toLowerCase();
      var part3 = ' ' + part2;
      var plen = part.length;
      var space = part.indexOf(' ') > 0;
      var more_detail = false;
      var do_words = this.options.wordMatch;

      // Get list of matches.
      for (var i=0; i<this.cache.length; i++) {
        var str = this.cache[i].toLowerCase();
        if (str.substr(0,plen) == part2) {
          if (str.length > plen)
            more_detail = true;
          results.push(i);
        } else if (do_words && str.indexOf(part3) >= 0) {
          results.push(i);
        }
      }

      // Collapse multple choices that all start with the same first word.
      // "more_detail" is true if there are inexact matches.
      if (this.options.collapse && more_detail) {
        if (results.length > 1) {
          // Suppress genus if only one matches, display only species now.
          if (this.cache[results[0]].toLowerCase() == part.toLowerCase())
            results.shift();

          // Suppress species when still choosing among multiple genera.
          else {
            var genera = 0;
            for (var i=0; i<results.length; i++)
              if (this.cache[results[i]].substr(plen).indexOf(' ') < 0)
                genera++;
            if (genera > 1) {
              new_results = [];
              for (var i=0; i<results.length; i++)
                if (this.cache[results[i]].substr(plen).indexOf(' ') < 0)
                  new_results.push(results[i]);
              results = new_results;
            }
          }
        }
      }
    }

    // Abort if there is only one result and it is an exact match.
    if (results.length == 1 &&
      this.cache[results[0]].toLowerCase() == part.toLowerCase())
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
      html += "<li><nobr>" + this.cache[results[i]] + "</nobr></li>\n";
    html = "<ul>\n" + html + "</ul>\n";
    this.updateChoices(html);
  }
});
