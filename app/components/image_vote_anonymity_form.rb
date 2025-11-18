# frozen_string_literal: true

# Form for changing image vote anonymity (no fields, just submit buttons)
class Components::ImageVoteAnonymityForm < Components::ApplicationForm
  def view_template
    div(class: "mt-3") do
      render_anonymous_count
      render_public_count
      submit(:image_vote_anonymity_make_public.l, disabled: anon.zero?)
    end
  end

  private

  def render_anonymous_count
    p do
      plain("#{:image_vote_anonymity_num_anonymous.t}: ")
      strong { anon }
    end
  end

  def render_public_count
    p do
      plain("#{:image_vote_anonymity_num_public.t}: ")
      strong { pub }
    end
  end

  def anon
    model.num_anonymous
  end

  def pub
    model.num_public
  end
end
