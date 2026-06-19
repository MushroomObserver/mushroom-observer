# frozen_string_literal: true

# rubocop:disable Style/FormatString
# `String#%` is used throughout for numeric formatting — `format`
# resolves to Phlex's `<format>` HTML element method inside the
# view's render scope.

# Per-naming vote-breakdown table — one row per non-zero vote value
# with score, weight, voter-count, and (non-anonymous) voter
# UserLinks, plus a totals row. Rendered into both
# `votes/index` (standalone page) and the per-naming vote modal
# triggered from the obs-show namings panel.
#
# NOTE: not built on `Components::Table` — the votes table mixes
# three row shapes (N data rows + 1 hr-separator row + 1 totals
# row) and uses its own `table-naming-votes` Bootstrap-adjacent
# styling with `cellpadding="0" cellspacing="5"` rather than the
# `.table` family Components::Table emits. Matches the
# "Mixed-shape rows that don't share an iteration source" carve-out
# in `.claude/rules/phlex_conversions.md`.
#
module Views::Controllers::Observations::Namings::Votes
  class Table < Views::Base
    prop :naming, _Union(::Naming, ::Observation::MergedNaming)
    # Optional. When the caller already has a NamingConsensus
    # (controller mutation paths), pass it; otherwise the view
    # derives one from `naming.observation` so single-render
    # callsites don't need to construct it.
    prop :consensus, _Nilable(::Observation::NamingConsensus),
         default: nil

    def view_template
      consensus = @consensus ||
                  ::Observation::NamingConsensus.new(@naming.observation)
      @vote_table = consensus.calc_vote_table(@naming)

      p { trusted_html(:show_votes_descript.t) }
      table(cellpadding: "0", cellspacing: "5",
            class: "table-naming-votes") do
        render_header
        render_value_rows
        render_separator
        render_totals_row
      end
    end

    private

    def render_header
      tr do
        th { trusted_html(:show_votes_vote.t) }
        th(align: "center") { trusted_html(:show_votes_score.t) }
        th(align: "center") { trusted_html(:show_votes_weight.t) }
        th(align: "center") { trusted_html(:show_votes_users.t) }
        th { render_nbsp }
      end
    end

    # Sort by descending vote value so "I'd Call It That" rows
    # rise to the top. Zero-value rows are skipped.
    def sorted_vote_keys
      @vote_table.keys.sort do |x, y|
        @vote_table[y][:value] <=> @vote_table[x][:value]
      end
    end

    def render_value_rows
      sorted_vote_keys.each do |str|
        row = @vote_table[str]
        next if row[:value].zero?

        render_value_row(str, row)
      end
    end

    # `String#%` (rather than `Kernel#format`) is used throughout
    # because `format` resolves to Phlex's `<format>` HTML element
    # method inside a view's render scope.
    def render_value_row(str, row) # rubocop:disable Metrics/AbcSize
      tr(class: "text-nowrap") do
        td { trusted_html(str.t) }
        td(align: "center") { plain(row[:value].to_s) }
        td(align: "center") { plain("%.2f" % row[:wgt]) }
        td(align: "center") { plain(row[:num].to_s) }
        td(align: "left") { small { render_voter_links(row[:votes]) } }
      end
    end

    # Strip anonymous votes; pseudorandom but deterministic order
    # (vote id reversed-string sort) so the listing doesn't leak
    # creation-time signal. Show at most three names; cap with
    # "..." when more.
    def render_voter_links(votes)
      visible = votes.reject(&:anonymous?).sort_by { |v| v.id.to_s.reverse }
      return if visible.empty?

      plain("(")
      render_visible_voters(visible)
      plain(")")
    end

    def render_visible_voters(visible)
      visible.each_with_index do |vote, i|
        plain(", ") if i.positive?
        if i < 3
          render(Components::Link::Object::User.new(
                   user: vote.user, name: vote.user.login
                 ))
        else
          plain("...")
          break
        end
      end
    end

    def render_separator
      tr { td(colspan: "5") { hr } }
    end

    def render_totals_row
      tr do
        td(align: "center") { trusted_html(:show_votes_total.t) }
        td(align: "center") { plain("%.2f" % @naming.vote_cache) }
        td(colspan: "2", align: "center") do
          plain("%.2f%%" % @naming.vote_percent)
        end
        td { render_nbsp }
      end
    end

    # Literal `&nbsp;` — the HTML5 parser decodes it to U+00A0
    # which prevents the surrounding `<td>` from collapsing (a
    # plain space lets auto-layout tables flatten the column).
    def render_nbsp
      trusted_html("&nbsp;".html_safe)
    end
  end
end
# rubocop:enable Style/FormatString
