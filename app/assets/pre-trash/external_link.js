$(document).on("ready turbo:load", function () {
  var add_callback = function () {
    var tr = $(this).parents("tr").first();
    var name = tr.find("[data-role='link']");
    var tabs = tr.find("[data-role='link-controls']");
    var obs = name.data("obs");
    var site = name.data("site");
    popup_text_field_dialog(ADD_LINK_DIALOG, "", function (url) {
      jQuery.ajax("/ajax/external_link/add/" + obs, {
        data: { site: site, value: url, authenticity_token: csrf_token() },
        dataType: "text",
        async: true,
        complete: function (request) {
          if (request.status == 200) {
            var link = request.responseText;
            name.attr("href", url)
              .data({ link: link, url: url });
            tabs.empty().append(
              "[",
              $("<a href='#'>").text(EDIT_BUTTON).click(edit_callback),
              "|",
              $("<a href='#'>").text(REMOVE_BUTTON).click(remove_callback),
              "]"
            );
          } else {
            alert(request.responseText);
          }
        }
      });
    });
    return false;
  };

  var edit_callback = function () {
    var tr = $(this).parents("tr").first();
    var name = tr.find("[data-role='link']");
    var link = name.data("link");
    var url = name.data("url");
    popup_text_field_dialog(EDIT_LINK_DIALOG, url, function (new_url) {
      jQuery.ajax("/ajax/external_link/edit/" + link, {
        data: { value: new_url, authenticity_token: csrf_token() },
        dataType: "text",
        async: true,
        complete: function (request) {
          if (request.status == 200) {
            name.attr("href", new_url)
              .data("url", new_url);
          } else {
            alert(request.responseText);
          }
        }
      });
    });
    return false;
  };

  var remove_callback = function () {
    var tr = $(this).parents("tr").first();
    var name = tr.find("[data-role='link']");
    var tabs = tr.find("[data-role='link-controls']");
    var link = name.data("link");
    if (confirm(REMOVE_LINK_DIALOG)) {
      jQuery.ajax("/ajax/external_link/remove/" + link, {
        data: { authenticity_token: csrf_token() },
        dataType: "text",
        async: true,
        complete: function (request) {
          if (request.status == 200) {
            name.attr("href", null);
            tabs.empty().append(
              "[",
              $("<a href='#'>").text(ADD_BUTTON).click(add_callback),
              "]"
            );
          } else {
            alert(request.responseText);
          }
        }
      });
    }
    return false;
  };

  $(".hidden-links").removeClass("hidden-links");
  $("[data-role='add-link']").click(add_callback);
  $("[data-role='edit-link']").click(edit_callback);
  $("[data-role='remove-link']").click(remove_callback);
});

function popup_text_field_dialog(msg, val, callback) {
  var cover = $("<div class='cover'>").appendTo($("body"));
  var popup = $("<div class='popup-dialog'>").appendTo($("body"));
  var form = $("<form>").appendTo(popup);
  var field = $("<input type='text' size='40'>").appendTo(popup);
  var btn1 = $("<input type='submit'>").val(OKAY_BUTTON);
  var btn2 = $("<input type='submit'>").val(CANCEL_BUTTON);
  form.append(
    $("<div>").text(msg),
    field,
    $("<div>").append(btn1, btn2)
  );
  var save = function () {
    var value = field.val();
    cover.remove();
    popup.remove();
    callback(value);
  };
  var cancel = function () {
    cover.remove();
    popup.remove();
  };
  var escape = function (event) {
    if (event.keyCode == 27) cancel();
  };
  popup.center().show();
  cover.click(cancel);
  form.submit(save);
  field.val(val).focus().keypress(escape);
  btn1.click(save).keypress(escape);
  btn2.click(cancel).keypress(escape);
}
