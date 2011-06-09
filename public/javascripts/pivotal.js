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
  if (CUR_STORY)
    click_on_story(CUR_STORY);
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
      $("pivotal_" + j).hide();
    }
  }
  CUR_LABEL = label;
  Element.ensureVisible($("pivotal_stories"));
}

function vote_on_story(story, user, value) {
  var div = $("pivotal_votes_" + story);
  new Ajax.Request("/ajax/pivotal/vote/" + story + "?value=" + value, {// 
    asynchronous: true,// 
    onComplete: function(request) {// 
      if (request.status == 200) {// 
        div.innerHTML = request.responseText;// 
      } else {// 
        alert(PIVOTAL_VOTE_FAILED + request.responseText);// 
      }// 
    }// 
  });// 
  $("pivotal_vote_num_" + story).innerHTML = // 
    '<img alt="Indicator" src="/images/indicator.gif" />';// 
}

function click_on_story(story) {
  var div = $("pivotal_body_" + story);
  if (CUR_STORY)
    $("pivotal_body_" + CUR_STORY).hide();
  if (CUR_STORY === story) {
    CUR_STORY = null;
    return;
  }
  CUR_STORY = story
  new Ajax.Request("/ajax/pivotal/story/" + story, {
    asynchronous: true,
    onComplete: function(request) {
      if (request.status == 200) {
        div.innerHTML = request.responseText;
        Element.ensureVisible($("pivotal_" + story));
      } else {
        div.innerHTML = '';
        div.hide();
        alert(PIVOTAL_STORY_FAILED + request.responseText);
        CUR_STORY = null;
      }
    }
  });
  div.innerHTML = '<span class="pivotal_loading">' +
    PIVOTAL_STORY_LOADING +
    ' <img alt="Indicator" src="/images/indicator.gif" />' +
    '</span>';
  div.show();
  Element.ensureVisible($("pivotal_" + story));
}

function post_comment(story) {
  var value = $("pivotal_comment").value;
  var popup = $("pivotal_popup");
  var num;
  new Ajax.Request("/ajax/pivotal/comment/" + story + "?value=" + escape(value), {
    asynchronous: true,
    onComplete: function(request) {
      popup.hide();
      if (request.status == 200) {
        num = $("pivotal_num_comments_" + story);
        num.innerHTML = parseInt(num.innerHTML) + 1;
        $("pivotal_comments").innerHTML += request.responseText;
        $("pivotal_comment").value = "";
      } else {
        alert(PIVOTAL_COMMENT_FAILED + request.responseText);
      }
    }
  });
  Element.center(popup);
  popup.show();
}

