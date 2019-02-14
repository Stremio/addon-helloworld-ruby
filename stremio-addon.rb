require 'json'
require 'uri'

MANIFEST = {
  id: "org.stremio.helloruby",
  version: "1.0.0",

  name: "Hello Ruby Add-on",
  description: "Sample addon made with Rack providing a few public domain movies",

  types: [ :movie, :series ],

  catalogs: [
    { type: :movie, id: "Hello, Ruby" },
    { type: :series, id: "Hello, Ruby" }
  ],

  resources: [
    "catalog",
    # The meta call will be invoked only for series with ID starting with hrb
    { name: "meta", types: [ "series" ], idPrefixes: [ "hrb" ] },
    { name: "stream", types: [ "movie", "series" ], idPrefixes: [ "tt", "hrb" ] }
  ]
}

OPTIONAL_META = [:posterShape, :background, :logo, :videos, :description, :releaseInfo, :imdbRating, :director, :cast, :dvdRelease, :released, :inTheaters, :certification, :runtime, :language, :country, :awards, :website, :isPeered]

METAHUB_URL = 'https://images.metahub.space/poster/medium/%s/img'

CATALOG = {
  "movie" => [
    { id: "tt0032138", name: "The Wizard of Oz", genres: [ :Adventure, :Family, :Fantasy, :Musical ] },
    { id: "tt0017136", name: "Metropolis", genres: [:Drama, :"Sci-Fi"] },
    { id: "tt0051744", name: "House on Haunted Hill", genres: [:Horror, :Mystery] },
    { id: "tt1254207", name: "Big Buck Bunny", genres: [:Animation, :Short, :Comedy], },
    { id: "tt0031051", name: "The Arizona Kid", genres: [:Music, :War, :Western] },
    { id: "tt0137523", name: "Fight Club", genres: [:Drama] }
  ],
  "series" => [
    {
      id: "tt1748166",
      name: "Pioneer One",
      genres: [:Drama],
      videos: [
        { season: 1, episode: 1, id: "tt1748166:1:1", title: "Earthfall", released: "2010-06-16"  }
      ]
    },
    {
      id: "hrbtt0147753",
      name: "Captain Z-Ro",
      description: "From his secret laboratory, Captain Z-Ro and his associates use their time machine, the ZX-99, to learn from the past and plan for the future.",
      releaseInfo: "1955-1956",
      logo: "https://fanart.tv/fanart/tv/70358/hdtvlogo/captain-z-ro-530995d5e979d.png",
      imdbRating: 6.9,
      genres: [:"Sci-Fi"],
      videos: [
        { season: 1, episode: 1, id: "hrbtt0147753:1:1", title: "Christopher Columbus", released: "1955-12-18" },
        { season: 1, episode: 2, id: "hrbtt0147753:1:2", title: "Daniel Boone", released: "1955-12-25" }
      ]
    }
  ]
}

STREAMS = {
  "movie" => {
    "tt0032138" => [
      { title: "Torrent", infoHash: "24c8802e2624e17d46cd555f364debd949f2c81e", fileIdx: 0 }
    ],
    "tt0017136" => [
      { title: "Torrent", infoHash: "dca926c0328bb54d209d82dc8a2f391617b47d7a", fileIdx: 1 }
    ],
    "tt0051744" => [
      { title: "Torrent", infoHash: "9f86563ce2ed86bbfedd5d3e9f4e55aedd660960" }
    ],
    "tt1254207" => [
      { title: "HTTP URL", url: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4" }
    ],
    "tt0031051" => [
      { title: "YouTube", ytId: "m3BKVSpP80s" }
    ],
    "tt0137523" => [
      { title: "External URL", externalUrl: "https://www.netflix.com/watch/26004747" }
    ]
  },

  "series" => {
    "tt1748166:1:1" => [
      { title: "Torrent", infoHash: "07a9de9750158471c3302e4e95edb1107f980fa6" }
    ],

    "hrbtt0147753:1:1" => [
      { title: "YouTube", ytId: "5EQw5NYlbyE" }
    ],
    "hrbtt0147753:1:2" => [
      { title: "YouTube", ytId: "ZzdBKcVzx9Y" }
    ],
  }
}

class NotFound
  def call(env)
    [404, {"Content-Type" => "text/plain"}, ["404 Not Found"]]
  end
end

# Base class with some common behaviour
class Resource
  @@headers = {
    "Access-Control-Allow-Origin" => "*",
    "Access-Control-Allow-Headers" => "*",
    "Content-Type" => "application/json"
  }

  def initialize(app)
    @app = app
  end

  def parse_request(env)
    segments = env["PATH_INFO"][1..-1] # Remove the leading slash
      .sub(/\.\w+$/, '') # Remove extension if any
      .split("/")
      .map{ |seg| URI.decode(seg) }

    { type: segments[0], id: segments[1], extraArgs: segments[2..-1] }
  end
end

class Manifest < Resource
  def call(env)
    return @app.call(env) unless env["PATH_INFO"].empty?

    [200, @@headers, [ MANIFEST.to_json ]]
  end
end

class Catalog < Resource
  def call(env)
    args = parse_request(env)
    return @app.call(env) unless CATALOG.key?(args[:type])

    metaPreviews = CATALOG[args[:type]].map do |item|
      {
        id: item[:id],
        type: args[:type],
        name: item[:name],
        genres: item[:genres],
        poster: METAHUB_URL % item[:id]
      }
    end

    catalog = { metas: metaPreviews }

    [200, @@headers, [catalog.to_json]]
  end
end

class Meta < Resource
  def call(env)
    args = parse_request(env)
    return @app.call(env) unless CATALOG.key?(args[:type])

    item = CATALOG[args[:type]]
      .select{ |item| item[:id] == args[:id] }
      .first

    meta = {
      meta: nil
    }

    unless item.nil? then
      # Build the meta info
      meta[:meta]= {
        id: item[:id],
        type: args[:type],
        name: item[:name],
        genres: item[:genres],
        poster: METAHUB_URL % item[:id]
      }

      # Populate optional values
      OPTIONAL_META.each{ |tag| meta[:meta][tag] = item[tag] if item.key?(tag) }
    end

    [200, @@headers, [meta.to_json]]
  end
end

class Stream < Resource
  def call(env)
    args = parse_request(env)
    return @app.call(env) unless STREAMS.key?(args[:type])

    streams = {
      streams: STREAMS[args[:type]][args[:id]] || []
    }

    [200, @@headers, [streams.to_json]]
  end
end

