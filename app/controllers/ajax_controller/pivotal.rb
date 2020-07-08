# frozen_string_literal: true

# see ajax_controller.rb
class AjaxController
  # Deal with Pivotal stories.  Renders updated story, vote controls, etc.
  # type::  Type of request: 'story', 'vote', 'comment'
  # id::    ID of story.
  # value:: Value of comment or vote (as necessary).
  def pivotal
    if @type == "story"
      pivotal_story(@id)
    elsif @type == "vote"
      pivotal_vote(@id, @value)
    elsif @type == "comment"
      pivotal_comment(@id, @value)
    end
  end

  private

  def pivotal_story(id)
    @story = Pivotal.get_story(id)
    render(inline: "<%= pivotal_story(@story) %>")
  end

  def pivotal_vote(id, value)
    @user = session_user!
    @story = Pivotal.cast_vote(id, @user, value)
    render(inline: "<%= pivotal_vote_controls(@story) %>")
  end

  def pivotal_comment(id, value)
    @user = session_user!
    @story = Pivotal.get_story(id)
    @comment = Pivotal.post_comment(id, @user, value)
    @num = @story.comments.length + 1
    render(inline: "<%= pivotal_comment(@comment, @num) %>")
  end
end
