jQuery(document).ready(function () {
    //http://api.jquery.com/delegate/
    jQuery(".show_images").delegate("[data-role='image_vote']", 'click', function(event){
       event.preventDefault();
       var data = $(this).data();
       image_vote(data.id, data.val);
    });

    function image_vote(id, value) {
        jQuery.ajax("/ajax/vote/image/" + id, {
            data: { value: value, authenticity_token: CSRF_TOKEN },
            dataType: 'text',
            async: true,
            error: function (response) {
                alert(response.responseText);
            },
            success: function(text) {
                var div = jQuery("#image_votes_" + id);
                div.html(text);
            }
        });
    }
});

