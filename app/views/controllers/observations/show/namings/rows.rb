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
# Replaces `app/views/controllers/observations/show/namings/_rows.erb`.
module Views::Controllers::Observations::Show::Namings
  class Rows < ::Views::Base
    prop :user, ::User
    prop :consensus, ::Observation::NamingConsensus

    def view_template
      render(::Components::ListGroup.new(
               id: "namings_table_rows", flush: true
             )) do |list|
        @consensus.merged_namings.each do |merged_naming|
          list.item do
            render(Row.new(naming: merged_naming, user: @user,
                           consensus: @consensus))
          end
        end
        list.empty { plain(:show_namings_no_names_yet.t) }
      end
    end
  end
end
