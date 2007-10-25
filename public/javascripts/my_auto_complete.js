function extend_ajax_autocompleter() {
  // NOTE: THIS MUST GO **BEFORE** the text_field_with_autocomplete tags //
  var old_render = Ajax.Autocompleter.prototype.render;
  var MyAutocompleter = {
      // Insert this code at the top of the render() method:
      // changes div's scroll offset to keep highlighted list item in view.
      old_render: old_render,
      render: function() {
        var e = this.getEntry(this.index);
        var ey = e.y || e.offsetTop;
        var eh = e.offsetHeight;
        var uy = this.update.scrollTop;
        var uh = this.update.offsetHeight - 17;
        var ny = ey+eh > uy+uh ? ey+eh - uh : uy;
        ny = ey < ny ? ey : ny;
        if (uy != ny)
          this.update.scrollTop = ny;
        this.old_render();
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
          var img_e = $(indicator);
          var txt_e = $(this.element);
          var txt_off = Position.cumulativeOffset(txt_e);
          var txt_x = txt_off[0] + txt_e.offsetWidth - 17;
          var txt_y = txt_off[1] + ((txt_e.offsetHeight - 15) / 2);
          img_e.style.left = txt_x + "px";
          img_e.style.top  = txt_y + "px";
          Element.show(indicator);
        }
      }
  };
  
  // Javascript doensn't do inheritance gracefully.  Scriptaculous
  // provides this handy "extend" method to accomplish the equivalent.
  // It inserts methods from second (my) class into the first (theirs).
  // In this case, it will overwrite a number of theres with my own.
  Object.extend(Ajax.Autocompleter.prototype, MyAutocompleter);
}
