/**
 * This should be included on every page.
 */
jQuery(document).ready(function () {
    if (!getCookie("hideBanner")) { //cookie to hide banner for 1 day
        jQuery('#message_banner').show();
    }
    jQuery('[data-toggle="tooltip"]').tooltip({container: 'body'}); //enable tooltips

    jQuery('[data-toggle="offcanvas"]').click(function () {
        jQuery(document).scrollTop(0);
        jQuery('.row-offcanvas').toggleClass('active');
        jQuery('#main_container').toggleClass('hidden-overflow-x');

    });
    jQuery('[data-toggle="search"]').click(function () {
        jQuery(document).scrollTop(0);
        var target = $(this).data().target;
        jQuery(target).css('margin-top', '32px');
        jQuery(target).toggleClass('hidden-xs');
    });
    jQuery('[data-dismiss="alert"]').click(function() {
        setCookie('hideBanner',bannermd5, 30);
    });

    jQuery('body').delegate('[data-toggle="expand-icon"]', "mouseenter mouseleave", function (e){
        var btn = jQuery(this).find('.theater-btn');
        if(e.type == "mouseleave") {
            return btn.hide();
        }
        var img = jQuery(this).find('img');
        btn.css('right', img.position().left);
        btn.show();
    });

    jQuery('body').delegate('[data-toggle="theater"]', 'click', function (e) {
        console.log('click');
        e.preventDefault();
        var img_src = jQuery(this).data().image;
        var img_orig = jQuery(this).data().original;
        jQuery('.img-theater').css('top', jQuery(document).scrollTop())
        jQuery('.img-theater').show();
        jQuery('body').addClass('theater-shown');
        jQuery('#img_append_target').html('<a href="{{orig}}"><img src="{{src}}" style="height: {{h}}; width: auto;"><//img><//a>'
            .replace("{{src}}", img_src)
            .replace("{{orig}}", img_orig)
            .replace("{{h}}", jQuery(window).height() - 20 + 'px'))
        jQuery(document).on('keyup.hideTheater', function (e){
            if (e.keyCode == 27) {
                hideTheater();
                $(document).unbind('keyup.hideTheater');
            }
        })
    });

    jQuery('[data-dismiss="theater"]').click(function (e){
        hideTheater();
    });


    function hideTheater() {
        jQuery('.img-theater').hide();
        jQuery('body').removeClass('theater-shown');
    }

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
                next.children(':first-child').clone().addClass("extra1").appendTo($(this));

            for (var i = 0; i < 2; i++) {
                next = next.next();
                if (next)
                    next.children(':first-child').clone().addClass("extra" + (i + 2)).appendTo($(this));
            }
            jQuery('[data-toggle="tooltip"]').tooltip({container: 'body'}); //enable tooltips
        });
});
