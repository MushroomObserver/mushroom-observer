# frozen_string_literal: true

class Inat
  # builds an MO Observation from an ::Inat::Obs
  class MoObservationBuilder
    include NamingReasons
    include ImageHandling

    attr_reader :inat_obs, :user, :skipped_images, :unlicensed_obs,
                :created_image_ids

    # Pass external_site:, inat_import:, and observation via **context
    # not as their own named params to avoid ParameterLists offense.
    def initialize(inat_obs:, user:, import_others: false, **context)
      @inat_obs = inat_obs
      @user = user
      @import_others = import_others
      @external_site = context[:external_site] || ExternalSite.inaturalist
      @inat_import = context[:inat_import]
      # Present => upgrade this existing (placeholder) Observation in
      # place instead of creating a new one (#4828).
      @observation = context[:observation]
      @upgrading = @observation.present?
      @skipped_images = 0
      @unlicensed_obs = inat_obs[:license_code].blank? ? 1 : 0
      @created_image_ids = []
    end

    def mo_observation
      if @upgrading
        build_observation
      else
        Naming.suppress_notifications { build_observation }
      end
      @observation
    rescue StandardError
      # Remove an incomplete new Observation from the db -- not one being
      # upgraded, since that record predates this run.
      @observation&.destroy unless @upgrading
      raise
    end

    private

    def build_observation
      create_missing_identification_names
      create_observation
      add_external_link
      add_inat_images(inat_obs[:observation_photos])
      update_names_and_proposals
      add_inat_sequences
    end

    def create_observation
      if @upgrading
        upgrade_observation
      else
        @observation = Observation.create(new_obs_params)
      end
      # Lead naming first so it wins calc_consensus ties (see consensus_naming).
      proposed_namings(community_name, prov_name, override_name, naming_vote).
        each do |name, value|
          add_naming_with_vote(name: name, namer: namer_for(name), value: value)
        end
      @observation.log(create_observation_log_key, user: user)
    end

    # A full import's namings replace the placeholder's single ad-hoc
    # leading-ID naming, not add to it.
    def upgrade_observation
      @observation.namings.destroy_all
      @observation.update!(
        new_obs_params.except(:user, :inat_import_id).
          merge(placeholder: false, inat_stand_in_naming_id: nil)
      )
    end

    def create_observation_log_key
      if @upgrading
        :log_observation_upgraded_from_placeholder
      else
        :log_observation_created
      end
    end

    # Resolves community/provisional/override/lead names, and creates MO
    # Names via the API when needed (#4828 — shared with
    # Inat::SkeletonObservationBuilder).
    def name_resolver
      @name_resolver ||= Inat::LeadNameResolver.new(inat_obs: inat_obs,
                                                    user: user)
    end

    def new_obs_params # rubocop:disable Metrics/AbcSize
      { user: user,
        when: inat_obs.when,
        location: inat_obs.location,
        where: inat_obs.where,
        lat: inat_obs.lat,
        lng: inat_obs.lng,
        gps_hidden: inat_obs.gps_hidden,
        name_id: lead_name.id,
        specimen: inat_obs.specimen?,
        text_name: lead_name.text_name,
        notes: inat_obs.notes,
        inat_import_id: @inat_import&.id,
        # A fresh import is a clean reflection by construction, so mark it
        # read-only now (#4214). The #4585 engine stamps the backlog later.
        reflected_at: Time.zone.now }.merge(collector_attrs)
    end

    # Link the collector to an MO user when the iNat collector (a custom
    # collector field, else the iNat login) matches a User#inat_username;
    # otherwise store the iNat name as free text. See PR #4452 / Joe.
    def collector_attrs
      Observation.resolve_collector(inat_obs.collector, owner: user,
                                                        match_inat: true)
    end

    # The MO name for the iNat Observation Taxon, creating it if needed.
    def community_name = name_resolver.community_name

    # The MO name for the iNat provisional-name observation field, or nil.
    def prov_name = name_resolver.prov_name

    # The MO name for the iNat "Species Name Override" obs field, or nil.
    def override_name = name_resolver.override_name

    # The name proposed as the obs's consensus: the override name when present,
    # else the provisional name, else the Observation Taxon, corrected to its
    # preferred synonym when deprecated in MO. calc_consensus confirms it from
    # the votes, where it carries the highest weight. (#4212, #4533)
    def lead_name = name_resolver.lead_name

    # A deprecated name's best preferred synonym, else the name itself
    # (falling back to itself when a deprecated name has no approved synonym).
    def preferred(name) = name_resolver.preferred(name)

    # Pure: the namings to create as [name, vote] for the given Observation
    # Taxon name, provisional name (or nil), override name (or nil), and the
    # lead's confidence vote. The lead (override, else provisional, else
    # Observation Taxon)
    # leads at lead_vote; every other name and the preferred synonym of any
    # deprecated name follow at Could Be. Lead is first so it wins
    # calc_consensus ties. (#4212, #4533)
    def proposed_namings(community, provisional, override, lead_vote)
      named = [override, provisional, community].compact
      lead = preferred(named.first)
      synonyms = named.select(&:deprecated?).
                 filter_map { |name| name.best_preferred_synonym.presence }
      others = (named + synonyms).uniq(&:id).reject { |n| n.id == lead.id }
      [[lead, lead_vote]] + others.map { |n| [n, Vote::MIN_POS_VOTE] }
    end

    # The proposer of a naming: the iNat user who suggested it when they're
    # an MO user, else the importer.
    def namer_for(name)
      return user unless suggested?(name)

      User.find_by(inat_username: suggester(suggestion(name))) || user
    end

    def add_external_link
      create_import_link(@observation, inat_obs[:id].to_s)
    end

    # Records import provenance as a polymorphic import ExternalLink on the
    # target (Observation or Image, #4299). The URL is derived from the
    # site's template + external_id, so none is stored.
    def create_import_link(target, external_id)
      ExternalLink.create!(
        user: user, target: target, external_site: @external_site,
        external_id: external_id, relationship: :import
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "InatImport: failed to create ExternalLink for " \
        "#{target.class} #{target.id} (iNat #{external_id}): #{e.message}"
      )
    end

    def create_missing_identification_names
      inat_obs[:identifications].each do |ident|
        taxon = Inat::Taxon.new(ident[:taxon])
        next unless taxon.importable?
        next if taxon.name.present?

        name_resolver.create_mo_name(taxon)
      end
    end

    def user_api_key = name_resolver.api_key

    def update_names_and_proposals
      Observation::NamingConsensus.new(@observation).calc_consensus(user)
    end

    def add_naming_with_vote(name:, namer:, value:)
      # Reuse the namer's existing naming for this name rather than stacking
      # a duplicate -- a re-import (or a re-run of this builder) otherwise
      # left the observation with identical namings (#5186).
      naming = @observation.namings.find_by(user: namer, name: name) ||
               Naming.create!(
                 observation: @observation, user: namer, name: name,
                 reasons: { 2 => used_references_explanation(name) }
               )

      vote = Vote.find_or_initialize_by(naming: naming, user: user)
      vote.update!(observation: @observation, value: value)
      # An ObservationView is needed even though noone has viewed this obs.
      ObservationView.find_or_create_by(observation: @observation,
                                        user: user) do |view|
        view.last_view = vote.updated_at
        view.reviewed = 1
      end
    end

    def suggested?(name)
      inat_ids = inat_obs[:identifications].map { |id| id[:taxon][:name] }
      inat_ids.include?(name.text_name)
    end

    def suggester_with_date(name)
      # The iNat user who suggested the name
      suggestion = suggestion(name)
      "#{:naming_reason_suggested_on_inat.l(user: suggester(suggestion))} " \
        "#{suggestion[:created_at]}"
    end

    def suggestion(name)
      inat_obs[:identifications].
        find { |id| id[:taxon][:name] == name.text_name }
    end

    # iNat login of the iNat user who suggested the id on iNat
    def suggester(suggestion)
      suggestion[:user][:login]
    end

    # Confidence weight for the importer's lead (consensus) naming, set
    # from the iNat obs's signals (#4212). Sequence/DNA evidence is the
    # strongest signal; a provisional name or Research Grade is Promising;
    # everything else (needs_id / casual, no sequence) is Could Be.
    def naming_vote
      return Vote::MAXIMUM_VOTE if inat_obs.sequences.present?

      if inat_obs.provisional_name.present? || research_grade?
        Vote::NEXT_BEST_VOTE # Promising
      else
        Vote::MIN_POS_VOTE   # Could Be
      end
    end

    def research_grade?
      inat_obs[:quality_grade] == "research"
    end

    def add_inat_sequences
      inat_obs.sequences.each do |sequence|
        params = { action: :sequence, method: :post,
                   api_key: user_api_key,
                   observation: @observation.id,
                   locus: sequence[:locus],
                   bases: sequence[:bases],
                   archive: sequence[:archive],
                   accession: sequence[:accession],
                   notes: sequence[:notes] }
        API2.execute(params)
      end
    end
  end
end
