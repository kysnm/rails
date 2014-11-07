# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

module PostgresqlUUIDHelper
  def connection
    @connection ||= ActiveRecord::Base.connection
  end

  def drop_table(name)
    connection.execute "drop table if exists #{name}"
  end
end

class PostgresqlLargeKeysTest < ActiveRecord::TestCase
  include PostgresqlUUIDHelper
  def setup
    connection.create_table('big_serials', id: :bigserial) do |t|
      t.string 'name'
    end
  end

  def test_omg
    schema = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection, schema)
    assert_match "create_table \"big_serials\", id: :bigserial",
      schema.string
  end

  def teardown
    drop_table "big_serials"
  end
end
