# encoding: utf-8
require 'spec_helper'

describe ActiveRecord::Migration do

  before(:each) do
    define_schema do

      create_table :users do |t|
        t.string :login, :index => { :unique => true }
      end

      create_table :members do |t|
        t.string :login
      end

      create_table :comments do |t|
        t.string :content
        t.integer :user
        t.integer :user_id
        t.foreign_key :user_id, :users, :primary_key => :id
      end

      create_table :posts do |t|
        t.string :content
      end
    end
    class User < ::ActiveRecord::Base ; end
    class Post < ::ActiveRecord::Base ; end
    class Comment < ::ActiveRecord::Base ; end
  end

  around(:each) do |example|
    with_fk_config(:auto_create => true, :auto_index => true) { example.run }
  end

  context "when table is created" do

    before(:each) do
      @model = Post
    end

    it "creates auto foreign keys" do
      create_table(@model) do |t|
        t.integer :user_id
      end
      expect(@model).to reference(:users, :id).on(:user_id)
    end

    it "respects explicit foreign key" do
      create_table(@model) do |t|
        t.integer :author_id, :foreign_key => { :references => :users }
      end
      expect(@model).to reference(:users, :id).on(:author_id)
      expect(@model).to have_index.on(:author_id)
    end

    it "suppresses auto foreign key" do
      create_table(@model) do |t|
        t.integer :member_id, :foreign_key => false
      end
      expect(@model).not_to reference.on(:member_id)
      expect(@model).not_to have_index.on(:member_id)
    end

    it "suppresses auto foreign key using shortcut" do
      create_table(@model) do |t|
        t.integer :member_id, :references => nil
      end
      expect(@model).not_to reference.on(:member_id)
      expect(@model).not_to have_index.on(:member_id)
    end

    [:references, :belongs_to].each do |reftype|

      context "when define #{reftype}" do

        before(:each) do
          @model = Comment
        end

        it "auto creates foreign key" do
          create_reference(reftype, :post)
          expect(@model).to reference(:posts, :id).on(:post_id)
        end

        it "does not create a foreign_key if polymorphic" do
          create_reference(reftype, :post, :polymorphic => true)
          expect(@model).not_to reference(:posts, :id).on(:post_id)
        end

        it "does not create a foreign_key with :foreign_key => false" do
          create_reference(reftype, :post, :foreign_key => false)
          expect(@model).not_to reference(:posts, :id).on(:post_id)
        end

        it "should create an index implicitly" do
          create_reference(reftype, :post)
          expect(@model).to have_index.on(:post_id)
        end

        it "should create exactly one index explicitly (#157)" do
          create_reference(reftype, :post, :index => true)
          expect(@model).to have_index.on(:post_id)
        end

        it "should respect :unique (#157)" do
          create_reference(reftype, :post, :index => :unique)
          expect(@model).to have_unique_index.on(:post_id)
        end

        it "should create a two-column index if polymophic and index requested" do
          create_reference(reftype, :post, :polymorphic => true, :index => true)
          expect(@model).to have_index.on([:post_id, :post_type])
        end

        protected

        def create_reference(reftype, column_name, *args)
          create_table(@model) do |t|
            t.send reftype, column_name, *args
          end
        end

      end
    end

    it "creates auto-index on foreign keys only" do
      create_table(@model) do |t|
        t.integer :user_id
        t.integer :application_id, :references => nil
        t.integer :state
      end
      expect(@model).to have_index.on(:user_id)
      expect(@model).not_to have_index.on(:application_id)
      expect(@model).not_to have_index.on(:state)
    end

    it "handles very long index names" do
      table = ("ta"*15 + "_id")
      column = ("co"*15 + "_id")
      expect {
        ActiveRecord::Migration.create_table table do |t|
          t.integer column, foreign_key: { references: :members, name: "verylong" }
        end
      }.not_to raise_error
      expect(ActiveRecord::Base.connection.indexes(table).first.columns.first).to eq column
    end

    it "overrides foreign key auto_create positively" do
      with_fk_config(:auto_create => false) do
        create_table @model, :foreign_keys => {:auto_create => true} do |t|
          t.integer :user_id
        end
        expect(@model).to reference(:users, :id).on(:user_id)
      end
    end

    it "overrides foreign key auto_create negatively" do
      with_fk_config(:auto_create => true) do
        create_table @model, :foreign_keys => {:auto_create => false} do |t|
          t.integer :user_id
        end
        expect(@model).not_to reference.on(:user_id)
      end
    end

    it "overrides foreign key auto_index positively" do
      with_fk_config(:auto_index => false) do
        create_table @model, :foreign_keys => {:auto_index => true} do |t|
          t.integer :user_id
        end
        expect(@model).to have_index.on(:user_id)
      end
    end

    it "overrides foreign key auto_index negatively", :mysql => :skip do
      with_fk_config(:auto_index => true) do
        create_table @model, :foreign_keys => {:auto_index => false} do |t|
          t.integer :user_id
        end
        expect(@model).not_to have_index.on(:user_id)
      end
    end

    it "disables auto-index for a column", :mysql => :skip do
      with_fk_config(:auto_index => true) do
        create_table @model do |t|
          t.integer :user_id, :index => false
        end
        expect(@model).not_to have_index.on(:user_id)
      end
    end

  end

  context "when table is changed", :sqlite3 => :skip do
    before(:each) do
      @model = Post
    end
    [false, true].each do |bulk|
      suffix = bulk ? ' with :bulk option' : ""

      it "auto creates a foreign key constraint"+suffix do
        change_table(@model, :bulk => bulk) do |t|
          t.integer :user_id
        end
        expect(@model).to reference(:users, :id).on(:user_id)
      end

      context "migrate down" do
        it "removes an auto foreign key and index"+suffix do
          create_table Comment do |t|
            t.integer :user_id
          end
          expect(Comment).to reference(:users, :id).on(:user_id)
          expect(Comment).to have_index.on(:user_id)
          migration = Class.new ::ActiveRecord::Migration.latest_version do
            define_method(:change) {
              change_table("comments", :bulk => bulk) do |t|
                t.integer :user_id
              end
            }
          end
          migration.migrate(:down)
          Comment.reset_column_information
          expect(Comment).not_to reference(:users, :id).on(:user_id)
          expect(Comment).not_to have_index.on(:user_id)
        end
      end
    end
  end

  context "when table is renamed", :postgresql => :only do

    before(:each) do
      @model = Comment
      create_table @model do |t|
        t.integer :user_id
        t.integer :xyz, :index => true
      end
      ActiveRecord::Migration.rename_table @model.table_name, :newname
    end

    it "should rename fk indexes" do
      index = ActiveRecord::Base.connection.indexes(:newname).find(&its.columns == ['user_id'])
      expect(index.name).to match(/^fk__newname_/)
    end

  end

  context "when column is added", :sqlite3 => :skip do

    before(:each) do
      @model = Comment
    end

    it "auto creates foreign key" do
      add_column(:post_id, :integer) do
        expect(@model).to reference(:posts, :id).on(:post_id)
      end
    end

    it "respects explicit foreign key" do
      add_column(:author_id, :integer, :foreign_key => { :references => :users }) do
        expect(@model).to reference(:users, :id).on(:author_id)
      end
    end

    it "doesn't create foreign key if column doesn't look like foreign key" do
      add_column(:views_count, :integer) do
        expect(@model).not_to reference.on(:views_count)
      end
    end

    it "doesn't create foreign key if declined explicitly" do
      add_column(:post_id, :integer, :foreign_key => false) do
        expect(@model).not_to reference.on(:post_id)
      end
    end

    it "shouldn't create foreign key if declined explicitly by shorthand" do
      add_column(:post_id, :integer, :references => nil) do
        expect(@model).not_to reference.on(:post_id)
      end
    end

    it "creates auto index" do
      add_column(:post_id, :integer) do
        expect(@model).to have_index.on(:post_id)
      end
    end

    it "does not create auto-index for non-foreign keys" do
      add_column(:state, :integer) do
        expect(@model).not_to have_index.on(:state)
      end
    end

    # MySQL creates an index on foreign key and we can't override that
    it "doesn't create auto-index if declined explicitly", :mysql => :skip do
      add_column(:post_id, :integer, :index => false) do
        expect(@model).not_to have_index.on(:post_id)
      end
    end

    protected
    def add_column(column_name, *args)
      table = @model.table_name
      ActiveRecord::Migration.add_column(table, column_name, *args)
      @model.reset_column_information
      yield if block_given?
      ActiveRecord::Migration.remove_column(table, column_name)
    end

  end

  context "when column is changed" do

    before(:each) do
      @model = Comment
    end

    context "with foreign keys", :sqlite3 => :skip do

      context "and initially references to users table" do

        before(:each) do
          create_table @model do |t|
            t.integer :user_id
          end
        end

        it "should have foreign key" do
          expect(@model).to reference(:users)
        end

        it "should drop foreign key if requested to do so" do
          change_column :user_id, :integer, :foreign_key => { :references => nil }
          expect(@model).not_to reference(:users)
        end

        it "should remove auto-created index if foreign key is removed", :mysql => :skip do
          expect(@model).to have_index.on(:user_id)  # sanity check that index was auto-created
          change_column :user_id, :integer, :foreign_key => { :references => nil }
          expect(@model).not_to have_index.on(:user_id)
        end

      end

      context "if column defined without foreign key but with index" do
        before(:each) do
          create_table @model do |t|
            t.integer :user_id, :foreign_key => false, :index => true
          end
        end

        it "should create the index" do
          expect(@model).to have_index.on(:user_id)
        end

        it "adding foreign key should not fail due to attempt to auto-create existing index" do
          expect { change_column :user_id, :integer, :foreign_key => true }.to_not raise_error
        end
      end
    end

    context "without foreign keys" do

      it "doesn't auto-add foreign keys" do
        create_table @model do |t|
          t.integer :user_id, :foreign_key => false
          t.string :other_column
        end
        with_fk_auto_create do
          change_column :other_column, :text
        end
        expect(@model).to_not reference(:users)
      end

    end

    protected
    def change_column(column_name, *args)
      table = @model.table_name
      ActiveRecord::Migration.change_column(table, column_name, *args)
      @model.reset_column_information
    end

  end

  def create_table(model, opts={}, &block)
    ActiveRecord::Migration.create_table model.table_name, opts.merge(:force => true), &block
    model.reset_column_information
  end

  def change_table(model, opts={}, &block)
    ActiveRecord::Migration.change_table model.table_name, opts, &block
    model.reset_column_information
  end

end

