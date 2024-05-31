import Config

config :exegete,
  ipv4_addr: "127.0.0.1",
  ipv6_addr: "::1",
  listen_port: 6379

config :logger, :console, metadata: [:mfa, :family, :client_addr, :client_port, :client_name, :db]

if File.exists?("config/#{Mix.env()}.exs") do
  import_config "#{Mix.env()}.exs"
end
