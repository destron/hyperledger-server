defmodule Mix.Tasks.Hyperledger.Nodes.Seed do
  use Mix.Task
  
  alias Hyperledger.Repo
  alias Hyperledger.Node
  
  @shortdoc "Seed the database with the nodes from a config file"
  
  def run(node_config) do
    Mix.Ecto.ensure_started(Repo)
    Repo.delete_all(Node)
    node_config
    |> File.read!
    |> Poison.decode!
    |> Enum.each fn node ->
       Node.create(node["id"], node["url"], node["public_key"])
    end
  end
  
end