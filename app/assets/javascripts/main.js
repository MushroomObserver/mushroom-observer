/**
 * This should be included on every page.
 */
jQuery(document).ready(function () {
    if (!getCookie("hideBanner")) { //cookie to hide banner for 1 day
        jQuery('#message_banner').show();
    }
    jQuery('[data-toggle="tooltip"]').tooltip({container: 'body'}); //enable tooltips

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

    jQuery('[data-toggle="theater"]').click(function (e){
        e.preventDefault();
        var img_src = jQuery(this).data().image;
        var img_orig = jQuery(this).data().original;
        jQuery('.img-theater').css('top', jQuery(document).scrollTop())
        jQuery('.img-theater').show();
        jQuery('body').addClass('theater-shown');
        jQuery('#img_append_target').html('<a href="{{orig}}"><img src="{{src}}" class="center-block" style="height: {{h}}; width: auto;"><//img><//a>'
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
        e.preventDefault();
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


    var slide_item_lengths = jQuery("#carouselshowmanymoveone .item").length;
        jQuery('#carouselshowmanymoveone .item').each(function () {
            var next = jQuery(this).next();
            if (!next.length) {
                next = $(this).siblings(':first');
            }
                next.children(':first-child').clone().addClass("extra1").appendTo($(this));

            for (var i = 0; i < 2; i++) {
                console.log(next);
                next = next.next();
                if (!next.length) {
                    //next = jQuery(this).siblings(':first');
                }

                next.children(':first-child').clone().addClass("extra" + (i + 2)).appendTo($(this));
            }
        });
});
