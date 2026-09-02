# frozen_string_literal: true

class Inat
  # Resolves the MO Name(s) for an iNat observation: the plain Observation
  # Taxon ("community" identification), the Provisional Species Name and
  # Species Name Override observation fields (if any), and the combined
  # "lead" name a builder should use when it can only pick one. Creates MO
  # Names via the API when no matching Name exists yet (iNat taxa lack
  # ICN ids to look up by). Shared by Inat::MoObservationBuilder (which
  # additionally proposes the non-lead names as alternates) and
  # Inat::SkeletonObservationBuilder (which uses #lead_name alone).
  class LeadNameResolver
    MO_API_KEY_NOTES = InatImportsController::MO_API_KEY_NOTES

    attr_reader :inat_obs, :user

    def initialize(inat_obs:, user:)
      @inat_obs = inat_obs
      @user = user
    end

    # The MO name for the iNat Observation Taxon, creating it if needed.
    def community_name
      @community_name ||=
        inat_obs.name ||
        create_mo_name(Inat::Taxon.new(inat_obs[:taxon])) ||
        Name.unknown
    end

    # The MO name for the iNat provisional-name observation field, or nil.
    # iNat can't use a provisional name as its own identification, so it is a
    # separate proposal from the Observation Taxon. Creates the MO name if
    # absent.
    # NOTE: iNat users seem to add a prov name only when there's a sequence.
    def prov_name
      return nil if inat_obs.provisional_name.blank?

      @prov_name ||= find_or_create_name(
        Name.parse_name(inat_obs.provisional_name)
      )
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

    # The name proposed as the obs's consensus: the override name when present,
    # else the provisional name, else the Observation Taxon, corrected to its
    # preferred synonym when deprecated in MO. (#4212, #4533)
    def lead_name
      @lead_name ||= preferred(override_name || prov_name || community_name)
    end

    # The pure "Leading ID" (iNat's community/Observation Taxon), ignoring
    # "Species Name Override" and "Provisional Species Name"
    # field entirely -- unlike #lead_name.
    # A skeleton counterpart (#4828)
    # always tracks this, both at initial import
    # (Inat::SkeletonObservationBuilder) and at every later resync (#4215):
    # unlike a full import, it has exactly one, un-attributed Naming, so
    # honoring an override/provisional field there would silently
    # substitute a name nobody asked MO to track, in place of the taxon
    # iNat itself is actually leading with.
    def leading_id_name
      @leading_id_name ||= preferred(community_name)
    end

    # Citation text for the single, un-attributed "Used references" reason
    # a skeleton counterpart's Naming carries -- shared by the initial
    # import (Inat::SkeletonObservationBuilder) and any later resync that
    # revises the naming when iNat's own lead taxon has changed (#4828,
    # #4215).
    def reason_text
      link = "<a href=\"#{Inat::Constants::SITE}/observations/" \
             "#{inat_obs[:id]}\">iNat #{inat_obs[:id]}</a>"
      "#{link}, #{:inat_leading_id.l} #{Time.zone.today.strftime("%Y-%m-%d")}"
    end

    # A deprecated name's best preferred synonym, else the name itself
    # (falling back to itself when a deprecated name has no approved synonym).
    def preferred(name)
      return name unless name.deprecated?

      name.best_preferred_synonym.presence || name
    end

    # iNat "complex" rank needs special treatment because
    # The equivalent MO rank is a one-off, requiring special handling
    def create_mo_name(taxon)
      complex = taxon[:rank] == "complex"
      rank_str = complex ? "Group" : taxon[:rank].titleize
      name_str = if complex
                   # append "complex" to prevent parsing it as a Species
                   "#{taxon.full_name_string} complex"
                 else
                   taxon.full_name_string
                 end

      post_name(name: name_str, rank: rank_str)
    end

    def post_name(name:, rank:)
      params = { method: :post, action: :name,
                 api_key: api_key,
                 name: name,
                 rank: rank }
      api = API2.execute(params)
      return api.results.first unless api.errors.any?
      return name_with_trusted_rank(name, rank) if rank_parse_error?(api)

      raise("Failed to create name #{name.inspect}: " \
            "#{api.errors.join(", ")}")
    end

    def api_key
      APIKey.find_by(user: user, notes: MO_API_KEY_NOTES).key
    end

    private

    def rank_parse_error?(api)
      api.errors.any? do |e|
        e.is_a?(API2::NameDoesntParse) || e.is_a?(API2::NameWrongForRank)
      end
    end

    # iNat's declared rank is authoritative even when the name string
    # conflicts with MO's rank-guessing heuristic (e.g. suffix collisions
    # like "-ineae" matching Suborder before Tribe, as with
    # "Leucocoprineae"). This bypasses only this internal fallback; the
    # public Name-creation API's parse check is unchanged for other
    # callers.
    def name_with_trusted_rank(name, rank)
      Name.create_with_trusted_rank(user, name, rank) ||
        raise("Failed to create name #{name.inspect} at rank #{rank}")
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
        post_name(name: parsed.search_name, rank: parsed.rank)
      else
        best_mo_homonym(parsed.text_name)
      end
    end

    def best_mo_homonym(text_name)
      Name.where(text_name: text_name).
        order(deprecated: :asc, created_at: :desc).
        first
    end
  end
end
