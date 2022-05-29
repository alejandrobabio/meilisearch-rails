module MeiliSearch
  module Rails
    # these are the instance methods included
    module InstanceMethods

      def self.included(base)
        base.instance_eval do
          alias_method :index!, :ms_index! unless method_defined? :index!
          alias_method :remove_from_index!, :ms_remove_from_index! unless method_defined? :remove_from_index!
        end
      end

      def ms_index!(synchronous = false)
        self.class.ms_index!(self, synchronous || ms_synchronous?)
      end

      def ms_remove_from_index!(synchronous = false)
        self.class.ms_remove_from_index!(self, synchronous || ms_synchronous?)
      end

      def ms_enqueue_remove_from_index!(synchronous)
        if meilisearch_options[:enqueue]
          unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
            meilisearch_options[:enqueue].call(self, true)
          end
        else
          ms_remove_from_index!(synchronous || ms_synchronous?)
        end
      end

      def ms_enqueue_index!(synchronous)
        if meilisearch_options[:enqueue]
          unless self.class.send(:ms_indexing_disabled?, meilisearch_options)
            meilisearch_options[:enqueue].call(self, false)
          end
        else
          ms_index!(synchronous)
        end
      end

      def ms_synchronous?
        @ms_synchronous
      end

      private

      def ms_mark_synchronous
        @ms_synchronous = true
      end

      def ms_mark_for_auto_indexing
        @ms_auto_indexing = true
      end

      def ms_mark_must_reindex
        # ms_must_reindex flag is reset after every commit as part. If we must reindex at any point in
        # a transaction, keep flag set until it is explicitly unset
        @ms_must_reindex ||=
          if defined?(::Sequel) && is_a?(Sequel::Model)
            new? || self.class.ms_must_reindex?(self)
          else
            new_record? || self.class.ms_must_reindex?(self)
          end
        true
      end

      def ms_perform_index_tasks
        return if !@ms_auto_indexing || @ms_must_reindex == false

        ms_enqueue_index!(ms_synchronous?)
        remove_instance_variable(:@ms_auto_indexing) if instance_variable_defined?(:@ms_auto_indexing)
        remove_instance_variable(:@ms_synchronous) if instance_variable_defined?(:@ms_synchronous)
        remove_instance_variable(:@ms_must_reindex) if instance_variable_defined?(:@ms_must_reindex)
      end
    end
  end
end
