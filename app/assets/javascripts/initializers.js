/**
 * This should be included on every page in the footer.
*/

// With Turbolinks, jQuery(document).on('ready' doesn't fire after first load
// because new content is loaded asynchronously and added to the existing page.
// To achieve the same effect, we bind to jQuery(document).on('ready page:load'
// https://github.com/turbolinks/turbolinks#installing-javascript-behavior

// TODO: check these listeners

// advanced_search
// api_key
// confirm
// donate
// external_link
// image_vote
// pivotal
// rss_feed_select_helper
// thumbnail_map
// translations

// Initialize Verlok LazyLoad
var lazyLoadInstance = new LazyLoad({
    elements_selector: ".lazyload"
    // ... more custom settings?
});

$(document).on('ready page:load', function () {

    // This works better than straight autofocus attribute in firefox.
    // Normal autofocus causes it to scroll window hiding title etc.
    $('[data-autofocus=true]').first().focus();

    // Initialize data-links
    $('[data-role=link]').on('click', function() {
      window.location = jQuery(this).attr('data-url');
    });

    // Initialize tooltips
    $('[data-toggle="tooltip"]').tooltip({container: 'body'});

    // Initialize sidebar toggle
    $('[data-toggle="offcanvas"]').click(function () {
        $(document).scrollTop(0);
        $('.row-offcanvas').toggleClass('active');
        $('#main_container').toggleClass('hidden-overflow-x');

    });

    // Initialize search toggle
    $('[data-toggle="search"]').click(function () {
        $(document).scrollTop(0);
        var target = $(this).data().target;
        $(target).css('margin-top', '32px');
        $(target).toggleClass('d-none');
    });

    // Initialize alert dismiss
    $('[data-dismiss="alert"]').click(function() {
        setCookie('hideBanner2', BANNER_TIME, 30);
    });

    // Initialize bootstrap lightbox
    $(document).on('click', '[data-toggle="lightbox"]', function(event) {
        event.preventDefault();
        // console.log("lightbox clicked");
        $(this).ekkoLightbox({
          alwaysShowClose: true,
        });
    });

    function setCookie(cname, cvalue, exdays) {
        var d = new Date();
        d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
        var expires = "expires=" + d.toUTCString();
        document.cookie = cname + "=" + cvalue + "; " + expires + ";path=/";
    }

    $('.file-field :file').on('change', function() {
        var val = $(this).val().replace(/.*[\/\\]/, ''),
            next = $(this).parent().next();
        // If file field immediately followed by span, show selection there.
        if (next.is('span')) next.html(val);
    });

    // Update lazy loads
    lazyLoadInstance.update();

    // Initialize validate_file_input_fields
    $("input[type=file][multiple!=multiple]").each(function() {
      apply_file_input_field_validation(this.id);
    });

});
