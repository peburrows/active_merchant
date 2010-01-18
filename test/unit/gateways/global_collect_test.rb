require 'test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  
  def setup
    @gateway = GlobalCollectGateway.new(:login => '123456')

    @credit_card = credit_card('4111111111111111')
    @amount = 100
    
    @options = { :billing_address => address }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '1234567890', response.authorization, "Authorization did not match: #{response.authorization} != 1234567890"
    assert response.test?, "The request was not performed as TEST"
  end

  def test_unsuccessful_request
    # confirm_expected_gateway_methods_are_called(:add_invoice, :add_creditcard, :add_address, :add_customer_data)
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, 'REQUEST 1212121 VALUE 4567350000427976 OF FIELD CREDITCARDNUMBER DID NOT PASS THE LUHNCHECK', 'message wrong'
    assert response.test?
  end


  private
  
  def successful_authorization_response
    '<XML>
      <REQUEST>
        <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
        <META>
          <MERCHANTID>1</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
          <REQUESTIPADDRESS>123.123.123.123</REQUESTIPADDRESS>
        </META>
        <PARAMS>
          <ORDER>
            <ORDERID>9998990013</ORDERID>
            <AMOUNT>29990</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>nl</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>2345</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <EXPIRYDATE>1206</EXPIRYDATE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>nl</LANGUAGECODE>
          </PAYMENT>
        </PARAMS>
        <RESPONSE>
          <RESULT>OK</RESULT>
          <META>
            <REQUESTID>17025</REQUESTID>
            <RESPONSEDATETIME>20030829161055</RESPONSEDATETIME>
          </META>
          <ROW>
            <STATUSID>600</STATUSID>
            <FRAUDRESULT>N</FRAUDRESULT>
            <FRAUDCODE>0000</FRAUDCODE>
            <ADDITIONALREFERENCE>DVR00000000000000000</ADDITIONALREFERENCE>
            <EFFORTID>1</EFFORTID>
            <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
            <ATTEMPTID>1</ATTEMPTID>
            <CVVRESULT>P</CVVRESULT>
            <ORDERID>2703070132</ORDERID>
            <AUTHORISATIONCODE>OK0089</AUTHORISATIONCODE>
            <EXTERNALREFERENCE>1234567890</EXTERNALREFERENCE>
            <MERCHANTID>9090</MERCHANTID>
            <STATUSDATE>20030829161055</STATUSDATE>
            <AVSRESULT>X</AVSRESULT>
          </ROW>
        </RESPONSE>
      </REQUEST>
    </XML>'
  end

  def failed_authorization_response
    '<XML>
      <REQUEST>
        <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
        <META>
          <MERCHANTID>1</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
          <REQUESTIPADDRESS>123.123.123.123</REQUESTIPADDRESS>
        </META>
        <PARAMS>
          <ORDER>
            <ORDERID>9998990013</ORDERID>
            <AMOUNT>29990</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>nl</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>2345</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <EXPIRYDATE>1206</EXPIRYDATE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>nl</LANGUAGECODE>
          </PAYMENT>
        </PARAMS>
        <RESPONSE>
          <RESULT>NOK</RESULT>
          <META>
            <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME>
            <REQUESTID>245</REQUESTID>
          </META>
          <ERROR>
            <CODE>21000020</CODE>
            <MESSAGE>REQUEST 1212121 VALUE 4567350000427976 OF FIELD CREDITCARDNUMBER DID NOT PASS THE LUHNCHECK</MESSAGE>
          </ERROR>
        </RESPONSE>
      </REQUEST>
    </XML>'
  end
  
  def successful_capture_response
    '<XML>
      <REQUEST>
        <ACTION>SET_PAYMENT</ACTION>
        <META>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <MERCHANTID>1</MERCHANTID>
          <VERSION>1.0</VERSION>
        </META>
        <PARAMS>
          <ORDERID>9998990011</ORDERID>
          <EFFORTID>1</EFFORTID>
          <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID>
        </PARAMS>
        <RESPONSE>
          <RESULT>OK</RESULT>
          <META>
            <RESPONSEDATETIME>20040719145902</RESPONSEDATETIME>
            <REQUESTID>246</REQUESTID>
          </META>
        </RESPONSE>
      </REQUEST>
    </XML>'
  end
  
  def failed_capture_response
    '<XML>
      <REQUEST>
        <ACTION>SET_PAYMENT</ACTION>
        <META>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <MERCHANTID>1</MERCHANTID>
          <VERSION>1.0</VERSION>
        </META>
        <PARAMS>
          <ORDERID>9998990011</ORDERID>
          <EFFORTID>1</EFFORTID>
          <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID>
        </PARAMS>
        <RESPONSE>
          <RESULT>NOK</RESULT>
          <META>
            <RESPONSEDATETIME>20040719145902</RESPONSEDATETIME>
            <REQUESTID>246</REQUESTID>
          </META>
          <ERROR>
            <CODE>410110</CODE>
            <MESSAGE>REQUEST 257 UNKNOWN ORDER OR NOT PENDING</MESSAGE>
          </ERROR>
        </RESPONSE>
      </REQUEST>
    </XML>'
  end
end
