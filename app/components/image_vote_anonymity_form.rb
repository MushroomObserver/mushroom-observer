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
      div do
        plain("#{:image_vote_anonymity_num_anonymous.t}: " \
              "#{model.num_anonymous}")
      end
      div do
        plain("#{:image_vote_anonymity_num_public.t}: #{model.num_public}")
      end
    end
  end

  def render_buttons
    div(class: "mt-3") do
      div { submit(:image_vote_anonymity_make_anonymous.l) }
      div { submit(:image_vote_anonymity_make_public.l) }
    end
  end
end
