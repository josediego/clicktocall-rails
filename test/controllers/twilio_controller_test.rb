require 'test_helper'

class TwilioControllerTest < ActionController::TestCase
  test 'should get index' do
    get :index
    assert_response :ok
  end

  test 'should initiate a call with a real phone number' do
    twilio_number = '15008675308'
    user_phone = '12066505812'
    sales_phone = '12066505813'
    api_host = 'http://test.host'
    client = Minitest::Mock.new
    calls = Minitest::Mock.new
    calls.expect(:create, true, [{ from: twilio_number,
                                   to: user_phone,
                                   url: "#{api_host}/connect/#{sales_phone}"}])
    client.expect(:calls, calls)

    ENV['TWILIO_NUMBER'] = twilio_number
    ENV['API_HOST'] = api_host
    Twilio::REST::Client.stub :new, client do
      post :call, userPhone: user_phone, salesPhone: sales_phone, format: 'json'

      assert_response :ok
      json = JSON.parse(response.body)
      assert_equal 'ok', json['status']
      assert_equal 'Phone call incoming!', json['message']
    end

    client.verify
    calls.verify
  end

  test 'should return a failure with a non real phone number' do
    post :call, userPhone: 'blah', salesPhone: 'blah', format: 'json'

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 'ok', json['status']
    assert_equal ['User phone is an invalid number',
                  'Sales phone is an invalid number'], json['message']
  end

  test 'should fail as fake Twilio request' do
    @request.env['HTTP_X_TWILIO_SIGNATURE'] = 'FAKE_SIGNATURE'
    post :connect, sales_number: '12066505813'
    assert_response 401 # Unauthorized
  end

  test 'should succeed with real Twilio request' do
    # Mock the validator so that we don't have to use a real signature here.
    validator = Minitest::Mock.new
    validator.expect(:validate, true, [String, Hash, String])
    Twilio::Security::RequestValidator.stub(:new, validator) do
      @request.env['HTTP_X_TWILIO_SIGNATURE'] = 'REAL_SIGNATURE'
      post :connect, sales_number: '12066505813'

      assert_response :ok
      assert response.body.match(/<Say voice="alice">/)
    end

    validator.verify
  end
end
