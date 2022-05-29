module MeiliSearch
  module Rails
    module ClassMethods
      module AdditionalMethods
        def self.extended(base)
          class << base
            alias_method :raw_answer, :ms_raw_answer unless method_defined? :raw_answer
            alias_method :facets_distribution, :ms_facets_distribution unless method_defined? :facets_distribution
          end
        end

        def ms_raw_answer
          @ms_json
        end

        def ms_facets_distribution
          @ms_json['facetsDistribution']
        end

        private

        def ms_init_raw_answer(json)
          @ms_json = json
        end
      end
    end
  end
end
