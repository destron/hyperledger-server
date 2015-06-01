defmodule Hyperledger.View do
  use Ecto.Model

  alias Hyperledger.Repo
  alias Hyperledger.View
  alias Hyperledger.LogEntry
  alias Hyperledger.Node
  
  schema "views" do
    timestamps
      
    belongs_to :primary, Node
    has_many :log_entries, LogEntry
  end
  
  def append do
    id = Repo.one(from v in View, select: count(v.id)) + 1
    node_count = Repo.one(from n in Node, select: count(n.id))
    primary = Repo.get(Node, (node_count - rem(id, node_count)))
    
    %View{id: id, primary: primary} |> Repo.insert
  end
  
  def current do
    id = Repo.one(from v in View, select: count(v.id))
    Repo.get(View, id)
  end
end