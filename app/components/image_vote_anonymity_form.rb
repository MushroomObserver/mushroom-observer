# frozen_string_literal: true

# Form for changing image vote anonymity (no fields, just submit buttons)
class Components::ImageVoteAnonymityForm < Components::ApplicationForm
  def view_template
    div(class: "mt-3") do
      render_anonymous
      render_spacer
      render_public
    end
  end

  private

  def render_anonymous
    div(class: "d-inline-block text-center") do
      p do
        plain("#{:image_vote_anonymity_num_anonymous.t}:")
        whitespace
        strong { anon }
      end
      div do
        submit(:image_vote_anonymity_make_anonymous.l, disabled: anon.positive?)
      end
    end
  end

  def render_spacer
    div(class: "d-inline-block p-5")
  end

  def render_public
    div(class: "d-inline-block text-center") do
      p do
        plain("#{:image_vote_anonymity_num_public.t}:")
        whitespace
        strong { pub }
      end
      div do
        submit(:image_vote_anonymity_make_public.l, disabled: pub.positive?)
      end
    end
  end

  def anon
    model.num_anonymous
  end

  def pub
    model.num_public
  end
end
