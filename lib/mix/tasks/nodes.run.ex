defmodule Mix.Tasks.Hyperledger.Nodes.Run do
  use Mix.Task
  
  @shortdoc "Run node n from a config file"
  
  def run([n, node_config]) do
    nodes =
      node_config
      |> File.read!
      |> Poison.decode!
    
    n = String.to_integer(n)
    node = Enum.at(nodes, (n - 1))
    
    System.put_env("DATABASE_URL", node["db"])
    System.put_env("PORT", "#{node["port"]}")
    System.put_env("NODE_URL", node["url"])
    System.put_env("SECRET_KEY", node["secret_key"])
    
    Mix.shell.cmd "mix ecto.drop"
    Mix.shell.cmd "mix ecto.create"
    Mix.shell.cmd "mix ecto.migrate"
    Mix.Task.run "hyperledger.nodes.seed", [node_config]
    Mix.shell.cmd "mix phoenix.server"
  end
end