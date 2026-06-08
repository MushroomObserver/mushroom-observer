# frozen_string_literal: true

# Warning-level alert that surfaces likely-meant names when the user
# typed a name string with no exact match. Pre-Phlex this was
# `_name_suggestions.erb`. Heading is the `:list_observations_suggestions`
# label, then one indented row per suggested name: either a link to
# the name's show page (when there are no observations of that name)
# or a link to the observations search filtered by the name (when
# there are observations).
class Views::Controllers::Observations::Show::NameSuggestionsAlert < Views::Base
  # Pairs of `[Name, count]` — see
  # `ObservationsController::Index#make_name_suggestions`. The
  # controller builds an `Array<[Name, Integer]>` rather than a
  # Hash because the iteration order is sort-stable (sort by
  # `Name#sort_name` and preserve). Zero-count entries link to
  # the name's show page; non-zero to the observations search.
  prop :names, _Array(_Tuple(::Name, Integer))

  def view_template
    render(Components::Alert.new(level: :warning)) do
      p { plain("#{:list_observations_suggestions.t}:") }
      @names.each { |name, count| render_row(name, count) }
    end
  end

  private

  def render_row(name, count)
    div(class: "pl-3") do
      count.zero? ? render_name_link(name) : render_obs_link(name, count)
    end
  end

  def render_name_link(name)
    plain("#{:list_observation_name.t}: ")
    a(href: url_for(name.show_link_args)) do
      trusted_html(name.display_name.t)
    end
    plain(" (0)")
  end

  def render_obs_link(name, count)
    plain("#{:list_observation_observations.t} ")
    a(href: observations_path(pattern: name.text_name)) do
      trusted_html(name.display_name.t)
    end
    plain(" (#{count})")
  end
end
