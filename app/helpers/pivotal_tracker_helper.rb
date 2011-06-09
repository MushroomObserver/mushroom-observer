# encoding: utf-8
#
#  = Pivotal Tracker Helpers
#
#  pivotal_vote_controls::     Cute little controls for voting stories up or down.
#  pivotal_story::             Display a single story.
#  pivotal_comment::           Display a single comment (for use within a story). 
#
################################################################################

module ApplicationHelper::PivotalTracker

  def pivotal_vote_controls(story)
    current_vote = story.user_vote(@user)
    result = ''
    result += if @user && current_vote < PIVOTAL_MAX_VOTE
      link_to_function(image_tag('vote_up_hot.png'),
        "vote_on_story(#{story.id}, #{@user.id}, #{current_vote+1})")
    else
      image_tag('vote_up_cold.png')
    end
    result += '<span id="pivotal_vote_num_' + story.id + '">' + story.score.to_s + '</span>'
    result += if @user && current_vote > PIVOTAL_MIN_VOTE
      link_to_function(image_tag('vote_down_hot.png'),
        "vote_on_story(#{story.id}, #{@user.id}, #{current_vote-1})")
    else
      image_tag('vote_down_cold.png')
    end
    return result
  end

  def pivotal_story(story)
    result = ''
    result += '<p class="pivotal_heading">' + :DESCRIPTION.l + ':</p>'
    result += story.description.tp
    if story.user.instance_of?(User)
      result += '<p class="pivotal_heading">' + :pivotal_posted_by.l + ': '
      result += user_link(story.user) + '</p>'
    end
    result += '<p class="pivotal_heading">' + :COMMENTS.l + ':</p>'
    result += '<div id="pivotal_comments">'
    num = 0
    for comment in story.comments
      num += 1
      result += pivotal_comment(comment, num)
    end
    result += '</div>'
    result += '<form action="" style="margin-top:1em">'
    result += '<textarea id="pivotal_comment" cols="80" rows="10"></textarea><br/>'
    result += '<input type="button" value="' + :pivotal_post_comment.l + '" ' +
              'onclick="post_comment(' + story.id + ')" />'
    result += '</form>'
    return result
  end

  def pivotal_comment(comment, num)
    result = ''
    result += '<div class="ListLine' + (num & 1).to_s + '">'
    result += '<p>'
    result += :CREATED.t + ': ' + comment.time.to_s + '<br/>'
    result += :BY.t + ': ' + user_link(comment.user) + '<br/>'
    result += '</p>'
    result += comment.text.to_s.tp
    result += '</div>'
    return result
  end
end
