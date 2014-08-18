var STORIES;
var PIVOTAL_VOTE_FAILED;
var PIVOTAL_STORY_FAILED;
var PIVOTAL_COMMENT_FAILED;
var PIVOTAL_STORY_LOADING;

var CUR_LABEL = "all";
var CUR_STORY = null;

function click_on_label(label) {
  var old_stories = STORIES[CUR_LABEL] || [];
  var new_stories = STORIES[label]     || [];
  var state = {};
  var i, j, e;
  if (CUR_STORY) {
    click_on_story(CUR_STORY);
  }
  for (i=0; i<old_stories.length; i++) {
    j = old_stories[i];
    state[j] = true;
  }
  for (i=0; i<new_stories.length; i++) {
    j = new_stories[i];
    if (!state[j]) {
      $("pivotal_" + j).show();
    } else {
      state[j] = false;
    }
  }
  for (i=0; i<old_stories.length; i++) {
    j = old_stories[i];
    if (state[j]) {
      jQuery("#pivotal_" + j).hide();
    }
  }
  CUR_LABEL = label;
  jQuery("#pivotal_stories").ensureVisible();
}

function vote_on_story(story, user, value) {
  var div = jQuery("#pivotal_votes_" + story);
  var span = jQuery("#pivotal_vote_num_" + story);
  var old_score = span.html();
  jQuery.ajax("/ajax/pivotal/vote/" + story, {
    data: { value: value, authenticity_token: CSRF_TOKEN },
    dataType: "text",
    async: true,
    complete: function(request) {
      if (request.status == 200) {
        div.html(request.responseText);
      } else {
        span.html(old_score);
        alert(PIVOTAL_VOTE_FAILED + request.responseText);
      }
    }
  });
  span.html('<img alt="Indicator" src="/images/indicator.gif" />');
}

function click_on_story(story) {
  var div = jQuery("%pivotal_body_" + story);
  if (CUR_STORY) {
    jQuery("#pivotal_body_" + CUR_STORY).hide();
  }
  if (CUR_STORY === story) {
    CUR_STORY = null;
    return;
  }
  CUR_STORY = story;
  jQuery.ajax("/ajax/pivotal/story/" + story, {
    data: { authenticity_token: CSRF_TOKEN },
    dataType: "text",
    async: true,
    complete: function(request) {
      if (request.status == 200) {
        div.html(request.responseText);
        jQuery("#pivotal_" + story).ensureVisible();
      } else {
        div.html('');
        div.hide();
        alert(PIVOTAL_STORY_FAILED + request.responseText);
        CUR_STORY = null;
      }
    }
  });
  div.html('<span class="pivotal_loading">' +
    PIVOTAL_STORY_LOADING +
    ' <img alt="Indicator" src="/images/indicator.gif" />' +
    '</span>');
  div.show();
  jQuery("#pivotal_" + story).ensureVisible();
}

function post_comment(story) {
  var value = jQuery("#pivotal_comment").val();
  var popup = jQuery("#pivotal_popup");
  var num;
  jQuery.ajax("/ajax/pivotal/comment/" + story, {
    data: { value: value, authenticity_token: CSRF_TOKEN },
    dataType: "text",
    async: true,
    complete: function(request) {
      popup.hide();
      if (request.status == 200) {
        num = jQuery("#pivotal_num_comments_" + story);
        num.html(parseInt(num.innerHTML) + 1);
        jQuery("#pivotal_comments").append(request.responseText);
        jQuery("#pivotal_comment").val('');
      } else {
        alert(PIVOTAL_COMMENT_FAILED + request.responseText);
      }
    }
  });
  popup.center();
  popup.show();
}

