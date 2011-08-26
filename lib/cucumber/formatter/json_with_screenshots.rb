require 'fileutils'

module Cucumber
  module Formatter
    class JsonWithScreenshots < Json
      module Cucumber09
        def after_step(step)
          @current_step[:html_file] = write_data_to_file(JsonWithScreenshots.last_step_html, :html)
          @current_step[:emails] = emails_for_step(step)
          super
        end
      end

      module Cucumber010
        def after_step(step)
          additional_step_info = { 'html_file' => write_data_to_file(JsonWithScreenshots.last_step_html, :html), 
            'png_file'  => write_data_to_file(JsonWithScreenshots.last_step_png,  :png),
            'emails' => emails_for_step(step) }

          current_element = @gf.gherkin_object['elements'].last
          current_step = current_element['steps'].last
          current_step.merge!(additional_step_info)
        end

        # The JSON formatter adds the background as a feature element,
        # we only want full scenarios so lets delete all with type 'background'
        def after_feature(feature)
          @gf.gherkin_object['elements'].delete_if do |element|
            element['type'] == 'background'
          end
          super(feature)
        end
      end

      cucumber_version = Gem.loaded_specs["cucumber"].version
      if cucumber_version < Gem::Version.new('0.10.0')
        include Cucumber09
      else
        include Cucumber010
      end

      class << self
        attr_accessor :last_step_html, :last_step_png

        def rewrite_css_and_image_references(response_html) # :nodoc:
          return response_html unless Capybara.asset_root
          directories = Dir.new(Capybara.asset_root).entries.inject([]) do |list, name|
            list << name if File.directory?(name) and not name.to_s =~ /^\./
              list
          end
          response_html.gsub!(/("|')\/(#{directories.join('|')})/, '\1public/\2')
          response_html.gsub(/("|')http:\/\/.*\/images/, '\1public/images') 
        end    
      end

      def initialize(step_mother, path_or_io, options)
        make_results_dir
        super(step_mother, path_or_io, options)
      end

      private


      # Writes the given html to a file in the results directory
      # and returns the filename.
      #
      # Filename are based on the SHA1 of the contents. This means 
      # that we will only write the same html once
      def write_data_to_file(data, type=:html)
        return nil unless data && data != ""
        filename = Digest::SHA1.hexdigest(data) + ".#{type}"
        full_file_path = File.join(results_dir, filename)

        unless File.exists?(full_file_path)
          File.open(full_file_path, 'w+') do |f|
            f  << data
          end
        end

        filename
      end

      def emails_for_step(step)
        #if (defined? ActionMailer)
          #ActionMailer::Base.deliveries.collect{|mail| mail_as_json(mail) }
        #end
      end

      def mail_as_json(mail)
        html_filename = write_email_to_file('text/html', mail)
        text_filename = write_email_to_file('text/plain', mail)
        {
          :to => mail.to,
          :from => mail.from,
          :subject => mail.subject,
          :body => {
          :html => html_filename,
          :text => text_filename
        }
        }
      end

      # Writes the content of the given content type to disk and returns
      # the filename to access it.
      #
      # Returns nil if no file was written.
      def write_email_to_file(content_type, mail)
        mail_part = mail.parts.find{|part| part.content_type.to_s.include? content_type }
        return nil unless mail_part

        contents = mail_part.body.to_s
        filename = Digest::SHA1.hexdigest(contents) + content_type.gsub('/', '.') + ".email.html"

        full_file_path = File.join(results_dir, filename)
        unless File.exists?(full_file_path)
          File.open(full_file_path, 'w+') do |f|
            f << prepare_email_content(content_type, contents)
          end
        end

        filename
      end

      def prepare_email_content(content_type, contents)
        case content_type
        when 'text/html'
          JsonWithScreenshots.rewrite_css_and_image_references(contents)
        when 'text/plain'
          "<html><body><pre>#{contents}</pre></body></html>"
        else
          contents
        end
      end

      def results_filename
        @json_file ||= File.join(results_dir, 'results.json')
      end

      def results_dir
        @results_dir ||= File.expand_path("results")
      end

      def make_results_dir
        FileUtils.mkdir results_dir unless File.directory? results_dir
      end
    end
  end
end
