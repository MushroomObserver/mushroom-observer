# frozen_string_literal: true

require("test_helper")

class HerbariumTest < UnitTestCase
  def test_herbarium_records
    assert(herbaria(:nybg_herbarium).herbarium_records.length > 1)
  end

  def test_mailing_address
    assert(herbaria(:nybg_herbarium).mailing_address)
    assert_nil(herbaria(:rolf_herbarium).mailing_address)
  end

  def test_location
    assert(herbaria(:nybg_herbarium).location)
    assert_nil(herbaria(:rolf_herbarium).location)
  end

  def test_email
    assert(herbaria(:nybg_herbarium).email)
    assert(herbaria(:rolf_herbarium).email)
  end

  def test_curators
    assert(herbaria(:nybg_herbarium).curators.length > 1)
    assert_equal(1, herbaria(:rolf_herbarium).curators.length)
  end

  def test_fields
    assert(herbaria(:nybg_herbarium).name)
    assert(herbaria(:nybg_herbarium).description)
    assert(herbaria(:nybg_herbarium).code)
  end

  def test_merge
    ny = herbaria(:nybg_herbarium)
    f  = herbaria(:field_museum)
    # Make sure it takes at least one field from F.
    ny.update(mailing_address: "")

    name              = ny.name
    code              = ny.code
    email             = ny.email
    mailing_address   = f.mailing_address
    location_id       = ny.location_id
    description       = ny.description
    curators          = (ny.curators + f.curators).uniq
    herbarium_records = ny.herbarium_records + f.herbarium_records
    result            = ny.merge(f)

    assert_objs_equal(ny, result)
    assert_equal(name, result.name)
    assert_equal(code, result.code)
    assert_equal(email, result.email)
    assert_equal(mailing_address, result.mailing_address)
    assert_equal(location_id, result.location_id)
    assert_equal(description, result.description)
    # Do it this way to make absolutely sure no duplicate records are being
    # created in the glue table.  This can and has happened with other tables.
    curator_ids = HerbariumCurator.where(herbarium_id: ny.id).pluck(:user_id)
    assert_equal(curators.map(&:id).sort, curator_ids.sort)
    assert_obj_arrays_equal(herbarium_records, result.herbarium_records)
  end

  def test_mcp_collid
    fungarium = herbaria(:nybg_herbarium)
    # Sorry for the magic numbers, but they are the values in MCP
    assert_equal(3, fungarium.mcp_collid)

    fungarium.update(code: "TENN") # make it the U of Tenn herbarium
    assert_equal(
      7, fungarium.mcp_collid,
      "Index Herborarium code should match " \
      "hyphenated MyCoPortal InstitutionCode"
    )

    fungarium.update(code: "notInMCP") # make it not an MCP collection
    assert_nil(fungarium.mcp_collid)

    assert_nil(herbaria(:rolf_herbarium).mcp_collid)
  end

  def test_web_searchable
    nybg = herbaria(:nybg_herbarium)
    assert(nybg.web_searchable?)

    nybg.update(code: "notInMCP")
    assert_not(nybg.web_searchable?)

    assert_not(herbaria(:rolf_herbarium).web_searchable?)
  end

  def test_mcp_searchable
    assert(herbaria(:nybg_herbarium).mcp_searchable?)
    assert_not(herbaria(:rolf_herbarium).mcp_searchable?)
  end
end
