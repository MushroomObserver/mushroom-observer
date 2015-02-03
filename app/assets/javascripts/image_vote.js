jQuery(document).ready(function () {
  // http://api.jquery.com/delegate/

  var $show_votes_container = jQuery('#show_votes_container');
  var $quality_vote_container = jQuery('#quality_vote_container');
  jQuery("body").delegate("[data-role='image_vote']", 'click', function(event){
    event.preventDefault();
    var data = $(this).data();
    image_vote(data.id, data.val);
  });

  function image_vote(id, value) {
    jQuery.ajax("/ajax/vote/image/" + id, {
      data: { value: value, authenticity_token: csrf_token() },
      dataType: 'text',
      async: true,
      error: function (response) {
        alert(response.responseText);
      },
      success: function(text) {
        var div = jQuery("#image_vote_links_" + id).parent();
        div.html(text);
        var newVotePercentage = div.find('span.data_container').data('percentage');
        jQuery("#vote_meter_bar_" + id).css('width', newVotePercentage + "%")
        if ($show_votes_container && $quality_vote_container) { //updates the side bar if on actual image page.
          $show_votes_container.load(window.location + " #show_votes_table");
          $quality_vote_container.load(window.location + " #quality_vote_content");
        }
      }
    });
  }
});
