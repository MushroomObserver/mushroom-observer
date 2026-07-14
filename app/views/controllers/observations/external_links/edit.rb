# frozen_string_literal: true

# Action template for `Observations::ExternalLinksController#edit` —
# the "edit this external link" page. Renders `ExternalLinks::Form`
# alongside a `Components::Matrix::Box` observation-summary card.
module Views::Controllers::Observations::ExternalLinks
  class Edit < Views::FullPageBase
    prop :external_link, ::ExternalLink
    prop :observation, ::Observation
    prop :site, ::ExternalSite
    prop :back, _Nilable(String), default: nil
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:full)
      add_edit_title(@external_link)

      div(class: "row") do
        Column(xs: 12, sm: 7) { render_form }
        Column(xs: 12, sm: 5) { render_matrix_box }
      end
    end

    private

    def render_form
      render(Form.new(
               @external_link,
               observation: @observation,
               sites: [@site],
               site: @site,
               user: @user,
               back: @back
             ))
    end

    def render_matrix_box
      ul(class: "row list-unstyled") do
        render(::Components::Matrix::Box.new(
                 user: @user,
                 object: @observation,
                 columns: Components::Column.classes_for(xs: 12)
               ))
      end
    end
  end
end
