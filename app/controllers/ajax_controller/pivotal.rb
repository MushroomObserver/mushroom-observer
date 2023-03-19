# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::Pivotal
  # Deal with Pivotal stories.  Renders updated story, vote controls, etc.
  # type::  Type of request: 'story', 'vote', 'comment'
  # id::    ID of story.
  # value:: Value of comment or vote (as necessary).
  def pivotal
    case @type
    when "story"
      pivotal_story(@id)
    when "vote"
      pivotal_vote(@id, @value)
    when "comment"
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
