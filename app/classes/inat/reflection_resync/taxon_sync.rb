# frozen_string_literal: true

class Inat
  class ReflectionResync
    # Keeps a reflection's source-derived namings current with its iNat
    # identification (#4215). When the Observation Taxon, provisional
    # name or name override changes, the old lead stays as a naming at
    # Could Be and the new lead is proposed at the #4212 weight, both via
    # Inat::NamingPlan so import and resync agree. Sequence evidence for
    # that weight counts the whole occurrence: a native sequence on the
    # companion is evidence for the specimen the reflection mirrors.
    #
    # Only source-derived rows move: namings and votes carrying the
    # site's external_site_id, stamped by the importer or here. A
    # person's namings and votes on the reflection are never changed.
    # A name the plan needs but MO lacks is created as the admin actor,
    # the resync's owner, trusting iNat's rank.
    class TaxonSync
      Outcome = Data.define(:added, :reweighted, :alerts) do
        def changed?
          added.positive? || reweighted.positive?
        end
      end

      def call(obs, inat_obs)
        @obs = obs
        @inat_obs = inat_obs
        @site = ReflectionResync.inat_link(obs).external_site
        @added = 0
        @reweighted = 0
        @alerts = []
        proposals = plan
        Naming.suppress_notifications { apply(proposals) } if proposals
        Outcome.new(added: @added, reweighted: @reweighted, alerts: @alerts)
      end

      private

      # nil when the identification can't be mirrored: an iNat "Unknown"
      # (no importable taxon) is left alone; an unresolvable lead is
      # reported for the batch's alert digest.
      def plan
        return nil unless @inat_obs.taxon_importable?

        community = community_name
        return nil unless community

        provisional = parsed_name(@inat_obs.provisional_name,
                                  "provisional name")
        Inat::NamingPlan.new(
          community: community, provisional: provisional,
          override: parsed_name(@inat_obs.name_override, "name override"),
          lead_vote: lead_vote(provisional)
        ).proposals
      end

      def lead_vote(provisional)
        Inat::NamingPlan.lead_vote_for(
          quality_grade: @inat_obs[:quality_grade],
          sequence_evidence: sequence_evidence?,
          provisional_evidence: !provisional.nil?
        )
      end

      def community_name
        @inat_obs.name ||
          create_name(**Inat::Taxon.new(@inat_obs[:taxon]).mo_name_params) ||
          alert("iNat taxon #{@inat_obs.inat_taxon_name.inspect} has no " \
                "MO name and could not be created")
      end

      def parsed_name(str, label)
        return nil if str.blank?

        parsed = Name.parse_name(str)
        if parsed.nil? || parsed.text_name.blank?
          return alert("#{label} #{str.inspect} does not parse as a name")
        end

        Name.where(text_name: parsed.text_name).
          order(deprecated: :asc, created_at: :desc).first ||
          create_name(name: parsed.search_name, rank: parsed.rank) ||
          alert("#{label} #{str.inspect} could not be created as an MO name")
      end

      def create_name(name:, rank:)
        Name.create_with_trusted_rank(User.admin, name, rank)
      end

      def alert(message)
        @alerts << message
        nil
      end

      def sequence_evidence?
        return true if @inat_obs.sequences.present?

        Sequence.where(observation_id: member_ids).exists?
      end

      def member_ids
        return [@obs.id] unless @obs.occurrence_id

        Observation.where(occurrence_id: @obs.occurrence_id).select(:id)
      end

      def apply(proposals)
        voted = source_voted_namings
        proposals.each do |proposal|
          naming = voted.find { |n| n.name_id == proposal.name.id } ||
                   find_or_create(proposal.name)
          set_vote(naming, proposal.vote)
        end
        demote_unplanned(voted, proposals)
      end

      # The namings the source currently speaks for: those carrying the
      # importer's stamped vote. Identified by the vote, not the naming,
      # because the source also votes on a naming a person proposed first.
      def source_voted_namings
        @obs.namings.joins(:votes).
          where(votes: { user_id: importer.id,
                         external_site_id: @site.id }).distinct.to_a
      end

      # A name the source no longer proposes keeps its naming; only the
      # source's own vote on it drops, to Could Be.
      def demote_unplanned(voted, proposals)
        planned = proposals.map { |p| p.name.id }
        voted.reject { |n| planned.include?(n.name_id) }.
          each { |n| set_vote(n, Vote::MIN_POS_VOTE, demote: true) }
      end

      # A naming for this name may already be on the observation, in which
      # case the source votes on it rather than proposing the same name
      # again: Naming rejects a second proposal by the same user, and a
      # person's naming is not ours to duplicate or to claim. The
      # importer's own naming from before the marker is the same
      # source-derived row, so that one is stamped. Otherwise create one,
      # credited as the importer does: to the iNat identifier when they
      # are an MO user, else the importer.
      def find_or_create(name)
        existing = @obs.namings.where(name: name).to_a
        ours = existing.find { |n| n.user_id == importer.id }
        return stamp(ours) if ours
        return existing.first if existing.any?

        @added += 1
        Naming.create!(observation: @obs, user: namer_for(name), name: name,
                       external_site: @site, reasons: { 2 => reason })
      end

      def stamp(naming)
        return naming if naming.external_site_id == @site.id

        naming.update_column(:external_site_id, @site.id)
        naming
      end

      def reason
        "<a href=\"#{Inat::Constants::SITE}/observations/#{@inat_obs[:id]}\">" \
          "iNat #{@inat_obs[:id]}</a>, #{:inat_leading_id.l} " \
          "#{Time.zone.today.strftime("%Y-%m-%d")}"
      end

      def namer_for(name)
        ident = @inat_obs[:identifications].to_a.
                find { |i| i.dig(:taxon, :name) == name.text_name }
        (ident && User.find_by(inat_username: ident.dig(:user, :login))) ||
          importer
      end

      def importer
        @obs.user
      end

      # The importer's vote on the naming is the source-derived one. A
      # demotion only lowers: a vote already at or below Could Be stays.
      def set_vote(naming, value, demote: false)
        vote = naming.votes.find_by(user: importer)
        return if demote && (vote.nil? || vote.value <= value)
        return mark_vote(vote) if vote && vote.value == value

        consensus = Observation::NamingConsensus.new(@obs)
        @reweighted += 1 if consensus.change_vote(naming, value, importer)
        mark_vote(naming.votes.find_by(user: importer))
      end

      def mark_vote(vote)
        return unless vote && vote.external_site_id != @site.id

        vote.update_column(:external_site_id, @site.id)
      end
    end
  end
end
