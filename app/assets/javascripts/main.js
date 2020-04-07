/**
 * This should be included on every page.
 */
jQuery(document).ready(function () {

    // This works better than straight autofocus attribute in firefox.
    // Normal autofocus causes it to scroll window hiding title etc.
    jQuery('[data-autofocus=true]').first().focus();

    jQuery('[data-role=link]').on('click', function() {
      window.location = jQuery(this).attr('data-url');
    });

    jQuery('[data-toggle="tooltip"]').tooltip({container: 'body'});

    jQuery('[data-toggle="offcanvas"]').click(function () {
        jQuery(document).scrollTop(0);
        jQuery('.row-offcanvas').toggleClass('active');
        jQuery('#main_container').toggleClass('hidden-overflow-x');

    });

    jQuery('[data-toggle="search"]').click(function () {
        jQuery(document).scrollTop(0);
        var target = jQuery(this).data().target;
        jQuery(target).css('margin-top', '32px');
        jQuery(target).toggleClass('d-none');
    });

    jQuery('[data-dismiss="alert"]').click(function() {
        setCookie('hideBanner2', BANNER_TIME, 30);
    });

    function setCookie(cname, cvalue, exdays) {
        var d = new Date();
        d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
        var expires = "expires=" + d.toUTCString();
        document.cookie = cname + "=" + cvalue + "; " + expires + ";path=/";
    }

    jQuery('.file-field :file').on('change', function() {
        var val = $(this).val().replace(/.*[\/\\]/, ''),
            next = $(this).parent().next();
        // If file field immediately followed by span, show selection there.
        if (next.is('span')) next.html(val);
    });
});
