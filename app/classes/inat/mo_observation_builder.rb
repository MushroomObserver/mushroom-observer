# frozen_string_literal: true

class Inat
  # builds an MO Observation from an ::Inat::Obs
  class MoObservationBuilder
    include NamingReasons
    include ImageHandling

    attr_reader :inat_obs, :user, :skipped_images, :unlicensed_obs

    MO_API_KEY_NOTES = InatImportsController::MO_API_KEY_NOTES

    def initialize(inat_obs:, user:, import_others: false,
                   external_site: nil, inat_import: nil)
      @inat_obs = inat_obs
      @user = user
      @import_others = import_others
      @external_site = external_site || ExternalSite.inaturalist
      @inat_import = inat_import
      @skipped_images = 0
      @unlicensed_obs = inat_obs[:license_code].blank? ? 1 : 0
    end

    def mo_observation
      create_missing_identification_names
      create_observation
      add_external_link
      add_inat_images(inat_obs[:observation_photos])
      update_names_and_proposals
      add_inat_sequences
      @observation
    rescue StandardError => e
      # Remove incomplete Observation from the db
      @observation&.destroy
      raise(e)
    end

    private

    def create_observation
      @observation = Observation.create(new_obs_params)
      # Lead naming first so it wins calc_consensus ties (see consensus_naming).
      proposed_namings(community_name, prov_name, override_name, naming_vote).
        each do |name, value|
          add_naming_with_vote(name: name, namer: namer_for(name), value: value)
        end
      @observation.log(:log_observation_created, user: user)
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
        inat_import_id: @inat_import&.id }.merge(collector_attrs)
    end

    # Link the collector to an MO user when the iNat collector (a custom
    # collector field, else the iNat login) matches a User#inat_username;
    # otherwise store the iNat name as free text. See PR #4452 / Joe.
    def collector_attrs
      Observation.resolve_collector(inat_obs.collector, owner: user,
                                                        match_inat: true)
    end

    # The MO name for the iNat Observation Taxon, creating it if needed.
    def community_name
      resolved_obs_name
    end

    # The MO name for the iNat provisional-name observation field, or nil.
    # iNat can't use a provisional name as its own identification, so it is a
    # separate proposal from the Observation Taxon. Creates the MO name if
    # absent.
    # NOTE: iNat users seem to add a prov name only when there's a sequence.
    def prov_name
      return nil if inat_obs.provisional_name.blank?

      @prov_name ||= find_or_create_prov_name
    end

    def find_or_create_prov_name
      find_or_create_name(Name.parse_name(inat_obs.provisional_name))
    end

    # The MO name for the iNat "Species Name Override" obs field, or nil. The
    # override outranks the provisional name and the Observation Taxon as the
    # lead (#4533). Returns nil - falling back to the provisional/Community
    # lead - when the override value can't be parsed or created as an MO Name.
    def override_name
      return @override_name if defined?(@override_name)

      @override_name =
        inat_obs.name_override.blank? ? nil : find_or_create_override_name
    end

    def find_or_create_override_name
      find_or_create_name(Name.parse_name(inat_obs.name_override)) ||
        log_ignored_override("unparseable or uncreatable name")
    rescue StandardError => e
      log_ignored_override(e.message)
    end

    # Logs why an override was dropped (so a fall-back isn't silent) and
    # returns nil for the override lead. (#4533)
    def log_ignored_override(reason)
      Rails.logger.warn("InatImport: ignoring Species Name Override " \
                        "#{inat_obs.name_override.inspect}: #{reason}")
      nil
    end

    # Existing MO Name for the parsed name, else create it via the API (iNat
    # taxa/provisional names lack ICN ids). nil when the name won't parse.
    def find_or_create_name(parsed)
      return nil if parsed.nil? || parsed.text_name.blank?

      if Name.where(text_name: parsed.text_name).none?
        add_provisional_name(parsed)
      else
        best_mo_homonym(parsed.text_name)
      end
    end

    # The name proposed as the obs's consensus: the override name when present,
    # else the provisional name, else the Observation Taxon, corrected to its
    # preferred synonym when deprecated in MO. calc_consensus confirms it from
    # the votes, where it carries the highest weight. (#4212, #4533)
    def lead_name
      @lead_name ||= preferred(override_name || prov_name || community_name)
    end

    # A deprecated name's best preferred synonym, else the name itself
    # (falling back to itself when a deprecated name has no approved synonym).
    def preferred(name)
      return name unless name.deprecated?

      name.best_preferred_synonym.presence || name
    end

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

        create_mo_name(taxon)
      end
    end

    def resolved_obs_name
      @resolved_obs_name ||=
        inat_obs.name ||
        create_mo_name(Inat::Taxon.new(inat_obs[:taxon])) ||
        Name.unknown
    end

    def create_mo_name(taxon)
      # iNat "complex" rank needs special treatment because
      # The equivalent MO rank is a one-off, requiring special handling
      complex = taxon[:rank] == "complex"
      rank_str = complex ? "Group" : taxon[:rank].titleize
      name_str = if complex
                   # append "complex" to prevent parsing it as a Species
                   "#{taxon.full_name_string} complex"
                 else
                   taxon.full_name_string
                 end

      # There's no author or ICN ID because iNat taxa lack those.
      post_name(name: name_str, rank: rank_str)
    end

    def add_provisional_name(parsed_prov_name)
      post_name(name: parsed_prov_name.search_name, rank: parsed_prov_name.rank)
    end

    def post_name(name:, rank:)
      params = { method: :post, action: :name,
                 api_key: user_api_key,
                 name: name,
                 rank: rank }
      api = API2.execute(params)
      if api.errors.any?
        raise("Failed to create name #{name.inspect}: " \
              "#{api.errors.join(", ")}")
      end

      api.results.first
    end

    def user_api_key
      APIKey.find_by(user: user, notes: MO_API_KEY_NOTES).key
    end

    def update_names_and_proposals
      Observation::NamingConsensus.new(@observation).calc_consensus(user)
    end

    def add_naming_with_vote(name:, namer:, value:)
      used_references = 2
      explanation = used_references_explanation(name)
      naming = Naming.create(
        observation: @observation,
        user: namer, name: name,
        reasons: { used_references => explanation }
      )

      vote = Vote.create(naming: naming, observation: @observation,
                         user: user, value: value)
      # We need an ObservationView, but noone has actually viewed this Obs.
      ObservationView.create!(observation: @observation, user: user,
                              last_view: vote.updated_at, reviewed: 1)
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

    def best_mo_homonym(text_name)
      Name.where(text_name: text_name).
        order(deprecated: :asc, created_at: :desc).
        first
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
