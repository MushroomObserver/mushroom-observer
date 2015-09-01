jQuery(document).ready(function () {

    jQuery('body').delegate('[data-toggle="expand-icon"]', "mouseenter mouseleave", function (e){
        var btn = jQuery(this).find('.theater-btn');
        if( e.type == "mouseleave")
            return btn.hide();
        var img = jQuery(this).find('img');
        btn.css('right', img.position().left).show();
    });


});
