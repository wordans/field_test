require "rails/generators"
require "rails/generators/migration"
require "active_record"
require "rails/generators/active_record"

module FieldTest
  module Generators
    class ExperimentsGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("../templates", __FILE__)

      # Implement the required interface for Rails::Generators::Migration.
      def self.next_migration_number(dirname) #:nodoc:
        next_migration_number = current_migration_number(dirname) + 1
        if ::ActiveRecord::Base.timestamped_migrations
          [Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % next_migration_number].max
        else
          "%.3d" % next_migration_number
        end
      end

      def copy_migration
        migration_template "experiments.rb", "db/migrate/create_field_test_experiments.rb", migration_version: migration_version
      end

      def migration_version
        if ActiveRecord::VERSION::MAJOR >= 5
          "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
        end
      end
    end
  end
end
