require 'test_helper'

class RemoteGlobalCollectTest < Test::Unit::TestCase
  

  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect).merge(:test => true))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    # @declined_card = credit_card('4242424242424242')
    
    @options = { 
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  # def test_successful_purchase
  #   assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => rand(Time.now)))
  #   assert_success response
  #   assert_equal 'SUCCESS', response.message
  # end
  # 
  # def test_successful_purchase_with_currency_other_than_usd
  #   assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:order_id => rand(Time.now), :currency => 'EUR'))
  #   assert_success response
  #   assert_equal 'SUCCESS', response.message
  # end

  # # not sure what must be done to ensure a decline response
  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end

  def test_visa_not_authorised
    assert response = @gateway.purchase(@amount, credit_card('4263982640269299'), @options.merge(:order_id => rand(Time.now)) )
    assert_success response
  end
  
  def test_one_mc_success
    cc = credit_card('5425233430109903', :type => 'master')
    assert response = @gateway.purchase(@amount, cc, @options.merge(:order_id => rand(Time.now)) )
    assert_success response
  end
  
  def test_two_mc_success
    cc = credit_card('5432673002690551', :type => 'master_card')
    assert response = @gateway.purchase(@amount, cc, @options.merge(:order_id => rand(Time.now)) )
    assert_success response
  end
  
  def test_amex_success
    cc = credit_card('374245455400001', :type => 'amex')
    assert response = @gateway.purchase(@amount, cc, @options.merge(:order_id => rand(Time.now)))
    assert_success response
  end

  # def test_authorize_and_capture
  #   order_id = rand(Time.now)
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options.merge(:order_id => order_id))
  #   assert_success auth
  #   assert_equal 'SUCCESS', auth.message
  #   assert_equal '600', auth.params['statusid']
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization, {:order_id => order_id, :card_type => @credit_card.type})
  #   assert_success capture
  # end
  # 
  # def test_failed_capture
  #   order_id = rand(Time.now) + 10
  #   assert response = @gateway.capture(@amount, '', {:order_id => order_id, :card_type => 'visa'})
  #   assert_failure response
  #   assert_equal "ORDER (MERCHANTID=5165, ORDERID=#{order_id}, EFFORTID={2}) NOT FOUND: {3}", response.message
  # end
  # 
  # def test_invalid_login
  #   gateway = GlobalCollectGateway.new(:login => '123')
  #   assert response = gateway.purchase(@amount, @credit_card, @options.merge(:order_id => rand(Time.now)))
  #   assert_failure response
  #   assert_equal 'UNKNOWN MERCHANT *** ACTION INSERT_ORDERWITHPAYMENT (130) IS NOT ALLOWED', response.message
  # end
end
