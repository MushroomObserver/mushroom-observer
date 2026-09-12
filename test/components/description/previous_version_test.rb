# frozen_string_literal: true

require "test_helper"

class PreviousVersionTest < ComponentTestCase
  def setup
    super
    @name = names(:peltigera)
  end

  def test_renders_current_version_label
    html = render_previous_version(obj: @name)

    assert_includes(html, "#{:version.ti}: #{@name.version}")
  end

  def test_renders_previous_version_link_when_multi_version
    skip("Need a name with multiple versions") if @name.versions.size <= 1

    html = render_previous_version(obj: @name)

    assert_html(html, "a.previous_version_link",
                text: :show_name_previous_version.t)
  end

  def test_omits_previous_link_when_single_version
    obs = observations(:minimal_unknown_obs)
    skip("Need a single-version versioned object") if
      obs.respond_to?(:versions) && obs.versions.size > 1

    # Use a fresh Name with only one version implicitly.
    name = names(:agaricus_campestris)
    html = render_previous_version(obj: name)

    assert_no_html(html, "a.previous_version_link")
  end

  private

  def render_previous_version(obj:)
    render(Components::Description::PreviousVersion.new(
             obj: obj, versions: obj.versions.to_a
           ))
  end
end
