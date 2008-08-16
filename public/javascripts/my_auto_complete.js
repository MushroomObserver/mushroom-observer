var NameAutocompleter;

// NOTE: THIS MUST GO **BEFORE** the text_field_with_autocomplete tags
function extend_ajax_autocompleter() {

  var MyAutocompleter = {
    // Insert this code at the top of the render() method:
    // changes div's scroll offset to keep highlighted list item in view.
    old_render: Ajax.Autocompleter.prototype.render,
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

    // Overwrite default onShow callback to have it NOT set the width.
    old_show: Ajax.Autocompleter.prototype.show,
    show: function() {
      if (Element.getStyle(this.update, 'display') == 'none') {
        if(!this.update.style.position || this.update.style.position == 'absolute') {
          this.update.style.position = 'absolute';
          Position.clone(this.element, this.update, {
            setHeight: false,
            setWidth: this.options.inherit_width,
            offsetTop: this.element.offsetHeight
          });
        }
        Element.show(this.update);
        if (this.options.onShow != this.old_show)
          this.options.onShow(this.element, this.update);
      }
      this.old_show();
    },

    // Rewrite these methods to prevent wrapping on keyboard up/down.
    markPrevious: function()
      { if(this.index > 0) this.index-- },
    markNext: function()
      { if(this.index < this.entryCount-1) this.index++ },

    // Have to move indicators each time we show them, just in case
    // the user has resized the window or some such.
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
    }
  };

  // Javascript doensn't do inheritance gracefully.  Scriptaculous
  // provides this handy "extend" method to accomplish the equivalent.
  // It inserts methods from second (my) class into the first (theirs).
  // In this case, it will overwrite a number of theirs with my own.
  Object.extend(Autocompleter.Base.prototype, MyAutocompleter);
  Object.extend(Ajax.Autocompleter.prototype, MyAutocompleter);

  // -----------------------------------------------------------------------------

  // Build NameAutocompleter on top of Ajax.Autocompleter.
  NameAutocompleter = Class.create();
  Object.extend(NameAutocompleter.prototype, Ajax.Autocompleter.prototype);
  Object.extend(NameAutocompleter.prototype, {

    old_initialize: Ajax.Autocompleter.prototype.initialize,
    initialize: function(element, update, url, options) {
      options.indicator = 'indicator';
      options.frequency = 0.1;
      options.allow_hide = true;
      this.species = [];
      this.loading = false;
      this.letter  = null;
	  this.old_initialize(element, update, url, options);
    },

    old_hide: Ajax.Autocompleter.prototype.hide,
    hide: function() {
      if (this.allow_hide) {
        this.old_hide();
        this.allow_hide = false;
      }
    },

    old_onKeyPress: Ajax.Autocompleter.prototype.onKeyPress,
    onKeyPress: function(event) {
      if (this.active)
        switch(event.keyCode) {
        case Event.KEY_TAB:
        case Event.KEY_RETURN:
          this.selectEntry();
          Event.stop(event);
          return;
        }
      this.allow_hide = true;
      this.old_onKeyPress(event);
    },

    old_onBlur: Ajax.Autocompleter.prototype.onBlur,
    onBlur: function(event) {
      this.allow_hide = true;
      this.old_onBlur(event);
      if (this.options.onChange)
        (this.options.onChange.bind(this))(this.element.value);
    },

    selectEntry: function() {
      this.updateElement(this.getCurrentEntry());
      this.getUpdatedChoices();
    },

    onComplete: function(request) {
      var list = this.species = [];
      var str = request.responseText;
      var x;
      while ((x = str.indexOf("\n")) >= 0) {
        list.push(str.substr(0, x));
        str = str.substr(x+1);
      }
      this.loading = false;
      if (list.length > 0)
        this.getUpdatedChoices();
    },

    old_getUpdatedChoices: Ajax.Autocompleter.prototype.getUpdatedChoices,
    getUpdatedChoices: function() {
      var part = this.getToken();

      // Need to request list for new first-letter?
      if (this.letter == null || part.charAt(0) != this.letter) {
        this.letter = part.charAt(0);
        if (this.species.length == 0 || this.species[0].charAt(0) != this.letter) {
          this.loading = true;
          this.old_getUpdatedChoices();
          return;
        }
      } else if (this.loading) {
        return;
      }

      var plen = part.length;
      var space = part.indexOf(' ') > 0;
      var results = [];
      var more_detail = false;

      // Get list of matches.
      for (var i=0; i<this.species.length; i++) {
        var str = this.species[i];
        if (str.substr(0,plen) == part) {
          if (str.length > plen)
            more_detail = true;
          results.push(i);
        }
      }

      // Abort if no matches, or we have an exact match and nothing else.
      if (more_detail) {
        if (results.length > 1) {
          // Suppress genus if only one matches, display only species now.
          if (this.species[results[0]] == part)
            results.shift();

          // Suppress species when still choosing among multiple genera.
          else {
            var genera = 0;
            for (var i=0; i<results.length; i++)
              if (this.species[results[i]].substr(plen).indexOf(' ') < 0)
                genera++;
            if (genera > 1) {
              new_results = [];
              for (var i=0; i<results.length; i++)
                if (this.species[results[i]].substr(plen).indexOf(' ') < 0)
                  new_results.push(results[i]);
              results = new_results;
            }
          }
        }
      } else {
        results = [];
      }

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
        html += "<li><nobr>" + this.species[results[i]] + "</nobr></li>\n";
      html = "<ul>\n" + html + "</ul>\n";
      this.updateChoices(html);
    }
  });
}
