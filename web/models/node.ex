defmodule Hyperledger.Node do
  use Ecto.Model
  
  import Ecto.Query, only: [from: 2]
  
  require Logger
  
  alias Hyperledger.Repo
  alias Hyperledger.Node
  alias Hyperledger.PrepareConfirmation
  alias Hyperledger.CommitConfirmation
  alias Hyperledger.Crypto
  
  schema "nodes" do
    field :url, :string
    field :public_key, :string

    timestamps
    
    has_many :prepare_confirmations, PrepareConfirmation
    has_many :commit_confirmations, CommitConfirmation
  end
  
  def create(id, url, public_key) do
    Repo.insert %Node{id: id, url: url, public_key: public_key}
  end
  
  def current do
    query = from n in Node,
            where: n.url == ^System.get_env["NODE_URL"],
            select: n
    
    try do
      Repo.one!(query)
    rescue
      Ecto.CastError -> raise "NODE_URL env not set"
      Ecto.NoResultsError -> raise "no node matches NODE_URL env"
    end
    
  end
    
  def quorum do
    count - div(count - 1, 3)
  end
  
  def prepare_quorum do
    quorum - 1
  end
  
  def count do
    Repo.all(Node) |> Enum.count
  end
  
  def broadcast(id, path, data) do
    Repo.all(Node)
    |> Enum.reject(&(&1 == current))
    |> Enum.each fn node ->
         try do
           Logger.info "Posting log entry #{id} to #{node.url}"
           post_log(node.url, path, data)
         rescue
           error ->
             Logger.info "Error posting to replica node @ #{node.url}"
         end
       end
  end
  
  def post_log(url, path, data) do
    sig = Crypto.sign(data, secret_key)
    HTTPotion.post "#{url}/#{path}",
      headers: [
        "content-type": "application/json",
        "authorization": "Hyper Key=#{current.public_key}, Signature=#{sig}"
      ],
      body: Poison.encode!(data)
  end
  
  defp secret_key do
    case System.get_env("SECRET_KEY") do
      nil -> raise "SECRET_KEY env not set"
      secret -> Base.decode16!(secret)
    end
  end
end
