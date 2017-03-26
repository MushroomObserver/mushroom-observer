function replace_date_select_with_text_field(elem, opts) {
  var old_elem = typeof elem == "string" ? jQuery("#" + elem) : elem;
  var id     = old_elem.attr("id");
  var name   = old_elem.attr("name");
  var klass  = old_elem.attr("class");
  var style  = old_elem.attr("style");
  var value  = old_elem.val();
  var opts   = old_elem[0].options;
  var length = opts.length > 20 ? 20 : opts.length;
  var primer = [];
  for (var i=0; i<opts.length; i++)
    primer.push(opts.item(i).text);
  var new_elem = jQuery("<input type='text' />");
  new_elem.attr({
    class: klass,
    style: style,
    value: value,
    size:  4
  });
  // Not sure if this works yet...
  if (old_elem[0].onchange)
    new_elem.change(old_elem[0].onchange);
  old_elem.replaceWith(new_elem);
  new_elem.attr({
    id:   id,
    name: name
  });
  new MOAutocompleter(jQuery.extend({
    input_elem: new_elem,
    primer: primer.join("\n"),
    pulldown_size: length,
    act_like_select: true
  }, opts))
}
