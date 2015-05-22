require 'simplecov'
require 'simplecov-gem-profile'
SimpleCov.start "gem"

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'active_record'
require 'schema_auto_foreign_keys'
require 'schema_dev/rspec'

SchemaDev::Rspec.setup

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.include(SchemaPlus::Matchers)
  config.warnings = true
  config.around(:each) do |example|
    with_fk_config(auto_create: true, auto_index: true) do
      ActiveRecord::Migration.suppress_messages do
        example.run
      end
    end
  end
end

def with_fk_config(opts={}, &block)
  save = opts.keys.map{|key| [key, SchemaPlus::ForeignKeys.config.send(key)]}.to_h
  begin
    SchemaPlus::ForeignKeys.config.update_attributes(opts)
    yield
  ensure
    SchemaPlus::ForeignKeys.config.update_attributes(save)
  end
end

def with_fk_auto_create(value = true, &block)
  with_fk_config(:auto_create => value, &block)
end

def define_schema(&block)
  ActiveRecord::Schema.define do
    connection.tables.each do |table|
      drop_table table, force: :cascade
    end
    instance_eval &block
  end
end

SimpleCov.command_name "[ruby#{RUBY_VERSION}-activerecord#{::ActiveRecord.version}-#{ActiveRecord::Base.connection.adapter_name}]"
