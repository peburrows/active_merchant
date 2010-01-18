require 'test_helper'

class RemoteGlobalCollectTest < Test::Unit::TestCase
  

  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    # @declined_card = credit_card('4242424242424242')
    
    @options = { 
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => rand(Time.now)))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  # # not sure what must be done to ensure a decline response
  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end

  def test_authorize_and_capture
    order_id = rand(Time.now)
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options.merge(:order_id => order_id))
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert_equal '600', auth.params['statusid']
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, {:order_id => order_id, :card_type => @credit_card.type})
    assert_success capture
  end

  def test_failed_capture
    order_id = rand(Time.now) + 10
    assert response = @gateway.capture(@amount, '', {:order_id => order_id, :card_type => 'visa'})
    assert_failure response
    assert_equal "ORDER (MERCHANTID=5165, ORDERID=#{order_id}, EFFORTID={2}) NOT FOUND: {3}", response.message
  end

  def test_invalid_login
    gateway = GlobalCollectGateway.new(:login => '123')
    assert response = gateway.purchase(@amount, @credit_card, @options.merge(:order_id => rand(Time.now)))
    assert_failure response
    assert_equal 'UNKNOWN MERCHANT *** ACTION INSERT_ORDERWITHPAYMENT (130) IS NOT ALLOWED', response.message
  end
end
