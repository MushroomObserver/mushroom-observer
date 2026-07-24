# frozen_string_literal: true

require("test_helper")

class ObservationFragmentWhenTest < ComponentTestCase
  def test_renders_when_line
    obs = observations(:coprinus_comatus_obs)
    html = render(Components::ObservationFragment::When.new(obs: obs))

    assert_html(html, "li.obs-when.hanging-indent",
                text: "#{:when.ti}: #{obs.when.web_date}")
  end
end
