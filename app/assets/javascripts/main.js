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
        jQuery(target).toggleClass('hidden-xs');
    });

    jQuery('[data-dismiss="alert"]').click(function() {
        setCookie('hideBanner', banner_md5, 30);
    });

    function setCookie(cname, cvalue, exdays) {
        var d = new Date();
        d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
        var expires = "expires=" + d.toUTCString();
        document.cookie = cname + "=" + cvalue + "; " + expires;
    }

    function getCookie(cname) {
        var name = cname + "=";
        var ca = document.cookie.split(';');
        for(var i=0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0)==' ') c = c.substring(1);
            if (c.indexOf(name) == 0) return c.substring(name.length,c.length);
        }
        return undefined;
    }

    jQuery('#carousel .item').each(function () {
        var next = jQuery(this).next();
        if (next)
            next.children(':first-child').clone().addClass("extra1").appendTo(jQuery(this));

        for (var i = 0; i < 2; i++) {
            next = next.next();
            if (next)
                next.children(':first-child').clone().addClass("extra" + (i + 2)).appendTo(jQuery(this));
        }
        jQuery('[data-toggle="tooltip"]').tooltip({container: 'body'}); //enable tooltips
    });

    jQuery('.file-field :file').on('change', function() {
        var val = $(this).val().replace(/.*[\/\\]/, ''),
            next = $(this).parent().next();
        // If file field immediately followed by span, show selection there.
        if (next.is('span')) next.html(val);
    });
});
