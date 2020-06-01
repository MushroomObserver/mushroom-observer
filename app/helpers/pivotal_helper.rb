# frozen_string_literal: true

module PivotalHelper
  # From pivotal_tracker_helper.rb
  def pivotal_vote_controls(story)
    current_vote = story.user_vote(@user)
    result = "".html_safe
    result << if @user && current_vote < MO.pivotal_max_vote
                link_to(image_tag("vote_up_hot.png"),
                        {},
                        data: { role: "vote_on_story",
                                story: story.id,
                                user: @user.id,
                                vote: current_vote + 1 })
              else
                image_tag("vote_up_cold.png")
              end
    result << content_tag(:span,
                          story.score.to_s,
                          id: "pivotal_vote_num_#{story.id}")
    result << if @user && current_vote > MO.pivotal_min_vote
                link_to(image_tag("vote_down_hot.png"),
                        {},
                        data: { role: "vote_on_story",
                                story: story.id,
                                user: @user.id,
                                vote: current_vote - 1 })
              else
                image_tag("/assets/vote_down_cold.png")
              end
    result
  end

  def pivotal_story(story)
    result = content_tag(:p, :DESCRIPTION.l + ":", class: "pivotal_heading")
    result += story.description.tp
    if story.user
      result += content_tag(:p, :pivotal_posted_by.l + ": " +
                            user_link(story.user.id, story.user.name),
                            class: "pivotal_heading")
    end
    result += content_tag(:p, :COMMENTS.l + ":", class: "pivotal_heading")
    comments = []
    num = 0
    for comment in story.comments
      num += 1
      comments << pivotal_comment(comment, num)
    end
    result += content_tag(:div, comments.safe_join, id: "pivotal_comments")
    form = content_tag(:textarea,
                       "",
                       id: "pivotal_comment",
                       cols: 80,
                       rows: 10) + safe_br
    form += tag(:input,
                type: :button,
                value: :pivotal_post_comment.l,
                data: { role: "post_comment", story: story.id })
    result += content_tag(:form, form,
                          action: "",
                          class: "mt-3")
    result
  end

  def pivotal_comment(comment, num)
    content_tag(:div, class: "ListLine" + (num & 1).to_s) do
      content_tag(:p) do
        result = :CREATED.t + ": " + comment.time.to_s + safe_br
        if comment.user
          result << :BY.t + ": " +
                    user_link(comment.user.id, comment.user.name) +
                    safe_br
        end
        result
      end + comment.text.to_s.tp
    end
  end
end
