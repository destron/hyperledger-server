defmodule Hyperledger.IssueController do
  use Hyperledger.Web, :controller
  use Ecto.Model
  
  alias Hyperledger.Issue
  alias Hyperledger.Asset
  alias Hyperledger.LogEntry
  alias Hyperledger.Repo
  
  plug Hyperledger.Authentication when action in [:create]
  plug :action
  
  def index(conn, params) do
    asset = Repo.get(Asset, params["asset_id"])
    issues = Repo.all(assoc(asset, :issues))
    render conn, :index, issues: issues, asset: asset
  end

  def create(conn, params) do
    log_entry = %{
      command: "issue/create",
      data: conn.private.raw_json_body,
      authentication_key: conn.assigns[:authentication_key],
      signature: conn.assigns[:signature]
    }
    changeset = LogEntry.changeset(%LogEntry{}, :create, log_entry)
    
    if changeset.valid? do
      LogEntry.create(changeset)
      issue = Repo.get(Issue, params["issue"]["uuid"])
      conn
      |> put_status(:created)
      |> render :show, issue: issue
    else
      conn
      |> put_status(:unprocessable_entity)
      |> halt
    end
  end
end
