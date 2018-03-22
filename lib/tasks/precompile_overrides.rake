require 'fileutils'

namespace :assets do
  task :precompile do
    Rails.cache.clear
    Rake::Task['assets:precompile'].invoke
    # Rake::Task['assets:upload_sourcemap'].invoke
  end

  desc 'Upload source map'
  task upload_sourcemap: :environment do
    Rails.logger.info 'uploading sourcemap'
    TOKEN = ENV['ROLLBAR_ACCESS_TOKEN']

    ASSET_HOST = ENV['CDN_ADDRESS']

    conn = Faraday.new 'https://api.rollbar.com/api/1/sourcemap' do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.response :logger
    end

    Rails.configuration.js_resource.each do |item|
      file = File.basename(item, '.js')
      source_map = Dir.glob(Rails.root.join("public/assets/maps/#{file}*.js.map")).first
      compressed_file = Dir.glob(Rails.root.join("public/assets/#{file}*.js")).first

      response = conn.post do |req|
        req.body = {
          access_token: TOKEN,
          version: CODE_VERSION,
          source_map: Faraday::UploadIO.new(File.absolute_path(source_map), 'application/octet-stream'),
          minified_url: "#{ASSET_HOST}/assets/#{File.basename(compressed_file)}"
        }
      end

      Rails.logger.info response.body
    end

    FileUtils.rm_rf Rails.root.join("public/assets/maps")
    FileUtils.rm_rf Rails.root.join("public/assets/sources")

    Rails.logger.info 'upload complete'
  end
end
