begin
  require 'byebug'
rescue LoadError
end

require 'rspec'
debugger
require_relative 'lib/slackbot_frd/user_channel_callbacks'


RSpec.describe UserChannelCallbacks do
  def new_callback
    @curr_int ||= 0
    @curr_int += 1
    @curr_int
  end

  let(:cjc) { UserChannelCallbacks.new }
  9.times do |i|
    let("call#{i}".to_sym) { new_callback }
    let("u#{i}".to_sym) { "user#{i}" }
    let("c#{i}".to_sym) { "channel#{i}" }
  end

  context "properly return callbacks" do
    it "should return for :any, :any" do
      cjc.add(:any, :any, call1)
      cjc.add(:any, :any, call2)
      expect(cjc.where(:any, :any).count).to be 2
      expect(cjc.where(:any, :any)).to include(call1)
      expect(cjc.where(:any, :any)).to include(call2)
      expect(cjc.where(u1, :any).count).to be_zero
      expect(cjc.where(:any, c1).count).to be_zero
      expect(cjc.where_all).to match_array([call1, call2])
      expect(cjc.where_include_all(u1, c1).count).to be 2
    end

    it "should return the :any callbacks for specific users" do
      cjc.add(:any, :any, call1)
      cjc.add(:any, :any, call2)
      cjc.add(u1, :any, call3)
      cjc.add(:any, c1, call4)
      cjc.add(u1, c1, call5)
      cjc.add(u2, c2, call6)
      cjc.add(u2, c1, call7)
      expect(cjc.where_all.count).to be 2
      expect(cjc.where_all).to match_array([call1, call2])
      expect(cjc.where(u1, c1).count).to be 1
      expect(cjc.where(u1, c1)).to match_array([call5])
      expect(cjc.where(u2, c2)).to match_array([call6])
      expect(cjc.where_include_all(u1, c1).count).to be 5
      expect(cjc.where_include_all(u1, c1)).to match_array([call1, call2, call3, call4, call5])

      # A second round of the same tests to catch memory issues
      expect(cjc.where_all.count).to be 2
      expect(cjc.where_all).to match_array([call1, call2])
      expect(cjc.where(u1, c1).count).to be 1
      expect(cjc.where(u1, c1)).to match_array([call5])
      expect(cjc.where(u2, c2)).to match_array([call6])
      expect(cjc.where_include_all(u1, c1).count).to be 5
      expect(cjc.where_include_all(u1, c1)).to match_array([call1, call2, call3, call4, call5])
    end
  end
end
