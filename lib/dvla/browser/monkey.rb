require 'capybara'

module DVLA
  module Browser
    module Monkey
      module CapybaraScreenshot
        def save_screenshot(path = nil, full_size: false, **options)
          return super(path, **options) unless full_size

          case driver
          when Capybara::Selenium::Driver
            if driver.browser.is_a? Selenium::WebDriver::Edge::Driver
              metrics = driver.browser.execute_cdp('Page.getLayoutMetrics')
              driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride',
                                  width: metrics['contentSize']['width'].ceil,
                                  height: metrics['contentSize']['height'].ceil,
                                  deviceScaleFactor: metrics['visualViewport']['scale'],
                                  mobile: false)
              super(path, **options)
              driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
            else
              original_size = driver.browser.manage.window.size
              driver.browser.manage.window.maximize
              super(path, **options)
              driver.browser.manage.window.resize_to(original_size.width, original_size.height)
            end
          when Capybara::Cuprite::Driver, Capybara::Apparition::Driver
            original_size = driver.screen_size
            driver.fullscreen_window(driver.current_window_handle)
            super(path, **options)
            driver.resize_window(*original_size)
          else
            super(path, **options)
          end
        end
      end

      module CapybaraCookies
        def extract_browser_cookies
          return_hash = {}
          case driver
          when Capybara::Selenium::Driver
            driver.browser.manage.all_cookies
                  .each { |cookie| return_hash[cookie[:name]] = cookie }
          when Capybara::Cuprite::Driver
            driver.browser.cookies
                  .each { |cookie| return_hash[cookie.name] = cookie.attributes }
          when Capybara::Apparition::Driver
            driver.browser.get_raw_cookies.each do |cookie|
              cookie_hash = JSON.parse(cookie.to_json)
              return_hash[cookie_hash['attributes']['name']] = cookie_hash['attributes']
            end
          else
            raise "Tried to get cookies for unhandled browser: '#{driver.class}'"
          end
          return_hash.deep_stringify_keys!
        end
      end
    end
  end
end

Capybara::Session.prepend(DVLA::Browser::Monkey::CapybaraScreenshot)
Capybara::Session.include(DVLA::Browser::Monkey::CapybaraCookies)
