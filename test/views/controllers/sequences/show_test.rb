# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Sequences
  class ShowTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    # `render_blast_link` always renders; verify the ExternalLink
    # component produces the required external-navigation attrs.
    def test_blast_link_opens_in_new_tab
      seq = sequences(:local_sequence)
      html = render(Show.new(sequence: seq))

      assert_html(html, "a[target='_blank'][rel='noopener noreferrer']" \
                        "[href*='blast.ncbi.nlm.nih.gov']")
    end

    # When the sequence has a deposit (archive + accession), the
    # deposit line renders and the page also contains the deposit
    # external links (`target: _blank` via plain `link_to`). Sanity-
    # check that the BLAST button and deposit links are both present
    # without conflicting.
    def test_deposited_sequence_shows_deposit_line_and_blast_link
      seq = sequences(:deposited_sequence)
      html = render(Show.new(sequence: seq))

      # BLAST link + deposit archive + deposit accession all open externally
      assert_html(html, "a[target='_blank'][href*='blast.ncbi.nlm.nih.gov']")
      assert_html(html, "a[target='_blank'][href*='ncbi.nlm.nih.gov/nuccore']")
    end
  end
end
