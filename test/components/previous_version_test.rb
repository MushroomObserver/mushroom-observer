# frozen_string_literal: true

require "test_helper"

class PreviousVersionTest < ComponentTestCase
  def setup
    super
    @name = names(:peltigera)
  end

  def test_renders_current_version_label
    html = render(Components::PreviousVersion.new(
                    obj: @name, versions: @name.versions.to_a
                  ))

    assert_includes(html, "#{:VERSION.t}: #{@name.version}")
  end

  def test_renders_previous_version_link_when_multi_version
    skip("Need a name with multiple versions") if @name.versions.size <= 1

    html = render(Components::PreviousVersion.new(
                    obj: @name, versions: @name.versions.to_a
                  ))

    assert_html(html, "a.previous_version_link",
                text: :show_name_previous_version.t)
  end

  def test_omits_previous_link_when_single_version
    obs = observations(:minimal_unknown_obs)
    skip("Need a single-version versioned object") if
      obs.respond_to?(:versions) && obs.versions.size > 1

    # Use a fresh Name with only one version implicitly.
    name = names(:agaricus_campestris)
    html = render(Components::PreviousVersion.new(
                    obj: name, versions: name.versions.to_a
                  ))

    assert_no_html(html, "a.previous_version_link")
  end
end
