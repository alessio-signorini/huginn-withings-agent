require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::WithingsAgent do
  before(:each) do
    @valid_options = Agents::WithingsAgent.new.default_options
    @checker = Agents::WithingsAgent.new(:name => "WithingsAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
