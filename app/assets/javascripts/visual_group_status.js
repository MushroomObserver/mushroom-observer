jQuery(document).ready(function () {
  // http://api.jquery.com/delegate/

  jQuery("body").delegate("[data-role='visual_group_status']", 'click', function(event){
    event.preventDefault();
    var data = $(this).data();
      visual_group_status(data.imgid, data.vgid, data.need, data.inc);
  });

  function visual_group_status(imgid, vgid, need, value) {
    jQuery.ajax("/ajax/visual_group_status/visual_group/" + vgid, {
      data: { imgid: imgid, need: need, value: value, authenticity_token: csrf_token() },
      dataType: 'text',
      async: true,
      error: function (response) {
        alert(response.responseText);
      },
      success: function(text) {
        var div = jQuery("#visual_group_status_links_" + imgid);
        var $updatedLinks = $updatedLinks = jQuery(text);
        div.html($updatedLinks.find(".visual_group_status_links_container").first().html());
      }
    });
  }
});
