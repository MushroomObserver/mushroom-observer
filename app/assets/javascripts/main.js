/**
 * This should be included on every page.
 */
jQuery(document).ready(function () {
    if (!getCookie("hideBanner")) { //cookie to hide banner for 1 day
        jQuery('#message_banner').show();
    }
    $('[data-toggle="tooltip"]').tooltip({container: 'body'}); //enable tooltips

    jQuery('[data-toggle="offcanvas"]').click(function () {
        jQuery('.row-offcanvas').toggleClass('active');
        jQuery('body').toggleClass('hidden-overflow-x');
    });
    jQuery('[data-toggle="search"]').click(function () {
        var target = $(this).data().target;
        jQuery(target).css('margin-top', '32px');
        jQuery(target).toggleClass('hidden-xs');
    });
    jQuery('[data-dismiss="alert"]').click(function() {
        setCookie('hideBanner',"true", 1);
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

});
