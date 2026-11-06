# frozen_string_literal: true

require("test_helper")

# A printed QR code's two requests are left out of the per-IP traffic
# count, so a roomful of people scanning labels at a fair cannot block
# the address they share (#5416). The two other routes that reach the
# same action still count: that is where the crawlers arrive.
class LabelScanStatsIntegrationTest < IntegrationTestCase
  def setup
    super
    @obs = observations(:detailed_unknown_obs)
    @project = projects(:eol_project)
    @name = @obs.name
  end

  # What `script/update_ip_stats.rb` later reads and blocks on.
  def stats_written_by
    path = MO.ip_stats_file
    before = File.exist?(path) ? File.read(path) : ""
    yield
    after = File.exist?(path) ? File.read(path) : ""
    after.delete_prefix(before).split("\n").compact_blank
  end

  def test_the_obs_form_is_not_counted
    lines = stats_written_by { get("/obs/#{@obs.id}") }

    assert_empty(lines,
                 "A label's landing page should not count toward the " \
                 "per-IP limit")
  end

  # The lookup redirects, and where it lands is counted on its merits --
  # `/obs/:id` is not, a fallback index is. What matters here is that the
  # lookup itself contributes nothing.
  def test_the_label_lookup_is_not_counted
    lines = stats_written_by do
      get("/projects/#{@project.id}/names/#{@name.id}")
    end

    assert_empty(lines.grep(/best_observations/),
                 "The URL a label carries should not count toward the limit")
  end

  def test_the_long_observation_form_is_counted
    lines = stats_written_by { get("/observations/#{@obs.id}") }

    assert_not_empty(lines,
                     "/observations/:id is where the crawlers arrive and " \
                     "should still count")
  end

  def test_the_bare_id_form_is_counted
    lines = stats_written_by { get("/#{@obs.id}") }

    assert_not_empty(lines, "A bare /:id should still count")
  end

  def test_an_ordinary_page_is_counted
    lines = stats_written_by { get("/info/intro") }

    assert_not_empty(lines, "Other pages should still count")
  end
end
