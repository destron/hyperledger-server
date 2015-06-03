defmodule Hyperledger.View do
  use Ecto.Model

  alias Hyperledger.Repo
  alias Hyperledger.View
  alias Hyperledger.LogEntry
  alias Hyperledger.CloseConfirmation
  alias Hyperledger.Node
  
  schema "views" do
    field :closed, :boolean, default: false
    timestamps
      
    belongs_to :primary, Node
    has_many :log_entries, LogEntry
    has_many :close_confirmations, CloseConfirmation
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
  
  def check_and_close(view) do
    close_count = Repo.all(assoc(view, :close_confirmations)) |> Enum.count
    node_count = Repo.all(Node) |> Enum.count
    close_quorum = (node_count * 2 / 3) |> Float.floor
    if close_count >= close_quorum do
      %{ view | closed: true } |> Repo.update
    end
  end
end