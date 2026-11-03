# frozen_string_literal: true

# Phlex view for the "propose a name" page on an observation. Two
# columns: a left column with the naming form, and a right column
# with the observation's images and details.
module Views::Controllers::Observations::Namings
  class New < Views::FullPageBase
    # Forwards every prop the Form component needs — `observation`
    # for chrome (title + context-nav + observation_details +
    # images), the rest for the Form itself.
    prop :observation, ::Observation
    prop :naming, ::Naming
    prop :vote, ::Vote
    prop :given_name, String
    prop :reasons, _Hash(Integer, ::Naming::Reason)
    prop :user, _Nilable(::User), default: nil
    prop :feedback, Hash, default: -> { {} }

    def view_template
      add_chrome
      Row do
        Column(xs: 12, sm: 8) do
          div(class: "mt-3") { render_naming_form }
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
      add_page_title(:create_naming_title.t(id: @observation.id))
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
