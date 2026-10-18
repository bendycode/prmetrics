require 'rails_helper'

RSpec.describe StoryTrigger do
  def event(kind, payload = {})
    StoryEvent.new(kind: kind, occurred_at: Time.current, payload: payload)
  end

  it 'matches an event of its kind' do
    expect(described_class[:assigned].matches?(event(:assigned))).to be(true)
  end

  it 'does not match an event of another kind' do
    expect(described_class[:assigned].matches?(event(:opened))).to be(false)
  end

  describe 'with conditions on the payload' do
    subject(:trigger) { described_class[:assigned, 'assignee' => { 'type' => 'User' }] }

    it 'matches an event whose payload holds every condition' do
      matching = event(:assigned, 'assignee' => { 'type' => 'User', 'login' => 'octocat' }, 'id' => 1)

      expect(trigger.matches?(matching)).to be(true)
    end

    it 'does not match an event whose payload differs on a condition' do
      expect(trigger.matches?(event(:assigned, 'assignee' => { 'type' => 'Bot' }))).to be(false)
    end

    it 'does not match an event whose payload lacks a condition' do
      expect(trigger.matches?(event(:assigned, 'id' => 1))).to be(false)
    end
  end
end
