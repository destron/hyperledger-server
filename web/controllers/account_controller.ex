defmodule Hyperledger.AccountController do
  use Hyperledger.Web, :controller
  use Ecto.Model
  
  alias Hyperledger.Repo
  alias Hyperledger.Account
  alias Hyperledger.LogEntry
  
  plug Hyperledger.Authentication when action in [:create]
  plug :action

  def index(conn, _params) do
    accounts = Repo.all(Account)
    render conn, :index, accounts: accounts
  end
  
  def show(conn, params) do
    account = Repo.first(Acccount, params["id"])
    render conn, :show, account: account
  end
  
  def create(conn, params) do
    log_entry = %{
      command: "account/create",
      data: conn.private.raw_json_body,
      authentication_key: conn.assigns[:authentication_key],
      signature: conn.assigns[:signature]
    }
    changeset = LogEntry.changeset(%LogEntry{}, :create, log_entry)
    
    if changeset.valid? do
      LogEntry.create(changeset)
      account = Repo.get(Account, params["account"]["publicKey"])
      conn
      |> put_status(:created)
      |> render :show, account: account
    else
      conn
      |> put_status(:unprocessable_entity)
      |> halt
    end
  end
end
