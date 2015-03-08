jQuery(document).ready(function () {

    jQuery('body').delegate('[data-toggle="expand-icon"]', "mouseenter mouseleave", function (e){
        var btn = jQuery(this).find('.theater-btn');
        if( e.type == "mouseleave")
            return btn.hide();
        var img = jQuery(this).find('img');
        btn.css('right', img.position().left).show();
        //
    });

    jQuery('body').delegate('[data-toggle="theater"]', 'click', function (e) {
        e.preventDefault()
        jQuery('.hamburger').addClass('hidden');
        jQuery('body').addClass('theater-shown');

        var win = jQuery(window),
            doc = jQuery(document),
            div = jQuery('.img-theater-div'),
            data = jQuery(this).data(),
            w = win.width(),
            h = win.height(),
            img_orig = data.orig,
            img, img_w, img_h, img_src;

        var reposition_image = function() {
            var win_w = jQuery(window).width(),
                win_h = jQuery(window).height(),
                pad;
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

        // If we have the image size, we can determine exactly which image size
        // to get.  Also, go ahead and calculate what the image size will be.
        if (data.width) {
            var try_size = function(size, min, max) {
                if (img_w > min && img_w > img_h && w > min && h > img_h * min / img_w) {
                    if (max) {
                      img_h = Math.round(img_h * max / img_w);
                      img_w = max;
                    }
                    img_src = data[size];
                } else if (img_h > min && img_h > img_w && h > min && w > img_w * min / img_h) {
                    if (max) {
                      img_w = Math.round(img_w * max / img_h);
                      img_h = max;
                    }
                    img_src = data[size];
                }
                return img_src;
            };
            img_w = data.width;
            img_h = data.height;
            w -= 40; h -= 40; // remove padding
            try_size("full",   1280, 0   ) ||
            try_size("huge",   960,  1280) ||
            try_size("large",  640,  960 ) ||
            try_size("medium", 0,    640 );
            // console.log("win: "+w+","+h+" img: "+data.width+","+data.height+" -> "+img_w+","+img_h+ ", " + img_src);
        }

        // If we don't know image size at first, just guess what size will
        // probably be appropriate.
        else {
            w -= 40; h -= 40; // remove padding
            if (w/h > 4/3) w = h * 4 / 3; // odds are img is between 4:3 and 3:4
            if (h/w > 4/3) h = w * 4 / 3;
            img_src = w > 1280 || h > 1280 ? data.full  :
                      w > 960  || h > 960  ? data.huge  :
                      w > 640  || h > 640  ? data.large :
                                             data.medium;
            // console.log("win: "+w+","+h+" -> " + img_src);
        }

        // Get image size if we don't already have it.
        img = new Image();
        if (!img_w)
            img.onload = function() {
                img_w = this.width;
                img_h = this.height;
                reposition_image();
                win.on('resize.theater', reposition_image);
            };
        img.src = img_src;

        // Insert img into DOM and style things and attach listeners.
        div.css('padding', '20px').html(img);
        div.find('img').click(function() { window.location = img_orig });
        jQuery('.img-theater').css('top', doc.scrollTop()).show();
        doc.on('keyup.hideTheater', function (e) {
            if (e.keyCode == 27)
                hideTheater();
        });

        // Position image immediately if already have size.
        if (img_w) {
            reposition_image();
            win.on('resize.theater', reposition_image);
        }
    });

    function hideTheater() {
        jQuery('.img-theater').hide();
        jQuery('body').removeClass('theater-shown');
        jQuery(document).unbind('keyup.hideTheater');
        jQuery(window).unbind('resize.theater');
        jQuery('.hamburger').removeClass('hidden');
    }

    jQuery('[data-dismiss="theater"]').click(hideTheater);
});
