// jQuery(document).ready(function () {
//
  // var $show_votes_container = jQuery('#show_votes_container');
  // var $quality_vote_container = jQuery('#quality_vote_container');

  // jQuery("body").on('click', "[data-role='image_vote']", function(event){
  //   event.preventDefault();
  //   var data = $(this).data();
  //   image_vote(data.id, data.val);
  // });

  // function image_vote(id, value) {
  //   jQuery.ajax("/ajax/vote/image/" + id, {
  //     data: { value: value, authenticity_token: csrf_token() },
  //     dataType: 'text',
  //     async: true,
  //     error: function (response) {
  //       alert(response.responseText);
  //     },
  //     success: function(text) {
  //       var div = jQuery("#image_vote_links_" + id);
  //       var $updatedLinks = $updatedLinks = jQuery(text);
  //       div.html($updatedLinks.find(".image-vote-links").first().html());

  //       var newVotePercentage = div.parent().find('span.data_container').data('percentage');
  //       jQuery("#vote_meter_bar_" + id).css('width', newVotePercentage + "%")
  //       if ($show_votes_container && $quality_vote_container) {
  //         // load = jQuery ajax shorthand method, not the old .on("load").
  //         // updates side bar if on actual image page.
  //         $show_votes_container.load(window.location + " #show_votes_table");
  //         $quality_vote_container.load(window.location + " #quality_vote_content");
  //       }
  //     }
  //   });
  // }
// });
