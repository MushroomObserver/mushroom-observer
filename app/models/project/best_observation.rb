# frozen_string_literal: true

#  = Project::BestObservation
#
#  The observation of one name a project would put forward: the one a
#  QR code on a fair label should lead to.
#
#  A printed label outlives the observation it was made from -- a
#  better photograph of the same mushroom turns up, or a better
#  identification -- so the label points here instead of at a fixed
#  observation, and this answers with whatever the project holds now.
#
#  Preference, in order:
#
#  1. in the project, has an image, and the community is at least
#     "Promising" about the name;
#  2. in the project and has an image;
#  3. in the project.
#
#  Within whichever of those holds, the best-voted photograph wins, and
#  the most recent observation breaks a tie. A photograph is what makes
#  a scan worth the trouble, which is why it leads.
#
#  Synonyms count: an observation filed under any name in the taxon's
#  synonym group is an observation of that taxon.
#
class Project::BestObservation
  # Vote::CONFIDENCE_VALS calls 2.0 "Promising".
  PROMISING = 2.0

  def initialize(project, name)
    @project = project
    @name = name
  end

  def observation
    return nil unless @project && @name

    confident_with_image || with_image || any
  end

  private

  def confident_with_image
    best(with_image_scope.where(Observation[:vote_cache].gteq(PROMISING)))
  end

  def with_image
    best(with_image_scope)
  end

  def any
    best(scope)
  end

  def scope
    @project.observations.where(name_id: taxon_name_ids)
  end

  def with_image_scope
    scope.where.not(thumb_image_id: nil)
  end

  # Ordered in Ruby rather than SQL: an observation's image votes are a
  # column on each of its images, so the rank is a max across a
  # has_many, which no single ORDER BY expresses.
  def best(candidates)
    candidates.includes(:images).max_by do |observation|
      [best_image_vote(observation), observation.when.to_s, observation.id]
    end
  end

  # 1.0 (worst) to 4.0 (best); 0 when nobody has voted on any of them.
  def best_image_vote(observation)
    observation.images.filter_map(&:vote_cache).max || 0.0
  end

  def taxon_name_ids
    return [@name.id] unless @name.synonym_id

    Name.where(synonym_id: @name.synonym_id).pluck(:id)
  end
end
