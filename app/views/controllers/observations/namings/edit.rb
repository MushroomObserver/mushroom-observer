# frozen_string_literal: true

# Phlex view for the "edit a naming" page. Same layout as `New`
# with a different page title; renders the existing naming + vote
# back into the same Form component.
module Views::Controllers::Observations::Namings
  class Edit < Views::FullPageBase
    prop :observation, ::Observation
    prop :naming, ::Naming
    # nil when this user hasn't voted on this naming yet.
    prop :vote, _Nilable(::Vote)
    prop :given_name, String
    prop :reasons, _Hash(Integer, ::Naming::Reason)
    prop :user, _Nilable(::User), default: nil
    prop :feedback, Hash, default: -> { {} }

    def view_template
      add_chrome
      Row do
        Column(xs: 12, sm: 8) do
          ContentPadded { render_naming_form }
        end
        Column(xs: 12, sm: 4) do
          render_images
          div(class: "mt-3") { render_observation_details }
        end
      end
    end

    private

    def add_chrome
      container_class(:double)
      content_padding(:panels)
      add_page_title(:edit_naming_title.t(id: @observation.id))
      add_context_nav(Tab::Observation::NamingForm.new(
                        observation: @observation
                      ))
    end

    def render_observation_details
      render(Views::Controllers::Observations::Show::Details.new(
               obs: @observation, user: @user
             ))
    end

    def render_naming_form
      render(Form.new(
               @naming,
               observation: @observation,
               vote: @vote,
               given_name: @given_name,
               reasons: @reasons,
               feedback: @feedback,
               show_reasons: true,
               turbo: true
             ))
    end

    def render_images
      render(Views::Controllers::Observations::Show::ImagesPanel.new(
               obs: @observation,
               images: @observation.images_sorted,
               user: @user
             ))
    end
  end
end
