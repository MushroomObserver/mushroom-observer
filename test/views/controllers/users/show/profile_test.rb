# frozen_string_literal: true

require("test_helper")

# Tests for the three branches of
# `Views::Controllers::Users::Show::Profile#life_list_text` — covered
# end-to-end via `UsersControllerTest#test_show_user`, but the
# species-only / higher-only branches don't reliably fire from
# fixtures. Pin each branch directly here with a stub
# `Checklist::ForUser`.
module Views::Controllers::Users
  class Show
    class ProfileTest < ComponentTestCase
      def setup
        super
        @show_user = users(:rolf)
        controller.instance_variable_set(:@user, @show_user)
      end

      # ---- life_list_text branches -------------------------------

      def test_life_list_text_both_species_and_higher
        html = render_profile(life_list: stub_life_list(species: 3, higher: 2))

        # `show_user_life_list` translation is the "both" form.
        assert_includes(html, "3 ")
        assert_includes(html, "2 ")
      end

      def test_life_list_text_species_only
        # Regression cover — the species-positive / higher-zero branch
        # only fires for users whose taxa are all species-rank or below.
        html = render_profile(life_list: stub_life_list(species: 5, higher: 0))

        assert_includes(html, :show_user_life_list_species.t(species: 5))
      end

      def test_life_list_text_higher_only
        html = render_profile(life_list: stub_life_list(species: 0, higher: 4))

        assert_includes(
          html,
          :show_user_life_list_higher.t(higher: 4,
                                        taxa_word: :checklist_taxa.l)
        )
      end

      def test_life_list_footer_skipped_when_num_taxa_zero
        # `render_footer` short-circuits on `num_taxa.zero?`, so the
        # life-list block + its surrounding `.panel-footer` don't fire.
        html = render_profile(life_list: stub_life_list(species: 0,
                                                        higher: 0))

        # The "Life list:" label only renders inside the footer block.
        assert_no_html(html, ".panel-footer")
      end

      private

      def render_profile(life_list:)
        render(Profile.new(show_user: @show_user, user: @show_user,
                           life_list: life_list))
      end

      # `Checklist::ForUser` instance with the three count methods
      # stubbed — bypasses the real life-list computation (which would
      # need a user with a specific shape of observations to hit each
      # branch) while keeping the prop type check happy.
      def stub_life_list(species:, higher:)
        list = ::Checklist::ForUser.new(@show_user)
        list.define_singleton_method(:num_taxa) { species + higher }
        list.define_singleton_method(:num_species_observed) { species }
        list.define_singleton_method(:num_higher_level_observed) { higher }
        list
      end
    end
  end
end
