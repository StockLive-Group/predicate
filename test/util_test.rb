# frozen_string_literal: true

require_relative 'test_helper'

class UtilTest < Minitest::Test
  def test_now_returns_time_object
    assert_kind_of Time, Predicate::Util.now
  end

  def test_now_uses_rails_zone_if_available
    # Mock Rails Time.zone
    mock_zone = Minitest::Mock.new
    mock_time = Time.now
    mock_zone.expect(:now, mock_time)

    # Define Time.zone on the singleton class
    ::Time.define_singleton_method(:zone) { mock_zone }

    begin
      assert_equal mock_time, Predicate::Util.now
    ensure
      # Remove the method after test
      ::Time.singleton_class.send(:remove_method, :zone)
    end

    assert_mock mock_zone
  end

  def test_now_falls_back_to_time_now_if_rails_missing
    # Ensure Time.zone is not defined or returns nil
    ::Time.stub(:respond_to?, false) do
      assert_kind_of Time, Predicate::Util.now
    end
  end

  def test_underscore_simple
    assert_equal 'user', Predicate::Util.underscore('User')
  end

  def test_underscore_camel_case
    assert_equal 'user_account', Predicate::Util.underscore('UserAccount')
  end

  def test_underscore_acronym
    assert_equal 'api_response', Predicate::Util.underscore('APIResponse')
  end

  def test_underscore_namespaces
    assert_equal 'predicate/core', Predicate::Util.underscore('Predicate::Core')
  end
end
