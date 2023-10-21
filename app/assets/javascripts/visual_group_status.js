jQuery(document).ready(function () {

  jQuery("body").on('click', "[data-role='visual_group_status']", function(event){
    event.preventDefault();
    var data = $(this).data();
      visual_group_status(data.imgid, data.vgid, data.status);
  });

  function visual_group_status(imgid, vgid, status) {
    jQuery.ajax("/ajax/visual_group_status/visual_group/" + vgid, {
      data: { imgid: imgid, value: status, authenticity_token: csrf_token() },
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
