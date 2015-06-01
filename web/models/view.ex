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
    view_count = Repo.one(from v in View, select: count(v.id))
    node_count = Repo.one(from n in Node, select: count(n.id))
    primary_id = rem(view_count, node_count) + 1
    
    %View{id: view_count + 1, primary_id: primary_id}
    |> Repo.insert
    |> Repo.preload(:primary)
  end
  
  def current do
    id = Repo.one(from v in View, select: count(v.id))
    if id == 0 do
      View.append
    else
      Repo.get(View, id)
      |> Repo.preload(:primary)
    end
  end
end