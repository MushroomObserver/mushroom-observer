# encoding: utf-8
class Descriptions < ActiveRecord::Migration[4.2]
  def self.up
    # ------------------------------------
    #  Add "meta" flag to user_groups.
    # ------------------------------------

    add_column :user_groups, :meta, :boolean, default: false

    # ----------------------------
    #  Add some new user prefs.
    # ----------------------------

    add_column :users, :email_locations_admin, :boolean, default: false
    add_column :users, :email_names_admin,     :boolean, default: false
    add_column :users, :thumbnail_size, :enum, default: :thumbnail, limit: [:thumbnail, :small]
    add_column :users, :image_size,     :enum, default: :medium, limit: Image.all_sizes

    # ----------------------------
    #  Add size to image.
    # ----------------------------

    add_column :images, :width, :integer
    add_column :images, :height, :integer

    # -----------------------------------------------------------
    #  Add location to species_lists, parallel to observations.
    # -----------------------------------------------------------

    add_column :species_lists, :location_id, :integer
    Location.connection.update %(
      UPDATE species_lists spl, locations loc
      SET spl.location_id = loc.id, spl.where = NULL
      WHERE spl.where = loc.display_name
    )

    # Clean up observations while we're at it.
    Observation.connection.update %(
      UPDATE observations SET `where` = NULL WHERE location_id IS NOT NULL
    )

    # --------------------------------------------------------------------
    #  Clean up obs.where and spl.where (remove leading/trailing space).
    # --------------------------------------------------------------------

    Observation.connection.update %(
      UPDATE observations SET `where` = RTRIM(LTRIM(`where`))
      WHERE `where` IS NOT NULL
    )

    SpeciesList.connection.update %(
      UPDATE species_lists SET `where` = RTRIM(LTRIM(`where`))
      WHERE `where` IS NOT NULL
    )

    # --------------------------------------
    #  First create the "all users" group.
    # --------------------------------------

    User.connection.insert %(
      INSERT INTO user_groups (`name`) VALUES ('all users')
    )
    id = User.connection.select_value(%(
      SELECT id FROM user_groups ORDER BY id DESC LIMIT 1
    )).to_i
    User.connection.update %(
      UPDATE user_groups
      SET `created`=NOW(), `modified`=NOW(), `sync_id`="#{id}us1", `meta`=TRUE
      WHERE id = #{id}
    )
    user_ids = User.connection.select_values %(
      SELECT id FROM users
    )
    User.connection.insert %(
      INSERT INTO user_groups_users (`user_id`, `user_group_id`)
      VALUES (#{user_ids.map { |u_id| "#{u_id},#{id}" }.join("), (")})
    )

    # ---------------------------------------------------
    #  Create groups corresponding to each single user.
    # ---------------------------------------------------

    for user_id in user_ids
      User.connection.insert %(
        INSERT INTO user_groups (`name`) VALUES ('user #{user_id}')
      )
      id = User.connection.select_value(%(
        SELECT id FROM user_groups ORDER BY id DESC LIMIT 1
      )).to_i
      User.connection.update %(
        UPDATE user_groups
        SET `created`=NOW(), `modified`=NOW(), `sync_id`="#{id}us1", `meta`=TRUE
        WHERE id = #{id}
      )
      User.connection.insert %(
        INSERT INTO user_groups_users (`user_id`, `user_group_id`)
        VALUES (#{user_id},#{id})
      )
    end

    # -----------------------------------------------------------------
    #  Get ids of these new meta-groups for use in permissions below.
    # -----------------------------------------------------------------

    all_users = User.connection.select_value(%(
      SELECT id FROM user_groups WHERE name = 'all users'
    )).to_i

    reviewers = User.connection.select_value(%(
      SELECT id FROM user_groups WHERE name = 'reviewers'
    )).to_i

    user_groups = {}
    for group_id, name in User.connection.select_rows %(
      SELECT id, name FROM user_groups WHERE name LIKE 'user %'
    )
      user_groups[Regexp.last_match(1).to_i] = group_id.to_i if name.match(/^user (\d+)$/)
    end

    # ------------------------------------------------------
    #  Load in all the old name and location-related data.
    # ------------------------------------------------------

    # puts "Loading name data..."
    # old_names             = Name.connection.select_all('SELECT * FROM names LIMIT 100')
    # old_past_names        = Name.connection.select_all('SELECT * FROM past_names LIMIT 100')
    # old_authors_names     = Name.connection.select_all('SELECT * FROM authors_names LIMIT 100')
    # old_editors_names     = Name.connection.select_all('SELECT * FROM editors_names LIMIT 100')
    #
    # puts "Loading draft data..."
    # projects              = Name.connection.select_all('SELECT * FROM projects LIMIT 100')
    # old_draft_names       = Name.connection.select_all('SELECT * FROM draft_names LIMIT 100')
    # old_past_draft_names  = Name.connection.select_all('SELECT * FROM past_draft_names LIMIT 100')
    #
    # puts "Loading location data..."
    # old_locations         = Name.connection.select_all('SELECT * FROM locations LIMIT 100')
    # old_past_locations    = Name.connection.select_all('SELECT * FROM past_locations LIMIT 100')
    # old_authors_locations = Name.connection.select_all('SELECT * FROM authors_locations LIMIT 100')
    # old_editors_locations = Name.connection.select_all('SELECT * FROM editors_locations LIMIT 100')

    puts "Loading name data..."
    old_names             = Name.connection.select_all("SELECT * FROM names").to_a
    old_past_names        = Name.connection.select_all("SELECT * FROM past_names").to_a
    old_authors_names     = Name.connection.select_all("SELECT * FROM authors_names").to_a
    old_editors_names     = Name.connection.select_all("SELECT * FROM editors_names").to_a

    puts "Loading draft data..."
    projects              = Name.connection.select_all("SELECT * FROM projects").to_a
    old_draft_names       = Name.connection.select_all("SELECT * FROM draft_names").to_a
    old_past_draft_names  = Name.connection.select_all("SELECT * FROM past_draft_names").to_a

    puts "Loading location data..."
    old_locations         = Name.connection.select_all("SELECT * FROM locations").to_a
    old_past_locations    = Name.connection.select_all("SELECT * FROM past_locations").to_a
    old_authors_locations = Name.connection.select_all("SELECT * FROM authors_locations").to_a
    old_editors_locations = Name.connection.select_all("SELECT * FROM editors_locations").to_a

    # Convert results of a select_all into a hash keyed on the given id field.
    # Values are Arrays of records corresponding to the given id.
    def self.hashify(list, id_field)
      hash = {}
      for rec in list
        id = rec[id_field].to_i
        list = hash[id] ||= []
        list << rec
      end
      hash
    end

    puts "Hashifying some results..."
    projects                  = hashify(projects, "id")
    old_draft_names_hash      = hashify(old_draft_names, "name_id")
    old_past_names_hash       = hashify(old_past_names, "name_id")
    old_past_draft_names_hash = hashify(old_past_draft_names, "draft_name_id")
    old_past_locations_hash   = hashify(old_past_locations, "location_id")

    # ----------------------------
    #  Restructure name data.
    # ----------------------------

    names                      = []
    names_versions             = []
    name_descriptions          = []
    name_descriptions_versions = []
    name_descriptions_admins   = []
    name_descriptions_writers  = []
    name_descriptions_readers  = []
    name_descriptions_authors  = []
    name_descriptions_editors  = []

    names_versioned_fields = %w(
      rank text_name display_name observation_name search_name
      author citation deprecated correct_spelling_id)
    names_fields = [
      "sync_id", "version", "created", "modified", "user_id",
      "description_id", "rss_log_id", "synonym_id", "num_views", "last_view",
      *names_versioned_fields
    ]
    names_versions_fields = [
      "name_id", "version", "modified", "user_id",
      *names_versioned_fields
    ]

    name_descriptions_note_fields = %w(
      gen_desc diag_desc distribution habitat look_alikes
      uses notes refs classification)
    name_descriptions_versioned_fields = [
      "license_id", *name_descriptions_note_fields
    ]
    name_descriptions_fields = [
      "sync_id", "version", "created", "modified", "user_id", "name_id",
      "review_status", "last_review", "reviewer_id", "ok_for_export",
      "num_views", "last_view", "source_type", "source_name", "public", "locale",
      *name_descriptions_versioned_fields
    ]
    name_descriptions_versions_fields = [
      "name_description_id", "version", "modified", "user_id",
      *name_descriptions_versioned_fields
    ]
    name_descriptions_admins_fields  = %w(name_description_id user_group_id)
    name_descriptions_writers_fields = %w(name_description_id user_group_id)
    name_descriptions_readers_fields = %w(name_description_id user_group_id)
    name_descriptions_authors_fields = %w(name_description_id user_id)
    name_descriptions_editors_fields = %w(name_description_id user_id)

    puts "Processing name and draft data..."
    i = 0
    for n2 in old_names
      i += 1
      n_id = n2["id"].to_i
      names << nil while names.length < n_id - 1
      if i % 100 == 0
        print "#{(i.to_f / old_names.length * 100).to_i}%\r"
        STDOUT.flush
      end

      nvs = []
      last_nv2 = nil
      for nv2 in old_past_names_hash[n_id] || [n2]
        if !last_nv2 ||
           names_versioned_fields.any? { |f| last_nv2[f] != nv2[f] }
          nv = {}
          names_versions_fields.each { |f| nv[f] = nv2[f] }
          nvs << nv
          nv["name_id"] = n_id
          nv["version"] = nvs.length
          nv["deprecated"] ||= 0
          last_nv2 = nv2
        end
      end

      n = {}
      names_fields.each { |f| n[f] = n2[f] }
      n["sync_id"]  = "#{n_id}us1"
      n["version"]  = nvs.length
      n["modified"] = nvs.last["modified"]
      n["user_id"]  = nvs.first["user_id"]
      n["deprecated"] ||= 0

      names << n
      names_versions += nvs

      if name_descriptions_note_fields.any? { |f| n2[f].to_s.match(/\S/) }
        nd_id = name_descriptions.length + 1

        ndvs = []
        last_nv2 = nil
        for nv2 in old_past_names_hash[n_id] || [n2]
          if name_descriptions_note_fields.any? { |f| nv2[f].to_s.match(/\S/) }
            if !last_nv2 ||
               name_descriptions_versioned_fields.any? { |f| last_nv2[f] != nv2[f] }
              ndv = {}
              name_descriptions_versions_fields.each { |f| ndv[f] = nv2[f] }
              ndvs << ndv
              ndv["name_description_id"] = nd_id
              ndv["version"] = ndvs.length
              last_nv2 = nv2
            end
          end
        end

        if ndvs.any?
          nd = {}
          name_descriptions_fields.each { |f| nd[f] = n2[f] }
          nd["sync_id"]     = "#{nd_id}us1"
          nd["version"]     = ndvs.length
          nd["created"]     = ndvs.first["modified"]
          nd["modified"]    = ndvs.last["modified"]
          nd["user_id"]     = ndvs.first["user_id"]
          nd["name_id"]     = n_id
          nd["public"]      = "1"
          nd["locale"]      = "en-US"
          nd["source_type"] = "public"
          nd["source_name"] = ""
          nd["ok_for_export"] ||= 0
          n["description_id"] = nd_id

          admins = [
            { "name_description_id" => nd_id, "user_group_id" => reviewers }
          ]
          writers = [
            { "name_description_id" => nd_id, "user_group_id" => all_users }
          ]
          readers = [
            { "name_description_id" => nd_id, "user_group_id" => all_users }
          ]
          authors = old_authors_names.
                    select { |rec| rec["name_id"].to_i == n_id }.
                    map { |rec| rec["user_id"].to_i }
          editors = ndvs.map { |rec| rec["user_id"].to_i } - authors
          authors = authors.uniq.sort.map do |id|
            { "name_description_id" => nd_id, "user_id" => id }
          end
          editors = editors.uniq.sort.map do |id|
            { "name_description_id" => nd_id, "user_id" => id }
          end

          name_descriptions << nd
          name_descriptions_versions += ndvs
          name_descriptions_admins += admins
          name_descriptions_writers += writers
          name_descriptions_readers += readers
          name_descriptions_authors += authors
          name_descriptions_editors += editors
        end
      end

      # ----------------------------
      #  Include drafts.
      # ----------------------------

      for d in old_draft_names_hash[n_id] || []
        d_id = d["id"].to_i
        nd_id = name_descriptions.length + 1
        project = projects[d["project_id"].to_i].first

        ndvs = []
        last_ndv2 = nil
        for ndv2 in old_past_draft_names_hash[d_id] || [d]
          if !last_ndv2 ||
             !name_descriptions_versioned_fields.
              select { |f| last_ndv2[f] != ndv2[f] }.empty?
            ndv = {}
            name_descriptions_versions_fields.each { |f| ndv[f] = ndv2[f] }
            ndvs << ndv
            ndv["name_description_id"] = nd_id
            ndv["version"] = ndvs.length
            last_ndv2 = ndv2
          end
        end

        nd = {}
        name_descriptions_fields.each { |f| nd[f] = d[f] }
        nd["sync_id"]       = "#{nd_id}us1"
        nd["version"]       = ndvs.length
        nd["created"]       = ndvs.first["modified"]
        nd["modified"]      = ndvs.last["modified"]
        nd["user_id"]       = ndvs.first["user_id"]
        nd["name_id"]       = n_id
        nd["public"]        = "0"
        nd["locale"]        = "en-US"
        nd["source_type"]   = "project"
        nd["source_name"]   = project["title"]
        nd["review_status"] = "unreviewed"
        nd["ok_for_export"] = "0"

        ag = project["admin_group_id"]
        mg = project["user_group_id"]
        ug = user_groups[d["user_id"].to_i]
        admins = [
          { "name_description_id" => nd_id, "user_group_id" => ag },
          { "name_description_id" => nd_id, "user_group_id" => ug }
        ]
        writers = [
          { "name_description_id" => nd_id, "user_group_id" => ag },
          { "name_description_id" => nd_id, "user_group_id" => ug }
        ]
        readers = [
          { "name_description_id" => nd_id, "user_group_id" => mg },
          { "name_description_id" => nd_id, "user_group_id" => ug }
        ]
        authors = [d["user_id"].to_i]
        editors = ndvs.map { |rec| rec["user_id"].to_i } - authors
        authors = authors.uniq.sort.map do |id|
          { "name_description_id" => nd_id, "user_id" => id }
        end
        editors = editors.uniq.sort.map do |id|
          { "name_description_id" => nd_id, "user_id" => id }
        end

        name_descriptions << nd
        name_descriptions_versions += ndvs
        name_descriptions_admins += admins
        name_descriptions_writers += writers
        name_descriptions_readers += readers
        name_descriptions_authors += authors
        name_descriptions_editors += editors
      end
    end

    # -----------------------------
    #  Restructure location data.
    # -----------------------------

    locations                      = []
    locations_versions             = []
    location_descriptions          = []
    location_descriptions_versions = []
    location_descriptions_admins   = []
    location_descriptions_writers  = []
    location_descriptions_readers  = []
    location_descriptions_authors  = []
    location_descriptions_editors  = []

    locations_versioned_fields = %w(
      display_name north south west east high low)
    locations_fields = [
      "sync_id", "version", "created", "modified", "user_id",
      "description_id", "rss_log_id", "search_name", "num_views", "last_view",
      *locations_versioned_fields
    ]
    locations_versions_fields = [
      "location_id", "version", "modified", "user_id",
      *locations_versioned_fields
    ]

    location_descriptions_note_fields = %w(
      gen_desc ecology species notes refs)
    location_descriptions_versioned_fields = [
      "license_id", *location_descriptions_note_fields
    ]
    location_descriptions_fields = [
      "sync_id", "version", "created", "modified", "user_id", "location_id",
      "num_views", "last_view", "source_type", "source_name", "public", "locale",
      *location_descriptions_versioned_fields
    ]
    location_descriptions_versions_fields = [
      "location_description_id", "version", "modified", "user_id",
      *location_descriptions_versioned_fields
    ]
    location_descriptions_admins_fields  = %w(location_description_id user_group_id)
    location_descriptions_writers_fields = %w(location_description_id user_group_id)
    location_descriptions_readers_fields = %w(location_description_id user_group_id)
    location_descriptions_authors_fields = %w(location_description_id user_id)
    location_descriptions_editors_fields = %w(location_description_id user_id)

    puts "Processing location data..."
    i = 0
    for l2 in old_locations
      i += 1
      l_id = l2["id"].to_i
      locations << nil while locations.length < l_id - 1
      if i % 100 == 0
        print "#{(i.to_f / old_locations.length * 100).to_i}%\r"
        STDOUT.flush
      end

      lvs = []
      last_lv2 = nil
      for lv2 in old_past_locations_hash[l_id] || [l2]
        if !last_lv2 ||
           !locations_versioned_fields.
            select { |f| last_lv2[f] != lv2[f] }.empty?
          lv = {}
          locations_versions_fields.each { |f| lv[f] = lv2[f] }
          lvs << lv
          lv["location_id"] = l_id
          lv["version"] = lvs.length
          last_lv2 = lv2
        end
      end

      l = {}
      locations_fields.each { |f| l[f] = l2[f] }
      l["sync_id"]  = "#{l_id}us1"
      l["version"]  = lvs.length
      l["modified"] = lvs.last["modified"]
      l["user_id"]  = lvs.first["user_id"]

      locations << l
      locations_versions += lvs

      if location_descriptions_note_fields.any? { |f| l2[f].to_s.match(/\S/) }
        ld_id = location_descriptions.length + 1

        ldvs = []
        last_lv2 = nil
        for lv2 in old_past_locations_hash[l_id] || [l2]
          if location_descriptions_note_fields.any? { |f| lv2[f].to_s.match(/\S/) }
            if !last_lv2 ||
               !location_descriptions_versioned_fields.
                select { |f| last_lv2[f] != lv2[f] }.empty?
              ldv = {}
              location_descriptions_versions_fields.each { |f| ldv[f] = lv2[f] }
              ldvs << ldv
              ldv["location_description_id"] = ld_id
              ldv["version"] = ldvs.length
              last_lv2 = lv2
            end
          end
        end

        if ldvs.any?
          ld = {}
          location_descriptions_fields.each { |f| ld[f] = l2[f] }
          ld["sync_id"]     = "#{ld_id}us1"
          ld["version"]     = ldvs.length
          ld["created"]     = ldvs.first["modified"]
          ld["modified"]    = ldvs.last["modified"]
          ld["user_id"]     = ldvs.first["user_id"]
          ld["location_id"] = l_id
          ld["public"]      = "1"
          ld["locale"]      = "en-US"
          ld["source_type"] = "public"
          ld["source_name"] = nil
          l["description_id"] = ld_id

          admins = [
            { "location_description_id" => nd_id, "user_group_id" => reviewers }
          ]
          writers = [
            { "location_description_id" => ld_id, "user_group_id" => all_users }
          ]
          readers = [
            { "location_description_id" => ld_id, "user_group_id" => all_users }
          ]
          authors = old_authors_locations.
                    select { |rec| rec["location_id"].to_i == l_id }.
                    map { |rec| rec["user_id"].to_i }
          editors = ldvs.map { |rec| rec["user_id"].to_i } - authors
          authors = authors.uniq.sort.map do |id|
            { "location_description_id" => ld_id, "user_id" => id }
          end
          editors = editors.uniq.sort.map do |id|
            { "location_description_id" => ld_id, "user_id" => id }
          end

          location_descriptions << ld
          location_descriptions_versions += ldvs
          location_descriptions_admins += admins
          location_descriptions_writers += writers
          location_descriptions_readers += readers
          location_descriptions_authors += authors
          location_descriptions_editors += editors
        end
      end
    end

    # -----------------------------------------
    #  Should be safe to delete old data now.
    # -----------------------------------------

    drop_table "names"
    drop_table "past_names"
    drop_table "draft_names"
    drop_table "past_draft_names"
    drop_table "locations"
    drop_table "past_locations"
    drop_table "authors_names"
    drop_table "editors_names"
    drop_table "authors_locations"
    drop_table "editors_locations"

    # ----------------------------
    #  Create new tables.
    # ----------------------------

    create_table "names", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string "sync_id", limit: 16
      t.integer "version"
      t.datetime "created"
      t.datetime "modified"
      t.integer "user_id"
      t.integer "description_id"
      t.integer "rss_log_id"
      t.integer "num_views", default: 0
      t.datetime "last_view"
      t.enum "rank", limit: Name.all_ranks
      t.string "text_name",        limit: 100
      t.string "search_name",      limit: 200
      t.string "display_name",     limit: 200
      t.string "observation_name", limit: 200
      t.string "author",           limit: 100
      t.text "citation"
      t.boolean "deprecated", default: false, null: false
      t.integer "synonym_id"
      t.integer "correct_spelling_id"
      t.text "notes"
    end

    create_table "names_versions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer "name_id"
      t.integer "version"
      t.datetime "modified"
      t.integer "user_id"
      t.enum "rank", limit: Name.all_ranks
      t.string "text_name",        limit: 100
      t.string "search_name",      limit: 200
      t.string "display_name",     limit: 200
      t.string "observation_name", limit: 200
      t.string "author",           limit: 100
      t.text "citation"
      t.boolean "deprecated", default: false, null: false
      t.integer "correct_spelling_id"
      t.text "notes"
    end

    create_table "name_descriptions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string "sync_id", limit: 16
      t.integer "version"
      t.datetime "created"
      t.datetime "modified"
      t.integer "user_id"
      t.integer "name_id"
      t.enum "review_status", default: :unreviewed, limit: [:unreviewed, :unvetted, :vetted, :inaccurate]
      t.datetime "last_review"
      t.integer "reviewer_id"
      t.boolean "ok_for_export",  default: true, null: false
      t.integer "num_views",      default: 0
      t.datetime "last_view"
      t.enum "source_type", limit: [:public, :foreign, :project, :source, :user]
      t.string "source_name",    limit: 100
      t.string "locale",         limit: 8
      t.boolean "public"
      t.integer "license_id"
      t.integer "merge_source_id"
      for field in name_descriptions_note_fields
        t.text field
      end
    end

    create_table "name_descriptions_versions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer "name_description_id"
      t.integer "version"
      t.datetime "modified"
      t.integer "user_id"
      t.integer "license_id"
      t.integer "merge_source_id"
      for field in name_descriptions_note_fields
        t.text field
      end
    end

    create_table "locations", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string "sync_id", limit: 16
      t.integer "version"
      t.datetime "created"
      t.datetime "modified"
      t.integer "user_id"
      t.integer "description_id"
      t.integer "rss_log_id"
      t.integer "num_views", default: 0
      t.datetime "last_view"
      t.string "display_name", limit: 200
      t.string "search_name",  limit: 200
      t.float "north"
      t.float "south"
      t.float "west"
      t.float "east"
      t.float "high"
      t.float "low"
    end

    create_table "locations_versions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string "location_id"
      t.integer "version"
      t.datetime "modified"
      t.integer "user_id"
      t.string "display_name", limit: 200
      t.float "north"
      t.float "south"
      t.float "west"
      t.float "east"
      t.float "high"
      t.float "low"
    end

    create_table "location_descriptions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.string "sync_id", limit: 16
      t.integer "version"
      t.datetime "created"
      t.datetime "modified"
      t.integer "user_id"
      t.integer "location_id"
      t.integer "num_views", default: 0
      t.datetime "last_view"
      t.enum "source_type", limit: [:public, :foreign, :project, :source, :user]
      t.string "source_name", limit: 100
      t.string "locale",      limit: 8
      t.boolean "public"
      t.integer "license_id"
      t.integer "merge_source_id"
      for field in location_descriptions_note_fields
        t.text field
      end
    end

    create_table "location_descriptions_versions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: true do |t|
      t.integer "location_description_id"
      t.integer "version"
      t.datetime "modified"
      t.integer "user_id"
      t.integer "license_id"
      t.integer "merge_source_id"
      for field in location_descriptions_note_fields
        t.text field
      end
    end

    for x, y, z in [
      %w(admins name_description user_group),
      %w(readers name_description user_group),
      %w(writers name_description user_group),
      %w(authors name_description user),
      %w(editors name_description user),
      %w(admins location_description user_group),
      %w(readers location_description user_group),
      %w(writers location_description user_group),
      %w(authors location_description user),
      %w(editors location_description user)
    ]
      create_table "#{y}s_#{x}", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", id: false, force: true do |t|
        t.integer "#{y}_id", default: 0, null: false
        t.integer "#{z}_id", default: 0, null: false
      end
    end

    # ----------------------------
    #  Populate new tables.
    # ----------------------------

    # Insert records into a new table.
    def self.populate_table(table, columns, data)
      puts "Populating #{table} with #{data.length} rows:"
      id = 0
      for rec in data
        id += 1
        if id % 100 == 0
          print "#{(id.to_f / data.length * 100).to_i}%\r"
          STDOUT.flush
        end
        if rec
          Name.connection.insert %(
            INSERT INTO #{table} (`#{columns.join("`,`")}`)
            VALUES (#{columns.map do |f|
              rec[f] ? "'" + rec[f].to_s.gsub('\\', '\\\\').gsub("'", "''") + "'" : "NULL"
            end.join(",")})
          )
        else
          Name.connection.insert "INSERT INTO #{table} VALUES ()"
          Name.connection.delete "DELETE FROM #{table} WHERE id = #{id}"
        end
      end
    end

    populate_table("names",                          names_fields,                           names)
    populate_table("names_versions",                 names_versions_fields,                  names_versions)
    populate_table("name_descriptions",              name_descriptions_fields,               name_descriptions)
    populate_table("name_descriptions_versions",     name_descriptions_versions_fields,      name_descriptions_versions)
    populate_table("name_descriptions_admins",       name_descriptions_admins_fields,        name_descriptions_admins)
    populate_table("name_descriptions_writers",      name_descriptions_writers_fields,       name_descriptions_writers)
    populate_table("name_descriptions_readers",      name_descriptions_readers_fields,       name_descriptions_readers)
    populate_table("name_descriptions_authors",      name_descriptions_authors_fields,       name_descriptions_authors)
    populate_table("name_descriptions_editors",      name_descriptions_editors_fields,       name_descriptions_editors)

    populate_table("locations",                      locations_fields,                       locations)
    populate_table("locations_versions",             locations_versions_fields,              locations_versions)
    populate_table("location_descriptions",          location_descriptions_fields,           location_descriptions)
    populate_table("location_descriptions_versions", location_descriptions_versions_fields,  location_descriptions_versions)
    populate_table("location_descriptions_admins",   location_descriptions_admins_fields,    location_descriptions_admins)
    populate_table("location_descriptions_writers",  location_descriptions_writers_fields,   location_descriptions_writers)
    populate_table("location_descriptions_readers",  location_descriptions_readers_fields,   location_descriptions_readers)
    populate_table("location_descriptions_authors",  location_descriptions_authors_fields,   location_descriptions_authors)
    populate_table("location_descriptions_editors",  location_descriptions_editors_fields,   location_descriptions_editors)

    # ---------------------------------------------
    #  Now add the classification cache to names.
    # ---------------------------------------------

    add_column :names, :classification, :text

    Name.connection.update %(
      UPDATE names, name_descriptions
         SET names.classification = name_descriptions.classification
       WHERE names.description_id = name_descriptions.id
         AND name_descriptions.classification IS NOT NULL
         AND !(name_descriptions.classification = '')
    )
  end

  def self.down
    # Sorry! This and the next migration can't be reversed without great difficulty.
  end
end
