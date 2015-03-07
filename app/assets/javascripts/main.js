/**
 * This should be included on every page.
 */
jQuery(document).ready(function () {
    // this works better than straing autofocus attribute in firefox
    // normal autofocus causes it to scroll window hiding title etc.
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
        e.preventDefault();
        jQuery('body').addClass('theater-shown');
        var win = jQuery(window),
            doc = jQuery(document),
            div = jQuery('.img-theater-div'),
            w = win.width(),
            h = win.height(),
            img_orig = jQuery(this).data().orig,
            img_src = w-40 > 1280 || h-40 > 1280 ? jQuery(this).data().full :
                      w-40 > 960  || h-40 > 960  ? jQuery(this).data().huge :
                                                   jQuery(this).data().large;
        var img, img_w, img_h;
        var reposition_image = function() {
            var win_w = jQuery(window).width(),
                win_h = jQuery(window).height();
            if (img_w < win_w - 40 && img_h < win_h - 40) {
                // image fits unscaled
                pad = Math.round((win_h - img_h) / 2);
            } else if ((win_h - 40) * img_w / img_h > win_w - 40) {
                // scale up so takes up full width
                pad = Math.round((win_h - (win_w - 40) * img_h / img_w) / 2);
            } else {
                // scale up so takes up full height
                pad = 20;
            }
            // console.log("img: "+img_w+","+img_h + " win: "+win_w+","+win_h + " -> pad: " + pad);
            div.css('padding', pad + 'px 20px');
        };
        img = new Image();
        img.onload = function() {
            img_w = this.width;
            img_h = this.height;
            reposition_image();
            win.on('resize.theater', reposition_image);
        };
        img.src = img_src;
        div.css('padding', '20px').html(img);
        div.find('img').click(function() { window.location = img_orig });
        jQuery('.img-theater').css('top', doc.scrollTop()).show();
        doc.on('keyup.hideTheater', function (e) {
            if (e.keyCode == 27)
                hideTheater();
        });
    });

    jQuery('[data-dismiss="theater"]').click(function (e){
        hideTheater();
    });

    function hideTheater() {
        jQuery('.img-theater').hide();
        jQuery('body').removeClass('theater-shown');
        jQuery(document).unbind('keyup.hideTheater');
        jQuery(window).unbind('resize.theater');
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
