module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      TEST_URL          = 'https://ps.gcsip.nl/wdl/wdl'
      LIVE_URL          = 'https://ps.gcsip.com/wdl/wdl'
      API_VERSION       = '1.0'
      DEFAULT_LANGUAGE  = 'en'
      APPROVED          = 'OK'
      
      self.money_format = :cents
      self.default_currency = 'USD'
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club, :laser, :solo, :maestro, :dankort]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.globalcollect.com/'
      
      # The name of the gateway
      self.display_name = 'Global Collect'
      
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_merchant_details(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('authonly', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_merchant_details(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
        
        # first, we have to authorize (unfortunately, we have to do this as two different requests...)
        response = commit('authonly', money, post)
        
        if response.success? && response.params['statusid'] == '600'
          return commit('capture', money, post)
        else
          return response
        end
      end                       
    
      def capture(money, authorization, options = {})
        requires!(options, :order_id, :card_type)
        post = {}
        add_merchant_details(post, options)
        add_capture_details(post, options, money)
        # we probably need to do something more here (maybe)
        commit('capture', money, post)
      end
      
    private                       
      def add_capture_details(post, options, money)
        post[:order_id]           = options[:order_id]
        post[:payment_product_id] = payment_product_id(options[:card_type])
        post[:currency]           = options[:currency] || self.class.default_currency
        post[:amount]             = amount(money)
      end
      
      def add_merchant_details(post, options)
        post[:merchant_id]          = @options[:login]
        post[:merchant_reference]   = options[:merchant_reference] || rand(Time.now).to_s.slice(0..29)
      end
      
      def add_customer_data(post, options)
        post[:user_ip]      = options[:ip]
        post[:email]        = options[:email]
        # this dumb, but you have to send the IP address of the server from which you make the request
        post[:ip_address]   = options[:merchant_ip]
      end

      def add_address(post, creditcard, options)
        if billing_address = options[:billing_address] || options[:address]
          post[:addr1]    = billing_address[:address1]
          post[:addr2]    = billing_address[:address2]
          post[:city]     = billing_address[:city]
          post[:state]    = billing_address[:state]
          post[:zip]      = billing_address[:zip]
          post[:country]  = billing_address[:country]
        end
      end
      
      def add_invoice(post, options)
        post[:order_id]             = options[:order_id] || options[:orderid] || rand(Time.now).to_s.slice(0..9)
        post[:description]          = options[:description]
        post[:language]             = options[:language] || DEFAULT_LANGUAGE
        post[:currency]             = options[:currency] || self.class.default_currency
      end
      
      def add_creditcard(post, creditcard)
        post[:card_num]           = creditcard.number
        post[:cvv]                = creditcard.verification_value
        post[:payment_product_id] = payment_product_id(creditcard.type)
        post[:card_code]          = creditcard.verification_value if creditcard.verification_value?
        post[:exp_date]           = expdate(creditcard)
        post[:first_name]         = creditcard.first_name
        post[:last_name]          = creditcard.last_name
        # we don't want to require a CVV2 value here...
        # raise ArgumentError, "A CVV2 value is required for credit card purchases" if (!post[:cvv] || post[:cvv] == '')
      end
      
      def test?
        @options[:test] || Base.gateway_mode == :test
      end
      
      def parse(xml)
        results = {}
        xml = REXML::Document.new(xml)
        if root = REXML::XPath.first(xml, '//RESPONSE')
          root.elements.to_a.each do |node|
            parse_element(node, results)
          end
        end

        results[:message] = message_from(results)
        return results
      end     
      
      def parse_element(node, results)
        if node.has_elements?
          node.elements.to_a.each {|e| parse_element(e, results) }
        else
          if node.parent.name =~ /^(row|response|meta)$/i
            results[node.name.downcase.to_sym] = node.text
          else
            results[(node.parent.name.downcase + '_' + node.name.downcase).to_sym] = node.text
          end
        end
        return results
      end
      
      def commit(action, money, post)
        request_xml = build_request(action, post, money)
        
        # if action == 'capture'
        #   puts request_xml 
        # else
        #   puts post[:order_id]
        # end
        
        url = (test? ? TEST_URL : LIVE_URL)
        response = parse( ssl_post(url, request_xml) )
        
        Response.new(response[:result] == APPROVED, response[:message], response,
          :test => test?,
          :authorization => response[:externalreference],
          :avs_result => { :code => response[:avsresult] },
          :cvv_result => response[:cvvresult])
      end

      def message_from(response)
        response[:error_message] ? response[:error_message] : 'SUCCESS'
      end
      
      def determine_api_action(action)
        case action
        when 'authonly' then 'INSERT_ORDERWITHPAYMENT'
        when 'capture'  then 'SET_PAYMENT'
        else
          raise ArgumentError, "unknown action type: #{action}"
        end
      end
      
      def build_request(action, post, money)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.tag! 'XML' do
          xml.tag! 'REQUEST' do
            xml.tag! 'ACTION', determine_api_action(action)
            xml.tag! 'META' do
              xml.tag! 'MERCHANTID', post[:merchant_id]
              xml.tag! 'IPADDRESS', post[:ip_address] if post[:ip_address]
              xml.tag! 'VERSION', API_VERSION
            end
            xml.tag! 'PARAMS' do
              case action
              when 'authonly'
                add_order_xml(xml,post,money)
                add_payment_xml(xml,post,money)
              when 'capture'
                add_capture_payment_xml(xml,post,money)
              end
            end
          end
        end
        return xml.target!
      end
      
      def add_order_xml(xml, post, money)
        xml.tag! 'ORDER' do
          xml.tag! 'ORDERID', post[:order_id]
          xml.tag! 'MERCHANTREFERENCE', post[:merchant_reference]
          xml.tag! 'AMOUNT', amount(money)
          xml.tag! 'CURRENCYCODE', post[:currency]
          xml.tag! 'COUNTRYCODE', post[:country]
          xml.tag! 'LANGUAGECODE', post[:language]
        end
      end
      
      def add_payment_xml(xml, post, money)
        xml.tag! 'PAYMENT' do
          xml.tag! 'PAYMENTPRODUCTID', post[:payment_product_id]
          xml.tag! 'FIRSTNAME', post[:first_name]
          xml.tag! 'SURNAME', post[:last_name]
          xml.tag! 'AMOUNT', amount(money)
          xml.tag! 'CURRENCYCODE', post[:currency]
          xml.tag! 'CREDITCARDNUMBER', post[:card_num]
          xml.tag! 'CVV', post[:cvv]
          xml.tag! 'EXPIRYDATE', post[:exp_date]
          xml.tag! 'COUNTRYCODE', post[:country]
          xml.tag! 'LANGUAGECODE', post[:language]
        end
      end
      
      def add_capture_payment_xml(xml, post, money)
        xml.tag! 'PAYMENT' do
          xml.tag! 'ORDERID', post[:order_id]
          xml.tag! 'PAYMENTPRODUCTID', post[:payment_product_id]
          xml.tag! 'CURRENCYCODE', post[:currency]
          xml.tag! 'AMOUNT', amount(money)
        end
      end
      
      def payment_product_id(cardtype)
        case cardtype.to_s
          when 'visa'             then '1'
          when 'american_express' then '2'
          when 'master'           then '3'
          when 'jcb'              then '125'
          when 'discover'         then '128'
          when 'laser'            then '124'
          when 'solo'             then '118'
          when 'maestro'          then '117'
          when 'dankort'          then '123'
        end
      end
      
      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)
        return "#{month}#{year[-2..-1]}"
      end
      
    end
  end
end

