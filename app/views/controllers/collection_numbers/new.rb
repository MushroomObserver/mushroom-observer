# frozen_string_literal: true

# Action template for `CollectionNumbersController#new`. Replaces
# `app/views/controllers/collection_numbers/new.html.erb`. Wraps
# the existing `Form` Phlex component with the page chrome + a
# side-column MatrixBox preview of the observation.
module Views::Controllers::CollectionNumbers
  class New < Views::FullPageBase
    prop :collection_number, ::CollectionNumber
    prop :observation, ::Observation
    prop :user, ::User

    def view_template
      container_class(:full)
      add_new_title(:add_object, :COLLECTION_NUMBER)
      add_context_nav(
        Tab::CollectionNumber::FormNew.new(observation: @observation)
      )

      div(class: "row") do
        div(class: "col-xs-12 col-sm-7") { render_form }
        div(class: "col-xs-12 col-sm-5") { render_observation_box }
      end
    end

    private

    def render_form
      render(Form.new(@collection_number, observation: @observation))
    end

    def render_observation_box
      ul(class: "row list-unstyled") do
        render(Components::Matrix::Box.new(
                 user: @user,
                 object: @observation.rss_log || @observation,
                 columns: "col-xs-12"
               ))
      end
    end
  end
end
