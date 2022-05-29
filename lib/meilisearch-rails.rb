require 'meilisearch'

require 'meilisearch/rails/version'
require 'meilisearch/rails/utilities'
require 'meilisearch/rails/errors'
require 'meilisearch/rails/index_settings'
require 'meilisearch/rails/safe_index'
require 'meilisearch/rails/class_methods'
require 'meilisearch/rails/instance_methods'

if defined? Rails
  begin
    require 'meilisearch/rails/railtie'
  rescue LoadError
  end
end

begin
  require 'active_job'
rescue LoadError
  # no queue support, fine
end

require 'logger'

module MeiliSearch
  module Rails
    autoload :Configuration, 'meilisearch/rails/configuration'
    extend Configuration

    autoload :Pagination, 'meilisearch/rails/pagination'

    class << self
      attr_reader :included_in

      def included(klass)
        @included_in ||= []
        @included_in << klass
        @included_in.uniq!

        klass.class_eval do
          extend ClassMethods
          include InstanceMethods
        end
      end
    end

    # here lived IndexSettings

    # Default queueing system
    if defined?(::ActiveJob::Base)
      # lazy load the ActiveJob class to ensure the
      # queue is initialized before using it
      autoload :MSJob, 'meilisearch/rails/ms_job'
    end

    # here lived SafeIndex

    # here lived ClassMethods

    # here lived InstanceMethods
  end
end
