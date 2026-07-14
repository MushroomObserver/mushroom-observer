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

      Row do
        Column(xs: 12, sm: 7) { render_form }
        Column(xs: 12, sm: 5) { render_matrix_box }
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
      Row(element: :ul, class: "list-unstyled") do
        render(::Components::Matrix::Box.new(
                 user: @user,
                 object: @observation.rss_log || @observation,
                 columns: Components::Column.classes_for(xs: 12)
               ))
      end
    end
  end
end
