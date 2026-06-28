# frozen_string_literal: true

# Action template for `Observations::ExternalLinksController#new` —
# the "add an external link to this observation" page. Renders
# `ExternalLinks::Form` alongside a `Components::Matrix::Box`
# observation-summary card.
module Views::Controllers::Observations::ExternalLinks
  class New < Views::FullPageBase
    prop :external_link, ::ExternalLink
    prop :observation, ::Observation
    prop :sites, _Array(::ExternalSite)
    prop :site, _Nilable(::ExternalSite), default: nil
    prop :user, _Nilable(::User), default: nil

    def view_template
      container_class(:full)
      add_new_title(:add_object, :EXTERNAL_LINK)

      div(class: "row") do
        div(class: Grid::SM7) { render_form }
        div(class: Grid::SM5) { render_matrix_box }
      end
    end

    private

    def render_form
      render(Form.new(
               @external_link,
               observation: @observation,
               sites: @sites,
               site: @site || @sites.first,
               user: @user
             ))
    end

    def render_matrix_box
      ul(class: "row list-unstyled") do
        render(::Components::Matrix::Box.new(
                 user: @user,
                 object: @observation.rss_log || @observation,
                 columns: Grid::FULL
               ))
      end
    end
  end
end
