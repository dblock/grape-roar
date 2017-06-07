require 'spec_helper'
require 'active_record'

describe Grape::Roar::Extensions::RelationalModels::Adapter do 
  context '.for' do
    let(:model) { Class.new(ActiveRecord::Base) }

    it 'looks up the correct adapter for a given class' do
      expect(described_class.for(model))
        .to be_an_instance_of(described_class::ActiveRecord)
    end
  end
end