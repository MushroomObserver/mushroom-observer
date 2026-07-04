# frozen_string_literal: true

# Body of the obs-show namings sub-panel — the `list-group` holding
# one row per proposed naming. The container's id
# (`namings_table_rows`) is the Turbo Stream target the
# `NamingsController` / `VotesController` stream actions write to
# when a naming is added / vote changes; rows themselves carry
# `observation_naming_<id>` on their inner `.naming-row` div (set by
# `Show::Namings::Row`), so single-row swaps can target individual
# children too.
#
# Reopen the parent `Namings` class so the nested `Rows` body can
# refer to its sibling `Row` by short name. Without this nesting,
# the lexical scope chain doesn't include `Namings`, and `Row.new`
# would need the full `Views::Controllers::…::Namings::Row` path.
class Views::Controllers::Observations::Show::Namings
  class Rows < Views::Base
    prop :user, ::User
    prop :consensus, ::Observation::NamingConsensus

    def view_template
      ListGroup(id: "namings_table_rows", flush: true) do |list|
        @consensus.merged_namings.each do |merged_naming|
          list.item do
            render(Row.new(naming: merged_naming, user: @user,
                           consensus: @consensus))
          end
        end
        list.empty { trusted_html(:show_namings_no_names_yet.t) }
      end
    end
  end
end
