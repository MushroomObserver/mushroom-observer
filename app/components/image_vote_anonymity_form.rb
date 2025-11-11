# frozen_string_literal: true

# Form for changing image vote anonymity (no fields, just submit buttons)
class Components::ImageVoteAnonymityForm < Phlex::HTML
  include Phlex::Rails::Helpers::FormAuthenticityToken
  include Phlex::Rails::Helpers::Routes

  def initialize(num_anonymous:, num_public:, action:)
    super()
    @num_anonymous = num_anonymous
    @num_public = num_public
    @action = action
  end

  def view_template
    form(action: @action, method: "post") do
      input(name: "authenticity_token", type: "hidden",
            value: form_authenticity_token)
      input(name: "_method", type: "hidden", value: "patch")

      render_vote_counts
      render_buttons
    end
  end

  private

  def render_vote_counts
    div(class: "mt-3") do
      plain("#{:image_vote_anonymity_num_anonymous.t}: #{@num_anonymous}")
      br
      plain("#{:image_vote_anonymity_num_public.t}: #{@num_public}")
      br
    end
  end

  def render_buttons
    div(class: "mt-3") do
      input(
        type: "submit",
        value: :image_vote_anonymity_make_anonymous.l,
        class: "btn btn-default",
        data: { turbo_submits_with: :SUBMITTING.l,
                disable_with: :image_vote_anonymity_make_anonymous.l }
      )
      br
      input(
        type: "submit",
        value: :image_vote_anonymity_make_public.l,
        class: "btn btn-default",
        data: { turbo_submits_with: :SUBMITTING.l,
                disable_with: :image_vote_anonymity_make_public.l }
      )
      br
    end
  end
end
