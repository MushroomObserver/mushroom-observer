# frozen_string_literal: true

class Inat
  # The namings an iNaturalist observation warrants on its MO reflection
  # and their confidence votes (#4212). Shared by the importer, creating
  # the reflection, and the resync's taxon engine, keeping it current, so
  # both propose the same names at the same weights.
  #
  # The lead is the override, else the provisional name, else the
  # Observation Taxon, corrected to its preferred synonym when deprecated
  # in MO. Its vote follows the source's evidence: sequence/DNA data is
  # Maximum, a provisional name or Research Grade is Promising, anything
  # else Could Be. Every other name, and the preferred synonym of any
  # deprecated name, follows at Could Be. The lead comes first so it wins
  # calc_consensus ties.
  class NamingPlan
    Proposal = Data.define(:name, :vote)

    # A deprecated name's best preferred synonym, else the name itself.
    def self.preferred(name)
      return name unless name.deprecated?

      name.best_preferred_synonym.presence || name
    end

    # The lead's confidence vote from the source's signals.
    # `provisional_evidence:` is whether the source carries a provisional
    # name at all -- it counts even when it can't be resolved to an MO
    # name.
    def self.lead_vote_for(quality_grade:, sequence_evidence:,
                           provisional_evidence:)
      return Vote::MAXIMUM_VOTE if sequence_evidence
      return Vote::NEXT_BEST_VOTE if provisional_evidence ||
                                     quality_grade == "research"

      Vote::MIN_POS_VOTE
    end

    attr_reader :lead_vote

    def initialize(community:, lead_vote:, provisional: nil, override: nil)
      @named = [override, provisional, community].compact
      @lead_vote = lead_vote
    end

    def lead
      self.class.preferred(@named.first)
    end

    def proposals
      [Proposal.new(name: lead, vote: lead_vote)] +
        others.map { |n| Proposal.new(name: n, vote: Vote::MIN_POS_VOTE) }
    end

    private

    # Every named name and the preferred synonym of any deprecated one,
    # minus the lead.
    def others
      synonyms = @named.select(&:deprecated?).
                 filter_map { |name| name.best_preferred_synonym.presence }
      (@named + synonyms).uniq(&:id).reject { |n| n.id == lead.id }
    end
  end
end
