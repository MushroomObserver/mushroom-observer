jQuery(document).ready(function () {

    jQuery('.responsive').slick({
        dots: true,
        arrows: true,
        infinite: false,
        variableWidth: true,
        speed: 300,
        slidesToShow: 3,
        slidesToScroll: 1,
        adaptiveHeight: true,
        responsive: [
            {
                breakpoint: 1024,
                settings: {
                    slidesToShow: 2
                }
            },
            {
                breakpoint: 480,
                settings: {
                    slidesToShow: 1
                }
            }
            // You can unslick at a given breakpoint now by adding:
            // settings: "unslick" instead of a settings object
        ]
    });

    jQuery('.responsive').on('init', function(event, slick){  //init the tooltips after the elements have been cloned.
        jQuery('[data-toggle="tooltip"]').tooltip({container: 'body'});
    })

});