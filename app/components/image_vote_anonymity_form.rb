# frozen_string_literal: true

# Form for changing image vote anonymity (no fields, just submit buttons)
class Components::ImageVoteAnonymityForm < Components::ApplicationForm
  def view_template
    render_vote_counts
    render_buttons
  end

  private

  def render_vote_counts
    div(class: "mt-3") do
      plain("#{:image_vote_anonymity_num_anonymous.t}: #{model.num_anonymous}")
      br
      plain("#{:image_vote_anonymity_num_public.t}: #{model.num_public}")
      br
    end
  end

  def render_buttons
    div(class: "mt-3") do
      submit(:image_vote_anonymity_make_anonymous.l)
      br
      submit(:image_vote_anonymity_make_public.l)
      br
    end
  end
end
