require 'cucumber'
require 'capybara'
require 'digest/sha1'

require 'cucumber/formatter/json'
require 'cucumber/formatter/json_with_screenshots'

if respond_to? :AfterStep
  AfterStep do |scenario|
    begin
      if !@email.blank?
        Cucumber::Formatter::JsonWithScreenshots.last_step_html = Cucumber::Formatter::JsonWithScreenshots.rewrite_css_and_image_references(@email)
        @email = nil
      elsif Capybara.page.driver.respond_to?(:browser) and Capybara.page.driver.browser.respond_to?(:save_screenshot)
        tempfile = Tempfile.new('screenshot').path
        Capybara.page.driver.browser.save_screenshot(tempfile)
        Cucumber::Formatter::JsonWithScreenshots.last_step_png  = open(tempfile).read
      elsif Capybara.page.driver.respond_to? :html
        Cucumber::Formatter::JsonWithScreenshots.last_step_html = Cucumber::Formatter::JsonWithScreenshots.rewrite_css_and_image_references(Capybara.page.driver.html.to_s)
      end
    rescue Exception => e
    end
  end
end

