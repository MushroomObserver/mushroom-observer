# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::Votes::Anonymity
  class FormTest < ComponentTestCase
    def test_renders_vote_counts
      html = render_form(num_anonymous: 5, num_public: 10)

      # Each count renders as a `<p>` containing the label text plus a
      # `<strong>` with the number. Scope to the `<strong>` so we get
      # the count (not "5 votes" from anywhere else on the page).
      doc = Nokogiri::HTML(html)
      strongs = doc.css("p strong").map(&:text)
      assert_includes(strongs, "5")
      assert_includes(strongs, "10")
      # And the labels themselves are in the `<p>`s directly — pull
      # both texts and check both labels appear (assert_html's at_css
      # only inspects the first match).
      paragraphs = doc.css("p").map(&:text)
      assert(paragraphs.any? do |t|
        t.include?(:image_vote_anonymity_num_anonymous.l)
      end)
      assert(paragraphs.any? do |t|
        t.include?(:image_vote_anonymity_num_public.l)
      end)
    end

    def test_renders_make_public_button
      html = render_form(num_anonymous: 5, num_public: 10)

      assert_html(
        html,
        "input[type='submit'][value='#{:image_vote_anonymity_make_public.l}']"
      )
    end

    def test_form_has_correct_attributes
      html = render_form(num_anonymous: 5, num_public: 10)

      assert_html(html, "form[action='/images/votes/anonymity']")
      assert_html(html, "form[method='post']")
      assert_html(html, "input[name='_method'][value='put']")
    end

    def test_public_button_disabled_when_no_anon_votes_exist
      html = render_form(num_anonymous: 0, num_public: 10)

      button_value = :image_vote_anonymity_make_public.l
      assert_html(html, "input[disabled][value='#{button_value}']")
    end

    private

    def render_form(num_anonymous: 0, num_public: 0)
      form_object = FormObject::ImageVoteAnonymity.new(
        num_anonymous: num_anonymous,
        num_public: num_public
      )
      render(Form.new(form_object))
    end
  end
end
