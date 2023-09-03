/**
 * This should be included on every page.
 */

$(document).on("ready turbo:load", function () {
  console.log("turbo!");

  // This works better than straight autofocus attribute in firefox.
  // Normal autofocus causes it to scroll window hiding title etc.
  jQuery('[data-autofocus=true]').first().focus();

  jQuery('[data-role=link]').on('click', function () {
    window.location = jQuery(this).attr('data-url');
  });

  jQuery('[data-toggle="tooltip"]').tooltip({ container: 'body' });

  // HAMBURGER HELPER
  jQuery('[data-toggle="offcanvas"]').on('click', function () {
    jQuery(document).scrollTop(0);
    jQuery('.row-offcanvas').toggleClass('active');
    jQuery('#main_container').toggleClass('hidden-overflow-x');

  });

  // SEARCH BAR FINDER
  jQuery('[data-toggle="search"]').on('click', function () {
    jQuery(document).scrollTop(0);
    var target = jQuery(this).data().target;
    // jQuery(target).css('margin-top', '32px');
    jQuery(target).toggleClass('hidden-xs');
  });

  jQuery('[data-dismiss="alert"]').on('click', function () {
    setCookie('hideBanner2', BANNER_TIME, 30);
  });

  function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
    var expires = "expires=" + d.toUTCString();
    document.cookie = cname + "=" + cvalue + "; " + expires + ";path=/";
  }

  jQuery('.file-field :file').on('change', function () {
    var val = $(this).val().replace(/.*[\/\\]/, ''),
      next = $(this).parent().next();
    // If file field immediately followed by span, show selection there.
    if (next.is('span')) next.html(val);
  });

  // Not a great solution, but ok for now.
  jQuery('form :input').on('change', function () {
    var disabled_buttons = $('[data-disable-with]');
    $(disabled_buttons).each(function () {
      $.rails.enableElement(this);
    })
  });

  // very precise binding for dynamically generated lightbox links
  // they are not there on page load, only when lightbox activated
  jQuery('body').on('click', '#lightbox .lb-dataContainer button.lightbox_link', function (e) {
    e.stopPropagation();
    var button = jQuery(e.target),
      modal_target_id = button.data("target");
    // must pass the button itself as second param
    jQuery(modal_target_id).modal("toggle", button);
  });

  // Initialize Verlok LazyLoad
  var lazyLoadInstance = new LazyLoad({
    elements_selector: ".lazy"
    // ... more custom settings?
  });

  // Update lazy loads
  lazyLoadInstance.update();
});
