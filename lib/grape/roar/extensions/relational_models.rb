module Grape
  module Roar
    module Extensions
      module RelationalModels
        class << self
          def included(other)
            registered_representers << other
            
            class << other
              include ActiveModelRelations::DSLMethods
            end
          end

          def registered_representers
            @registered_representers ||= []
          end
        end
      end
    end
  end
end