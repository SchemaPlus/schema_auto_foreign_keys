require 'spec_helper'

describe ActiveRecord::Schema do

  let(:connection) { ActiveRecord::Base.connection }

  context "defining with auto_index and auto_create" do

    before(:each) do
      with_fk_config(auto_create: true, auto_index: true) do
        ActiveRecord::Schema.define do

          create_table :users, :force => :cascade do
          end

          create_table :colors, :force => :cascade do
          end

          create_table :shoes, :force => :cascade do
          end

          create_table :posts, :force => true do |t|
            t.integer :user_id, :references => :users, :index => true
            t.integer :shoe_id, :references => :shoes   # should not have an index (except mysql)
            t.integer :color_id   # should not have a foreign key nor index
          end
        end
      end
    end

    it "creates only explicity added indexes" do
      expected = SchemaDev::Rspec::Helpers.mysql? ? 2 : 1
      expect(connection.user_tables_only.collect { |table| connection.indexes(table) }.flatten.size).to eq(expected)
    end

    it "should create only explicity added foriegn keys" do
      expect(connection.user_tables_only.collect { |table| connection.foreign_keys(table) }.flatten.size).to eq(2)
    end

  end

end
