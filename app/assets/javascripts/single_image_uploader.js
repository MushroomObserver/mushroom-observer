var x = String.fromCharCode(60);
var y = String.fromCharCode(93);

var IMAGE_FORM = "#{
  i = @images.length - 1
  str = render(:partial => 'form_image', :locals => { :index => i })
  str.gsub!("image_#{i}_", 'image_XXX_')
  str.gsub!("image_id_#{i}", 'image_id_XXX')
  str.gsub!("(#{i})", '(XXX)')
  str.gsub!("[#{i}]", '[XXX]')
  str.sub!("type=\"radio\" value=\"#{i}\"", 'type="radio" value="-XXX"')
  str.sub!("checked=\"checked\" ", '')
  str = escape_javascript(str)
  str.gsub('<', '"+x+"')
  str.gsub(']', '"+y+"')
}";

function auto_image_new(i) {
  if (NEXT_IMAGE_INDEX == i+1) image_new();
  $('image_' + i + '_notes').focus();
}

function image_new() {
  var n = NEXT_IMAGE_INDEX++;
  var form = IMAGE_FORM.replace(/XXX/g, n);
  jQuery('#image_forms').append(form);
  jQuery('#new_image_button').ensureVisible();
  apply_file_input_field_validation("image_" + n + "_image");
  return false;
}

function image_on(i) {
  jQuery('#image_'+i+'_div').show();
  jQuery('#image_'+i+'_less').show();
  jQuery('#image_'+i+'_more').hide();
  var div = jQuery('#image_'+i+'_box');
  div.css("border", '1px solid #888');
  div.ensureVisible();
  if (!CHANGED_DATES[i]) {
    jQuery('#image_'+i+'_when_1i').val( jQuery('#observation_when_1i').val() );
    jQuery('#image_'+i+'_when_2i').val( jQuery('#observation_when_2i').val() );
    jQuery('#image_'+i+'_when_3i').val( jQuery('#observation_when_3i').val() );
  }
  return false;
}

function image_off(i) {
  jQuery('#image_'+i+'_more').show();
  jQuery('#image_'+i+'_div').hide();
  jQuery('#image_'+i+'_less').hide();
  jQuery('#image_'+i+'_box').css("border", "0");
  return false;
}
