require './stremio-addon.rb'

app = Rack::Builder.new do
  use Rack::Reloader
  use Rack::ContentLength

  map "/manifest.json" do
    use Manifest
  end

  map "/meta" do
    use Meta
  end

  map "/catalog" do
    use Catalog
  end

  map "/stream" do
    use Stream
  end

  run NotFound.new
end.to_app

run app
